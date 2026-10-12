import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../utils/money.dart';

class ApplyResult {
  final double interest;
  final double capital;
  ApplyResult(this.interest, this.capital);
}

class DataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _clientes =>
      _db.collection('datos').doc(_uid).collection('clientes');
  CollectionReference<Map<String, dynamic>> get _prestamos =>
      _db.collection('datos').doc(_uid).collection('prestamos');
  CollectionReference<Map<String, dynamic>> get _pagos =>
      _db.collection('datos').doc(_uid).collection('pagos');

  String newId() => _uuid.v4().replaceAll('-', '').substring(0, 12);

  // ─── Load ───────────────────────────────────────────────

  Future<List<Client>> loadClients() async {
    final snap = await _clientes.get();
    return snap.docs
        .map((d) => Client.fromMap({...d.data(), 'id': d.id}))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<List<Loan>> loadLoans() async {
    final snap = await _prestamos.get();
    return snap.docs.map((d) => Loan.fromMap({...d.data(), 'id': d.id})).toList();
  }

  Future<List<Payment>> loadPaymentsToday() async {
    final t = todayIso();
    final snap = await _pagos.where('date', isEqualTo: t).get();
    return snap.docs.map((d) => Payment.fromMap({...d.data(), 'id': d.id})).toList();
  }

  Future<List<Payment>> loadAllPayments() async {
    final snap = await _pagos.get();
    return snap.docs.map((d) => Payment.fromMap({...d.data(), 'id': d.id})).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<Payment>> loadPaymentsForClient(String clientId) async {
    final snap = await _pagos.where('clientId', isEqualTo: clientId).get();
    return snap.docs.map((d) => Payment.fromMap({...d.data(), 'id': d.id})).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ─── Clients ────────────────────────────────────────────

  Future<Client> saveClient(Client c) async {
    await _clientes.doc(c.id).set(c.toMap());
    return c;
  }

  Future<void> deleteClient(String id) async {
    // delete payments of client
    final pays = await _pagos.where('clientId', isEqualTo: id).get();
    final batch = _db.batch();
    for (final d in pays.docs) {
      batch.delete(d.reference);
    }
    final loans = await _prestamos.where('clientId', isEqualTo: id).get();
    for (final d in loans.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_clientes.doc(id));
    await batch.commit();
  }

  // ─── Loans ──────────────────────────────────────────────

  Future<Loan> saveLoan(Loan l) async {
    await _prestamos.doc(l.id).set(l.toMap());
    return l;
  }

  Future<void> deleteLoan(String id) async {
    final pays = await _pagos.where('loanId', isEqualTo: id).get();
    final batch = _db.batch();
    for (final d in pays.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_prestamos.doc(id));
    await batch.commit();
  }

  Loan createLoan({
    required String clientId,
    required String type,
    required double capital,
    required String freq,
    required String startDate,
    double rate = 0,
    double fee = 0,
    double pct = 0,
    int n = 0,
    int wd = 5,
    List<int> customDays = const [],
    String note = '',
  }) {
    final id = newId();
    final next = firstDue(freq, startDate, wd: wd, customDays: customDays);
    final p = parts(startDate);
    final dom = p.length == 3 ? p[2] : null;

    if (type == 'c') {
      final total = r2(capital * (1 + pct / 100));
      return Loan(
        id: id,
        clientId: clientId,
        type: 'c',
        capital: capital,
        initialCapital: capital,
        pct: pct,
        n: n,
        total: total,
        cu: n > 0 ? r2(total / n) : 0,
        gan: n > 0 ? r2((total - capital) / n) : 0,
        paid: 0,
        k: 0,
        principal: 0,
        freq: freq,
        startDate: startDate,
        nextDate: next,
        wd: wd,
        customDays: List.from(customDays),
        note: note,
        dom: dom,
      );
    }

    // rédito: fee puede venir fijo o por rate
    final f = fee > 0 ? fee : r2(capital * rate / 100);
    final r = rate > 0 ? rate : (capital > 0 ? r2(f / capital * 100) : 0.0);
    return Loan(
      id: id,
      clientId: clientId,
      type: 'r',
      capital: capital,
      initialCapital: capital,
      principal: capital,
      fee: f,
      rate: r,
      pct: r,
      freq: freq,
      startDate: startDate,
      nextDate: next,
      wd: wd,
      customDays: List.from(customDays),
      note: note,
      dom: dom,
    );
  }

  // ─── Payment engine (port of stepR / stepC / stepCR / stepA) ───

  ApplyResult stepR(Loan l, double intr, double cap) {
    l.principal = r2(l.principal - cap);
    l.capPaid = r2((l.capPaid) + cap);
    l.credit = r2((l.credit) + intr);
    var g = 0;
    while (l.fee > 0 && l.principal > eps && l.credit + eps >= l.fee && g++ < 60) {
      l.credit = r2(l.credit - l.fee);
      l.nextDate = advance(l.nextDate, l.freq, wd: l.wd, customDays: l.customDays, dom: l.dom);
    }
    if (l.principal <= eps) {
      l.principal = 0;
      l.credit = 0;
    } else if (cap > 0) {
      l.fee = r2(l.principal * l.rate / 100);
    }
    return ApplyResult(intr, cap);
  }

  ApplyResult stepC(Loan l, double amt) {
    final bal0 = r2(l.total - l.paid);
    final capL = l.capLeft;
    var cap = bal0 > 0 ? r2(amt * capL / bal0) : 0.0;
    l.paid = r2(l.paid + amt);
    l.credit = r2(l.credit + amt);
    var g = 0;
    while (l.k < l.n && l.credit + eps >= l.inst(l.k) && g++ < 600) {
      l.credit = r2(l.credit - l.inst(l.k));
      l.k++;
      l.nextDate = advance(l.nextDate, l.freq, wd: l.wd, customDays: l.customDays, dom: l.dom);
    }
    if (l.total - l.paid <= eps) {
      l.paid = l.total;
      l.k = l.n;
      l.credit = 0;
      cap = capL;
    }
    cap = cap > capL ? capL : cap;
    l.capPaid = r2(l.capPaid + cap);
    return ApplyResult(r2(amt - cap), cap);
  }

  ApplyResult stepCR(Loan l, double amt) {
    l.rcredit = r2((l.rcredit) + amt);
    var g = 0;
    while (l.gan > 0 && l.rcredit + eps >= l.gan && g++ < 60) {
      l.rcredit = r2(l.rcredit - l.gan);
      l.nextDate = advance(l.nextDate, l.freq, wd: l.wd, customDays: l.customDays, dom: l.dom);
    }
    return ApplyResult(amt, 0);
  }

  ApplyResult stepA(Loan l, double amt) {
    final bal0 = r2(l.total - l.paid);
    final capL = l.capLeft;
    var cap = bal0 > 0 ? r2(amt * capL / bal0) : 0.0;
    l.total = r2(l.total - amt);
    if (l.total - l.paid <= eps) {
      l.total = l.paid;
      l.k = l.n;
      l.credit = 0;
      cap = capL;
    } else {
      final need = r2(l.total - l.paid + l.credit);
      l.n = l.k + (need / l.cu).ceil();
    }
    cap = cap > capL ? capL : cap;
    l.capPaid = r2(l.capPaid + cap);
    return ApplyResult(r2(amt - cap), cap);
  }

  ApplyResult apply(Loan l, double i, double c, String kind) {
    if (l.type != 'c') return stepR(l, i, c);
    if (kind == 'r') return stepCR(l, i);
    if (kind == 'a') return stepA(l, i + c);
    return stepC(l, i + c);
  }

  Future<Payment> registerPayment({
    required Loan loan,
    required String date,
    required double interest,
    required double capital,
    String note = '',
    String kind = '',
  }) async {
    final r = apply(loan, interest, capital, kind);

    String typeLabel;
    if (loan.type == 'c') {
      typeLabel = kind == 'r'
          ? 'Rédito'
          : kind == 'a'
              ? 'Avance a préstamo'
              : 'Cuota';
    } else {
      if (interest > 0 && capital > 0) {
        typeLabel = 'Mixto';
      } else if (capital > 0) {
        typeLabel = 'Avance a préstamo';
      } else {
        typeLabel = 'Rédito';
      }
    }

    if (loan.isDone) {
      loan.nextDate = '';
    }

    final p = Payment(
      id: newId(),
      loanId: loan.id,
      clientId: loan.clientId,
      date: date,
      interest: r.interest,
      capital: r.capital,
      type: typeLabel,
      note: note,
      bal: loan.balance,
      next: loan.isDone ? '' : loan.nextDate,
      k: loan.type == 'c' ? loan.k : null,
      n: loan.type == 'c' ? loan.n : null,
    );

    await _pagos.doc(p.id).set(p.toMap());
    await _prestamos.doc(loan.id).set(loan.toMap());
    return p;
  }

  /// Renovar: crea préstamo nuevo manteniendo nextDate, marca el viejo
  Future<Loan> renovar({
    required Loan old,
    required double newCapital,
    double? rate,
    double? fee,
    double? pct,
    int? n,
    String? type,
  }) async {
    final t = type ?? old.type;
    final loan = createLoan(
      clientId: old.clientId,
      type: t,
      capital: newCapital,
      freq: old.freq,
      startDate: old.nextDate.isNotEmpty ? old.nextDate : todayIso(),
      rate: rate ?? old.rate,
      fee: fee ?? 0,
      pct: pct ?? old.pct,
      n: n ?? (old.n > 0 ? old.n : 4),
      wd: old.wd,
      customDays: old.customDays,
      note: 'Renovación de ${old.id}',
    );
    // mantener el próximo cobro del anterior
    if (old.nextDate.isNotEmpty) {
      loan.nextDate = old.nextDate;
    }
    old.renewed = true;
    // liquidar saldo residual del viejo si se desea — el original mantiene el viejo hasta liquidar
    await saveLoan(old);
    await saveLoan(loan);
    return loan;
  }

  Future<void> deletePayment(String id) async {
    await _pagos.doc(id).delete();
  }
}

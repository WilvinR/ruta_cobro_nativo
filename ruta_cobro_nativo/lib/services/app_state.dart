import 'package:flutter/foundation.dart';
import '../models/client.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../utils/money.dart';
import 'auth_service.dart';
import 'data_service.dart';

class AppState extends ChangeNotifier {
  final AuthService auth = AuthService();
  final DataService data = DataService();

  List<Client> clients = [];
  List<Loan> loans = [];
  List<Payment> paymentsToday = [];
  List<Payment> allPayments = [];
  bool loading = true;
  bool paymentsFull = false;
  String? error;
  Map<String, dynamic>? profile;

  /// Membresía: si paidUntil / exemptUntil está en el pasado → solo lectura
  bool get isLocked {
    if (profile == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final paid = profile!['paidUntil'];
    final exempt = profile!['exemptUntil'];
    int? paidMs;
    int? exemptMs;
    if (paid is int) {
      paidMs = paid;
    } else if (paid is Map && paid['_seconds'] != null) {
      paidMs = (paid['_seconds'] as int) * 1000;
    }
    if (exempt is int) {
      exemptMs = exempt;
    } else if (exempt is Map && exempt['_seconds'] != null) {
      exemptMs = (exempt['_seconds'] as int) * 1000;
    }
    // Si no hay fechas de pago, no bloquear (modo prueba)
    if (paidMs == null && exemptMs == null) return false;
    final valid = (paidMs != null && paidMs > now) || (exemptMs != null && exemptMs > now);
    return !valid;
  }

  Client? clientById(String id) {
    try {
      return clients.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Loan? loanById(String id) {
    try {
      return loans.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Loan> loansOf(String clientId) =>
      loans.where((l) => l.clientId == clientId).toList();

  List<Loan> get activeLoans => loans.where((l) => !l.isDone).toList();

  List<Loan> get dueToday {
    final t = todayIso();
    return activeLoans.where((l) => l.nextDate.isNotEmpty && l.nextDate.compareTo(t) <= 0).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
  }

  Future<void> init() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      profile = await auth.getUserProfile();
      await reload();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    clients = await data.loadClients();
    loans = await data.loadLoans();
    paymentsToday = await data.loadPaymentsToday();
    notifyListeners();
  }

  Future<void> loadFullHistory() async {
    if (paymentsFull) return;
    allPayments = await data.loadAllPayments();
    paymentsFull = true;
    notifyListeners();
  }

  void _ensureWritable() {
    if (isLocked) {
      throw Exception('Membresía vencida: solo lectura');
    }
  }

  Future<void> addClient(Client c, {Loan? loan}) async {
    _ensureWritable();
    await data.saveClient(c);
    clients = [...clients, c]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (loan != null) {
      await data.saveLoan(loan);
      loans = [...loans, loan];
    }
    notifyListeners();
  }

  Future<void> updateClient(Client c) async {
    _ensureWritable();
    await data.saveClient(c);
    final i = clients.indexWhere((x) => x.id == c.id);
    if (i >= 0) clients[i] = c;
    notifyListeners();
  }

  Future<void> removeClient(String id) async {
    _ensureWritable();
    await data.deleteClient(id);
    clients = clients.where((c) => c.id != id).toList();
    loans = loans.where((l) => l.clientId != id).toList();
    allPayments = allPayments.where((p) => p.clientId != id).toList();
    paymentsToday = paymentsToday.where((p) => p.clientId != id).toList();
    notifyListeners();
  }

  Future<void> addLoan(Loan l) async {
    _ensureWritable();
    await data.saveLoan(l);
    loans = [...loans, l];
    notifyListeners();
  }

  Future<Payment> cobrar({
    required Loan loan,
    required String date,
    required double interest,
    required double capital,
    String note = '',
    String kind = '',
  }) async {
    _ensureWritable();
    final p = await data.registerPayment(
      loan: loan,
      date: date,
      interest: interest,
      capital: capital,
      note: note,
      kind: kind,
    );
    final i = loans.indexWhere((x) => x.id == loan.id);
    if (i >= 0) loans[i] = loan;
    paymentsToday = [...paymentsToday, p];
    if (paymentsFull) allPayments = [p, ...allPayments];
    notifyListeners();
    return p;
  }

  Future<Loan> renovar(Loan old, double newCapital, {double? rate, double? fee, double? pct, int? n}) async {
    _ensureWritable();
    final neu = await data.renovar(old: old, newCapital: newCapital, rate: rate, fee: fee, pct: pct, n: n);
    final i = loans.indexWhere((x) => x.id == old.id);
    if (i >= 0) loans[i] = old;
    loans = [...loans, neu];
    notifyListeners();
    return neu;
  }

  Future<void> removeLoan(String id) async {
    _ensureWritable();
    await data.deleteLoan(id);
    loans = loans.where((l) => l.id != id).toList();
    allPayments = allPayments.where((p) => p.loanId != id).toList();
    paymentsToday = paymentsToday.where((p) => p.loanId != id).toList();
    notifyListeners();
  }

  Future<void> signOut() async {
    clients = [];
    loans = [];
    paymentsToday = [];
    allPayments = [];
    paymentsFull = false;
    profile = null;
    await auth.signOut();
    notifyListeners();
  }
}

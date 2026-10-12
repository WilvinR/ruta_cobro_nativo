import '../utils/money.dart';

/// type: "r" = rédito, "c" = cuotas
class Loan {
  final String id;
  final String clientId;
  String type;
  double capital;
  double initialCapital;
  double principal;
  double fee;
  double rate; // % for rédito
  double pct; // % for cuotas total interest
  int n;
  double total;
  double cu;
  double gan;
  double paid;
  int k;
  double credit;
  double capPaid;
  double rcredit;
  String freq;
  String startDate;
  String nextDate;
  int wd;
  List<int> customDays;
  String note;
  int? dom;
  bool renewed;

  Loan({
    required this.id,
    required this.clientId,
    this.type = 'r',
    this.capital = 0,
    this.initialCapital = 0,
    this.principal = 0,
    this.fee = 0,
    this.rate = 0,
    this.pct = 0,
    this.n = 0,
    this.total = 0,
    this.cu = 0,
    this.gan = 0,
    this.paid = 0,
    this.k = 0,
    this.credit = 0,
    this.capPaid = 0,
    this.rcredit = 0,
    this.freq = 'semanal',
    required this.startDate,
    required this.nextDate,
    this.wd = 5,
    this.customDays = const [],
    this.note = '',
    this.dom,
    this.renewed = false,
  });

  factory Loan.fromMap(Map<String, dynamic> m) {
    final rate = _d(m['rate'] ?? m['pct']);
    return Loan(
      id: m['id']?.toString() ?? '',
      clientId: m['clientId']?.toString() ?? '',
      type: m['type']?.toString() ?? 'r',
      capital: _d(m['capital']),
      initialCapital: _d(m['initialCapital'] ?? m['capital']),
      principal: _d(m['principal']),
      fee: _d(m['fee']),
      rate: rate,
      pct: _d(m['pct']),
      n: (m['n'] as num?)?.toInt() ?? 0,
      total: _d(m['total']),
      cu: _d(m['cu']),
      gan: _d(m['gan']),
      paid: _d(m['paid']),
      k: (m['k'] as num?)?.toInt() ?? 0,
      credit: _d(m['credit']),
      capPaid: _d(m['capPaid']),
      rcredit: _d(m['rcredit']),
      freq: m['freq']?.toString() ?? 'semanal',
      startDate: m['startDate']?.toString() ?? '',
      nextDate: m['nextDate']?.toString() ?? '',
      wd: (m['wd'] as num?)?.toInt() ?? 5,
      customDays: (m['customDays'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [],
      note: m['note']?.toString() ?? '',
      dom: (m['dom'] as num?)?.toInt(),
      renewed: m['renewed'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'clientId': clientId,
        'type': type,
        'capital': capital,
        'initialCapital': initialCapital,
        'principal': principal,
        'fee': fee,
        'rate': rate,
        'pct': pct,
        'n': n,
        'total': total,
        'cu': cu,
        'gan': gan,
        'paid': paid,
        'k': k,
        'credit': credit,
        'capPaid': capPaid,
        'rcredit': rcredit,
        'freq': freq,
        'startDate': startDate,
        'nextDate': nextDate,
        'wd': wd,
        'customDays': customDays,
        'note': note,
        if (dom != null) 'dom': dom,
        'renewed': renewed,
      };

  bool get isDone {
    if (type == 'c') return (total - paid) <= eps;
    return principal <= eps;
  }

  double get balance {
    if (type == 'c') return r2(total - paid);
    return r2(principal);
  }

  double get capLeft => r2(MathMax(capital - capPaid, 0));

  double inst(int idx) {
    // cuota del índice idx; última puede ser distinta
    if (n <= 0) return cu;
    if (idx >= n - 1) {
      final remaining = r2(total - paid - credit);
      // approx last installment
      return remaining > 0 ? remaining : cu;
    }
    return cu;
  }

  String status(String today) {
    if (isDone) return 'Liquidado';
    if (nextDate.isEmpty) return 'Liquidado';
    if (nextDate.compareTo(today) < 0) return 'Atrasado';
    if (nextDate == today) return 'Vence hoy';
    return 'Al día';
  }

  int daysLate(String today) {
    if (nextDate.isEmpty || nextDate.compareTo(today) >= 0) return 0;
    final a = parts(nextDate);
    final b = parts(today);
    final da = DateTime.utc(a[0], a[1], a[2]);
    final db = DateTime.utc(b[0], b[1], b[2]);
    return db.difference(da).inDays;
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

double MathMax(double a, double b) => a > b ? a : b;

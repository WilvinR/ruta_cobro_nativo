class Payment {
  final String id;
  final String loanId;
  final String clientId;
  final String date; // yyyy-MM-dd
  final double interest;
  final double capital;
  final String type; // Rédito | Cuota | Mixto | Avance a préstamo
  final String note;
  final double bal;
  final String next;
  final int? k;
  final int? n;

  Payment({
    required this.id,
    required this.loanId,
    required this.clientId,
    required this.date,
    this.interest = 0,
    this.capital = 0,
    this.type = '',
    this.note = '',
    this.bal = 0,
    this.next = '',
    this.k,
    this.n,
  });

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        id: m['id']?.toString() ?? '',
        loanId: m['loanId']?.toString() ?? '',
        clientId: m['clientId']?.toString() ?? '',
        date: m['date']?.toString() ?? '',
        interest: _d(m['interest']),
        capital: _d(m['capital']),
        type: m['type']?.toString() ?? '',
        note: m['note']?.toString() ?? '',
        bal: _d(m['bal']),
        next: m['next']?.toString() ?? '',
        k: (m['k'] as num?)?.toInt(),
        n: (m['n'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'loanId': loanId,
        'clientId': clientId,
        'date': date,
        'interest': interest,
        'capital': capital,
        'type': type,
        'note': note,
        'bal': bal,
        'next': next,
        if (k != null) 'k': k,
        if (n != null) 'n': n,
      };

  double get amount => interest + capital;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

import 'package:intl/intl.dart';

const double eps = 0.005;

double r2(double n) => ((n + 1e-12) * 100).round() / 100.0;

String money(num n) {
  final f = NumberFormat.currency(locale: 'es_DO', symbol: 'RD\$', decimalDigits: 2);
  return f.format(n);
}

String todayIso() {
  final d = DateTime.now();
  return '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
}

String pad2(int n) => n.toString().padLeft(2, '0');

String formatDate(String iso) {
  if (iso.isEmpty || iso.length < 10) return iso.isEmpty ? '—' : iso;
  final p = iso.split('-');
  if (p.length < 3) return iso;
  return '${p[2]}/${p[1]}/${p[0]}';
}

List<int> parts(String iso) {
  final p = iso.split('-').map((e) => int.tryParse(e) ?? 0).toList();
  while (p.length < 3) p.add(0);
  return p;
}

String addDays(String iso, int n) {
  final p = parts(iso);
  final d = DateTime(p[0], p[1], p[2]).add(Duration(days: n));
  return '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
}

int lastDay(int year, int month) => DateTime(year, month + 1, 0).day;

/// Próximo día quincenal (1 o 16)
String nextQuin(String start) {
  final p = parts(start);
  final d = p[2];
  if (d < 16) {
    return '${p[0]}-${pad2(p[1])}-16';
  }
  // next month day 1
  final next = DateTime(p[0], p[1] + 1, 1);
  return '${next.year}-${pad2(next.month)}-01';
}

/// Próximo mes, mismo día (o último día del mes)
String nextMonth(String start, int? dom) {
  final p = parts(start);
  final day = dom ?? p[2];
  final next = DateTime(p[0], p[1] + 1, 1);
  final ld = lastDay(next.year, next.month);
  final d = day > ld ? ld : day;
  return '${next.year}-${pad2(next.month)}-${pad2(d)}';
}

/// Personalizado: días del mes (1-31)
String nextCustom(String start, List<int> days) {
  final ds = days.where((d) => d >= 1 && d <= 31).toSet().toList()..sort();
  if (ds.isEmpty) return addDays(start, 1);
  final p = parts(start);
  var z = DateTime(p[0], p[1], p[2]);
  for (var off = 1; off <= 62; off++) {
    z = z.add(const Duration(days: 1));
    final ld = lastDay(z.year, z.month);
    if (ds.any((x) => (x > ld ? ld : x) == z.day)) {
      return '${z.year}-${pad2(z.month)}-${pad2(z.day)}';
    }
  }
  return addDays(start, 1);
}

/// Primera fecha de cobro
String firstDue(String freq, String start, {int wd = 5, List<int> customDays = const []}) {
  if (freq == 'diario') return addDays(start, 1);
  if (freq == 'semanal') {
    // wd: 0=dom ... 6=sab like JS getDay, default 5 = viernes
    final p = parts(start);
    final dow = DateTime(p[0], p[1], p[2]).weekday % 7; // convert Mon=1..Sun=7 to Sun=0 style approx
    // JS: getDay() 0=Sun. Dart weekday 1=Mon..7=Sun.
    // Map dart to js: dart 7->0, 1->1, ... 6->6
    final jsDow = DateTime(p[0], p[1], p[2]).weekday == 7 ? 0 : DateTime(p[0], p[1], p[2]).weekday;
    final delta = ((wd - jsDow + 7) % 7);
    return addDays(start, delta == 0 ? 7 : delta);
  }
  if (freq == 'quincenal') return nextQuin(start);
  if (freq == 'personalizado') return nextCustom(start, customDays);
  // mensual
  return nextMonth(start, parts(start)[2]);
}

/// Avanza un período desde nextDate actual
String advance(String nextDate, String freq, {int wd = 5, List<int> customDays = const [], int? dom}) {
  if (freq == 'diario') return addDays(nextDate, 1);
  if (freq == 'semanal') return addDays(nextDate, 7);
  if (freq == 'quincenal') return nextQuin(nextDate);
  if (freq == 'personalizado') return nextCustom(nextDate, customDays);
  return nextMonth(nextDate, dom ?? parts(nextDate)[2]);
}

const freqLabels = {
  'diario': 'Diario',
  'semanal': 'Semanal',
  'quincenal': 'Quincenal',
  'mensual': 'Mensual',
  'personalizado': 'Personalizado',
};

const weekdayLabels = {
  0: 'Domingo',
  1: 'Lunes',
  2: 'Martes',
  3: 'Miércoles',
  4: 'Jueves',
  5: 'Viernes',
  6: 'Sábado',
};

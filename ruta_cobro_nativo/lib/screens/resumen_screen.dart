import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class ResumenScreen extends StatefulWidget {
  const ResumenScreen({super.key});

  @override
  State<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends State<ResumenScreen> {
  String _period = 'hoy';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadFullHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = todayIso();
    final pays = state.paymentsFull ? state.allPayments : state.paymentsToday;

    bool inP(String d) {
      switch (_period) {
        case 'hoy':
          return d == t;
        case 'semana':
          final now = DateTime.now();
          final k = (now.weekday + 6) % 7;
          final from = addDays(t, -k);
          return d.compareTo(from) >= 0 && d.compareTo(t) <= 0;
        case 'mes':
          return d.length >= 7 && d.substring(0, 7) == t.substring(0, 7);
        default:
          if (_period.startsWith('y')) return d.startsWith(_period.substring(1));
          return true;
      }
    }

    final filtered = pays.where((p) => inP(p.date)).toList();
    double cobrado = 0, interes = 0, capital = 0;
    for (final p in filtered) {
      cobrado += p.amount;
      interes += p.interest;
      capital += p.capital;
    }

    final active = state.activeLoans;
    double cartera = 0;
    int atrasados = 0;
    for (final l in active) {
      cartera += l.balance;
      if (l.status(t) == 'Atrasado') atrasados++;
    }

    final years = pays.map((p) => p.date.length >= 4 ? p.date.substring(0, 4) : '').toSet().where((y) => y.isNotEmpty).toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Hoy', 'hoy'),
                _chip('Semana', 'semana'),
                _chip('Mes', 'mes'),
                ...years.map((y) => _chip('Año $y', 'y$y')),
                _chip('Todo', 'todo'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Cobros del período', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 10),
          Row(children: [
            _card('Cobrado', money(cobrado), AppTheme.green),
            const SizedBox(width: 10),
            _card('Nº cobros', '${filtered.length}', AppTheme.amber),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _card('Interés', money(interes), AppTheme.blue),
            const SizedBox(width: 10),
            _card('Capital', money(capital), Colors.white70),
          ]),
          const SizedBox(height: 24),
          const Text('Cartera activa', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 10),
          Row(children: [
            _card('Clientes', '${state.clients.length}', Colors.white),
            const SizedBox(width: 10),
            _card('Activos', '${active.length}', AppTheme.amber),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _card('Atrasados', '$atrasados', AppTheme.red),
            const SizedBox(width: 10),
            _card('En calle', money(cartera), AppTheme.green),
          ]),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final sel = _period == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(label: Text(label), selected: sel, onSelected: (_) => setState(() => _period = value)),
    );
  }

  Widget _card(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  String _q = '';
  String _period = 'todo'; // hoy | semana | mes | yYYYY | todo | rango
  String _d1 = '';
  String _d2 = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadFullHistory();
    });
  }

  bool _inPeriod(Payment p) {
    final t = todayIso();
    final d = p.date;
    switch (_period) {
      case 'hoy':
        return d == t;
      case 'semana':
        final now = DateTime.now();
        final k = (now.weekday + 6) % 7; // monday=0
        final from = addDays(t, -k);
        return d.compareTo(from) >= 0 && d.compareTo(t) <= 0;
      case 'mes':
        return d.length >= 7 && d.substring(0, 7) == t.substring(0, 7);
      case 'rango':
        final a = _d1.isEmpty ? '0000-01-01' : _d1;
        final b = _d2.isEmpty ? '9999-12-31' : _d2;
        return d.compareTo(a) >= 0 && d.compareTo(b) <= 0;
      default:
        if (_period.startsWith('y')) {
          final y = _period.substring(1);
          return d.startsWith(y);
        }
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final base = state.paymentsFull ? state.allPayments : state.paymentsToday;
    final years = base.map((p) => p.date.length >= 4 ? p.date.substring(0, 4) : '').toSet().where((y) => y.isNotEmpty).toList()..sort((a, b) => b.compareTo(a));

    final list = base.where((p) {
      if (!_inPeriod(p)) return false;
      if (_q.isEmpty) return true;
      final c = state.clientById(p.clientId);
      return (c?.name.toLowerCase() ?? '').contains(_q.toLowerCase());
    }).toList();

    double total = 0;
    for (final p in list) {
      total += p.amount;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar cliente…',
                prefixIcon: Icon(Icons.search, color: AppTheme.muted),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _chip('Hoy', 'hoy'),
                _chip('Semana', 'semana'),
                _chip('Mes', 'mes'),
                ...years.map((y) => _chip('Año $y', 'y$y')),
                _chip('Todo', 'todo'),
                _chip('Rango…', 'rango'),
              ],
            ),
          ),
          if (_period == 'rango')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (d != null) setState(() => _d1 = '${d.year}-${pad2(d.month)}-${pad2(d.day)}');
                      },
                      child: Text(_d1.isEmpty ? 'Desde' : formatDate(_d1)),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (d != null) setState(() => _d2 = '${d.year}-${pad2(d.month)}-${pad2(d.day)}');
                      },
                      child: Text(_d2.isEmpty ? 'Hasta' : formatDate(_d2)),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('${list.length} cobros', style: const TextStyle(color: AppTheme.muted)),
                const Spacer(),
                Text(money(total), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.green)),
              ],
            ),
          ),
          if (!state.paymentsFull)
            const LinearProgressIndicator(color: Colors.white24, backgroundColor: Colors.transparent),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Sin cobros', style: TextStyle(color: AppTheme.muted)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final p = list[i];
                      final c = state.clientById(p.clientId);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(c?.name ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${p.type} · ${formatDate(p.date)}${p.note.isNotEmpty ? ' · ${p.note}' : ''}'),
                          trailing: Text(money(p.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.green)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final sel = _period == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _period = value),
      ),
    );
  }
}

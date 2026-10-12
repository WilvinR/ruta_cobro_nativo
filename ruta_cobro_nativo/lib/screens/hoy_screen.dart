import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/loan.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/status_tag.dart';
import 'cobrar_screen.dart';

class HoyScreen extends StatelessWidget {
  const HoyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final due = state.dueToday;
    final t = todayIso();

    double totalDue = 0;
    for (final l in due) {
      if (l.type == 'c') {
        totalDue += l.cu;
      } else {
        totalDue += l.fee;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => state.reload(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _Kpi(label: 'Por cobrar', value: '${due.length}', color: AppTheme.amber),
                const SizedBox(width: 10),
                _Kpi(label: 'Monto est.', value: money(totalDue), color: AppTheme.green),
              ],
            ),
          ),
          Expanded(
            child: due.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 56, color: AppTheme.green),
                        SizedBox(height: 12),
                        Text('Nada pendiente para hoy', style: TextStyle(color: AppTheme.muted, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: due.length,
                    itemBuilder: (_, i) {
                      final l = due[i];
                      final c = state.clientById(l.clientId);
                      final st = l.status(t);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openCobrar(context, l),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c?.name ?? 'Cliente',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    StatusTag(status: st),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l.type == 'c'
                                      ? 'Cuota ${l.k + 1}/${l.n} · ${money(l.cu)}'
                                      : 'Rédito · ${money(l.fee)}',
                                  style: const TextStyle(color: AppTheme.muted),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Saldo: ${money(l.balance)} · Vence: ${formatDate(l.nextDate)}',
                                  style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openCobrar(BuildContext context, Loan loan) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CobrarScreen(loan: loan)),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Kpi({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

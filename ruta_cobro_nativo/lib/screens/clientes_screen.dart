import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../models/loan.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/status_tag.dart';
import 'cliente_form_screen.dart';
import 'cobrar_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.clients.where((c) {
      if (_q.isEmpty) return true;
      final q = _q.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.phone.contains(q) || c.ref.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClienteFormScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar cliente…',
                prefixIcon: Icon(Icons.search, color: AppTheme.muted),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Sin clientes', style: TextStyle(color: AppTheme.muted)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final ls = state.loansOf(c.id);
                      final active = ls.where((l) => !l.isDone).toList();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showClient(context, c, ls),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.surface,
                                  child: Text(
                                    c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${c.phone}${c.ref.isNotEmpty ? ' · ${c.ref}' : ''}',
                                        style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                if (active.isNotEmpty)
                                  Text('${active.length} act.', style: const TextStyle(color: AppTheme.amber, fontSize: 12)),
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

  void _showClient(BuildContext context, Client c, List<Loan> ls) {
    final state = context.read<AppState>();
    final t = todayIso();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scroll) {
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              children: [
                Text(c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${c.phone} · ${c.ref}', style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ClienteFormScreen(client: c)),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Editar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ClienteFormScreen(client: c, addLoanOnly: true)),
                          );
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Prestar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Préstamos', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (ls.isEmpty)
                  const Text('Sin préstamos', style: TextStyle(color: AppTheme.muted))
                else
                  ...ls.map((l) {
                    final st = l.status(t);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.type == 'c' ? 'Cuotas · ${money(l.total)}' : 'Rédito · ${money(l.principal)}'),
                      subtitle: Text('Saldo ${money(l.balance)} · ${freqLabels[l.freq] ?? l.freq}'),
                      trailing: StatusTag(status: st),
                      onTap: l.isDone
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => CobrarScreen(loan: l)),
                              );
                            },
                    );
                  }),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Eliminar cliente'),
                        content: const Text('Se eliminarán también sus préstamos. ¿Continuar?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
                          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Eliminar', style: TextStyle(color: AppTheme.red))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await state.removeClient(c.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Eliminar cliente', style: TextStyle(color: AppTheme.red)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/loan.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class CobrarScreen extends StatefulWidget {
  final Loan loan;
  const CobrarScreen({super.key, required this.loan});

  @override
  State<CobrarScreen> createState() => _CobrarScreenState();
}

class _CobrarScreenState extends State<CobrarScreen> {
  late final TextEditingController _interest;
  late final TextEditingController _capital;
  late final TextEditingController _note;
  String _date = todayIso();
  String _kind = ''; // '' cuota, 'r' rédito cuotas, 'a' avance
  bool _saving = false;

  Loan get loan => widget.loan;

  @override
  void initState() {
    super.initState();
    if (loan.type == 'c') {
      _interest = TextEditingController(text: loan.cu.toStringAsFixed(2));
      _capital = TextEditingController(text: '0');
    } else {
      _interest = TextEditingController(text: loan.fee.toStringAsFixed(2));
      _capital = TextEditingController(text: '0');
    }
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _interest.dispose();
    _capital.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setKind(String k) {
    setState(() {
      _kind = k;
      if (loan.type == 'c') {
        if (k == 'a') {
          _interest.text = '0';
          _capital.text = loan.balance.toStringAsFixed(2);
        } else if (k == 'r') {
          _interest.text = loan.gan.toStringAsFixed(2);
          _capital.text = '0';
        } else {
          _interest.text = loan.cu.toStringAsFixed(2);
          _capital.text = '0';
        }
      }
    });
  }

  Future<void> _save() async {
    final interest = double.tryParse(_interest.text.replaceAll(',', '.')) ?? 0;
    final capital = double.tryParse(_capital.text.replaceAll(',', '.')) ?? 0;
    if (interest <= 0 && capital <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un monto')));
      return;
    }
    setState(() => _saving = true);
    try {
      final state = context.read<AppState>();
      final p = await state.cobrar(
        loan: loan,
        date: _date,
        interest: interest,
        capital: capital,
        note: _note.text.trim(),
        kind: _kind,
      );
      if (!mounted) return;
      final client = state.clientById(loan.clientId);
      final msg = _receipt(client?.name ?? '', p.interest + p.capital, p.type, p.bal);
      await showDialog(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Cobro registrado'),
          content: Text(msg),
          actions: [
            if (client != null && client.phone.isNotEmpty)
              TextButton(
                onPressed: () {
                  var phone = client.phone.replaceAll(RegExp(r'\D'), '');
                  if (!phone.startsWith('1') && phone.length <= 10) phone = '1$phone';
                  launchUrl(Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}'));
                },
                child: const Text('WhatsApp'),
              ),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cerrar')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _receipt(String name, double amount, String type, double bal) {
    return 'RutaCobro RD\n'
        'Cliente: $name\n'
        'Tipo: $type\n'
        'Monto: ${money(amount)}\n'
        'Fecha: ${formatDate(_date)}\n'
        'Saldo restante: ${money(bal)}';
  }

  Future<void> _renovar() async {
    final ctrl = TextEditingController(text: loan.capital.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Renovar préstamo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se mantiene el próximo cobro: ${formatDate(loan.nextDate)}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Monto del nuevo préstamo'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Renovar')),
        ],
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(ctrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    try {
      await context.read<AppState>().renovar(
            loan,
            amount,
            rate: loan.rate,
            fee: loan.fee,
            pct: loan.pct,
            n: loan.n,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Préstamo renovado')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final client = state.clientById(loan.clientId);
    final t = todayIso();
    final st = loan.status(t);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobrar'),
        actions: [
          if (!loan.isDone && !loan.renewed)
            IconButton(
              icon: const Icon(Icons.autorenew),
              tooltip: 'Renovar',
              onPressed: _renovar,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(client?.name ?? 'Cliente',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Text(st, style: TextStyle(
                        color: st == 'Atrasado' ? AppTheme.red : st == 'Vence hoy' ? AppTheme.amber : AppTheme.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      )),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loan.type == 'c'
                        ? 'Cuotas ${loan.k}/${loan.n} · Cuota ${money(loan.cu)} · Saldo ${money(loan.balance)}'
                        : 'Rédito ${money(loan.fee)} · Principal ${money(loan.principal)}',
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                  Text(
                    '${freqLabels[loan.freq] ?? loan.freq} · Próximo: ${formatDate(loan.nextDate)}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (loan.type == 'c') ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '', label: Text('Cuota')),
                ButtonSegment(value: 'r', label: Text('Rédito')),
                ButtonSegment(value: 'a', label: Text('Avance')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => _setKind(s.first),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _interest,
            decoration: InputDecoration(
              labelText: loan.type == 'c'
                  ? (_kind == 'r'
                      ? 'Pago de rédito'
                      : _kind == 'a'
                          ? 'Interés (0)'
                          : 'Monto cuota')
                  : 'Rédito / interés',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          if (loan.type == 'r' || _kind == 'a')
            TextFormField(
              controller: _capital,
              decoration: const InputDecoration(labelText: 'Abono a capital'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          if (loan.type == 'r' || _kind == 'a') const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha del cobro'),
            subtitle: Text(formatDate(_date)),
            trailing: const Icon(Icons.calendar_today, size: 20),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (d != null) {
                setState(() => _date = '${d.year}-${pad2(d.month)}-${pad2(d.day)}');
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving || state.isLocked ? null : _save,
              child: Text(_saving ? 'Guardando…' : state.isLocked ? 'Solo lectura' : 'Registrar cobro'),
            ),
          ),
        ],
      ),
    );
  }
}

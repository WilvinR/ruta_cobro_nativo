import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class ClienteFormScreen extends StatefulWidget {
  final Client? client;
  final bool addLoanOnly;
  const ClienteFormScreen({super.key, this.client, this.addLoanOnly = false});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _ref;
  late final TextEditingController _capital;
  late final TextEditingController _fee;
  late final TextEditingController _rate;
  late final TextEditingController _pct;
  late final TextEditingController _n;

  String _type = 'r';
  String _freq = 'semanal';
  String _start = todayIso();
  int _wd = 5;
  final Set<int> _customDays = {};
  bool _saving = false;

  bool get _isEdit => widget.client != null && !widget.addLoanOnly;
  bool get _showLoan => widget.client == null || widget.addLoanOnly;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _ref = TextEditingController(text: c?.ref ?? '');
    _capital = TextEditingController();
    _fee = TextEditingController();
    _rate = TextEditingController(text: '10');
    _pct = TextEditingController(text: '20');
    _n = TextEditingController(text: '4');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _ref.dispose();
    _capital.dispose();
    _fee.dispose();
    _rate.dispose();
    _pct.dispose();
    _n.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_showLoan && _freq == 'personalizado' && _customDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un día del mes')),
      );
      return;
    }
    setState(() => _saving = true);
    final state = context.read<AppState>();
    try {
      LoanParams? lp;
      if (_showLoan) {
        final cap = double.parse(_capital.text.replaceAll(',', '.'));
        lp = LoanParams(
          type: _type,
          capital: cap,
          freq: _freq,
          start: _start,
          rate: double.tryParse(_rate.text.replaceAll(',', '.')) ?? 0,
          fee: double.tryParse(_fee.text.replaceAll(',', '.')) ?? 0,
          pct: double.tryParse(_pct.text.replaceAll(',', '.')) ?? 0,
          n: int.tryParse(_n.text) ?? 1,
          wd: _wd,
          customDays: _customDays.toList()..sort(),
        );
      }

      if (widget.addLoanOnly && widget.client != null) {
        final loan = state.data.createLoan(
          clientId: widget.client!.id,
          type: lp!.type,
          capital: lp.capital,
          freq: lp.freq,
          startDate: lp.start,
          rate: lp.rate,
          fee: lp.fee,
          pct: lp.pct,
          n: lp.n,
          wd: lp.wd,
          customDays: lp.customDays,
        );
        await state.addLoan(loan);
      } else if (_isEdit) {
        final c = widget.client!.copyWith(
          name: _name.text.trim(),
          phone: _phone.text.replaceAll(RegExp(r'\D'), ''),
          ref: _ref.text.trim(),
        );
        await state.updateClient(c);
      } else {
        final id = const Uuid().v4().replaceAll('-', '').substring(0, 12);
        final c = Client(
          id: id,
          name: _name.text.trim(),
          phone: _phone.text.replaceAll(RegExp(r'\D'), ''),
          ref: _ref.text.trim(),
        );
        final loan = state.data.createLoan(
          clientId: id,
          type: lp!.type,
          capital: lp.capital,
          freq: lp.freq,
          startDate: lp.start,
          rate: lp.rate,
          fee: lp.fee,
          pct: lp.pct,
          n: lp.n,
          wd: lp.wd,
          customDays: lp.customDays,
        );
        await state.addClient(c, loan: loan);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.addLoanOnly
            ? 'Nuevo préstamo'
            : _isEdit
                ? 'Editar cliente'
                : 'Nuevo cliente'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.addLoanOnly) ...[
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Teléfono (WhatsApp) *'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.replaceAll(RegExp(r'\D'), '').length < 7) ? 'Teléfono inválido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ref,
                decoration: const InputDecoration(labelText: 'Referencia *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
            ],
            if (_showLoan) ...[
              const SizedBox(height: 20),
              const Text('Préstamo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'r', label: Text('A rédito')),
                  ButtonSegment(value: 'c', label: Text('A cuotas')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capital,
                decoration: const InputDecoration(labelText: 'Monto prestado (RD\$) *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Monto obligatorio';
                  return null;
                },
              ),
              if (_type == 'r') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fee,
                        decoration: const InputDecoration(labelText: 'Rédito (RD\$)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) {
                          final cap = double.tryParse(_capital.text.replaceAll(',', '.')) ?? 0;
                          final f = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                          if (cap > 0 && f > 0) {
                            _rate.text = r2(f / cap * 100).toStringAsFixed(2);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _rate,
                        decoration: const InputDecoration(labelText: 'Rédito (%)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) {
                          final cap = double.tryParse(_capital.text.replaceAll(',', '.')) ?? 0;
                          final r = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                          if (cap > 0 && r > 0) {
                            _fee.text = r2(cap * r / 100).toStringAsFixed(2);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              if (_type == 'c') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pct,
                  decoration: const InputDecoration(labelText: '% interés total *'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _n,
                  decoration: const InputDecoration(labelText: 'Nº de cuotas *'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return 'Mínimo 1';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _freq,
                decoration: const InputDecoration(labelText: 'Frecuencia'),
                items: freqLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _freq = v ?? 'semanal'),
              ),
              if (_freq == 'semanal') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _wd,
                  decoration: const InputDecoration(labelText: 'Día de cobro'),
                  items: weekdayLabels.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _wd = v ?? 5),
                ),
              ],
              if (_freq == 'personalizado') ...[
                const SizedBox(height: 12),
                const Text('Días del mes', style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(31, (i) {
                    final day = i + 1;
                    final sel = _customDays.contains(day);
                    return FilterChip(
                      label: Text('$day'),
                      selected: sel,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _customDays.add(day);
                          } else {
                            _customDays.remove(day);
                          }
                        });
                      },
                    );
                  }),
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha de inicio'),
                subtitle: Text(formatDate(_start)),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (d != null) {
                    setState(() => _start = '${d.year}-${pad2(d.month)}-${pad2(d.day)}');
                  }
                },
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Guardando…' : 'Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoanParams {
  final String type, freq, start;
  final double capital, rate, fee, pct;
  final int n, wd;
  final List<int> customDays;
  LoanParams({
    required this.type,
    required this.capital,
    required this.freq,
    required this.start,
    required this.rate,
    required this.fee,
    required this.pct,
    required this.n,
    required this.wd,
    required this.customDays,
  });
}

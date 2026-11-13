import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_entry.dart';
import '../theme.dart';
import '../utils/money.dart';

class EntryForm extends StatefulWidget {
  const EntryForm({
    super.key,
    this.entry,
    required this.initialDate,
    required this.onSave,
  });
  final FinanceEntry? entry;
  final DateTime initialDate;
  final Future<void> Function(FinanceEntry) onSave;
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late DateTime _date;
  late bool _income;
  late bool _paid;
  late String _category;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _title = TextEditingController(text: entry?.title ?? '');
    _amount = TextEditingController(
      text: entry == null ? '' : moneyInput(entry.amountCents),
    );
    _date = entry?.date ?? widget.initialDate;
    _income = entry?.isIncome ?? false;
    _paid = entry?.isPaid ?? true;
    _category = entry?.category ?? expenseCategories.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        FinanceEntry(
          id:
              widget.entry?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          title: _title.text.trim(),
          amountCents: parseMoney(_amount.text)!,
          category: _category,
          date: _date,
          isIncome: _income,
          isPaid: _paid,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.entry == null
                          ? 'Novo lançamento'
                          : 'Editar lançamento',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
              const Text(
                'Cada registro é um passo para se organizar.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Despesa'),
                    icon: Icon(Icons.north_east),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Receita'),
                    icon: Icon(Icons.south_west),
                  ),
                ],
                selected: {_income},
                onSelectionChanged: _saving
                    ? null
                    : (values) => setState(() {
                        _income = values.first;
                        _category =
                            (_income ? incomeCategories : expenseCategories)
                                .first;
                      }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amount,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  prefixText: 'R\$ ',
                  hintText: '0,00',
                ),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                validator: (value) {
                  final cents = parseMoney(value ?? '');
                  return cents == null || cents <= 0
                      ? 'Informe um valor positivo, como 125,90.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                enabled: !_saving,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex.: Compras da semana',
                  counterText: '',
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Dê um nome ao lançamento.'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('$_income-$_category'),
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: (_income ? incomeCategories : expenseCategories)
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100, 12, 31),
                          helpText: _paid
                              ? 'Data do lançamento'
                              : 'Data de vencimento',
                        );
                        if (date != null && mounted) {
                          setState(() => _date = date);
                        }
                      },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  DateFormat("dd 'de' MMMM 'de' yyyy", 'pt_BR').format(_date),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(_income ? 'Já foi recebido?' : 'Já foi pago?'),
                subtitle: Text(
                  _paid
                      ? 'Entra no resultado realizado do mês.'
                      : 'A data acima será o vencimento. Entra na previsão.',
                ),
                value: _paid,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _paid = value),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: coral)),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Salvando…' : 'Salvar lançamento'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

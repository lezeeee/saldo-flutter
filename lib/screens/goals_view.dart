import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/savings_goal.dart';
import '../services/exchange_service.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../widgets/finance_widgets.dart';

String _goalMoney(int cents, String currency) => NumberFormat.currency(
  locale: 'pt_BR',
  symbol: currency == 'USD' ? 'US\$' : 'R\$',
  decimalDigits: 2,
).format(cents / 100);

/// O estado da cotação é local à tela. As metas persistidas pertencem ao pai.
class GoalsView extends StatefulWidget {
  const GoalsView({
    super.key,
    required this.goals,
    required this.onSave,
    required this.onDelete,
    this.service,
  });

  final List<SavingsGoal> goals;
  final Future<void> Function(SavingsGoal) onSave;
  final Future<void> Function(SavingsGoal) onDelete;
  final ExchangeService? service;

  @override
  State<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends State<GoalsView> {
  late final ExchangeService _service;
  DollarQuote? _quote;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ExchangeService();
    if (widget.goals.any((goal) => goal.currency == 'USD')) _fetch();
  }

  @override
  void didUpdateWidget(covariant GoalsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.goals.any((goal) => goal.currency == 'USD') &&
        widget.goals.any((goal) => goal.currency == 'USD') &&
        _quote == null &&
        !_loading) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quote = await _service.fetchDollarQuote();
      if (mounted) {
        setState(() {
          _quote = quote;
          _loading = false;
        });
      }
    } on ExchangeException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _edit([SavingsGoal? goal]) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _GoalForm(goal: goal, onSave: widget.onSave),
  );

  Future<void> _changeSaved(SavingsGoal goal, {required bool withdraw}) =>
      showDialog<void>(
        context: context,
        builder: (_) => _ContributionDialog(
          goal: goal,
          withdraw: withdraw,
          onSave: widget.onSave,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasDollars = widget.goals.any((goal) => goal.currency == 'USD');
    final completed = widget.goals
        .where((goal) => goal.savedCents >= goal.targetCents)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF4E2),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 18,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nova meta'),
                  ),
                  if (widget.goals.isNotEmpty)
                    Text(
                      '${widget.goals.length} meta(s) · $completed concluída(s)',
                      style: const TextStyle(
                        color: green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'Acompanhamento manual; não movimenta o saldo. Registre aqui valores que você já separou para cada objetivo.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.6),
          ),
        ),
        if (hasDollars) ...[_exchangeNotice(), const SizedBox(height: 20)],
        if (widget.goals.isEmpty)
          const Panel(
            child: Column(
              children: [
                Icon(Icons.outlined_flag_rounded, color: green, size: 44),
                SizedBox(height: 18),
                Text(
                  'Qual é a sua próxima conquista?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                ),
                SizedBox(height: 10),
                Text(
                  'Crie uma meta em reais ou em dólares. Você define o objetivo e acompanha cada avanço.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.6),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 760
                  ? (constraints.maxWidth - 20) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (final goal in widget.goals)
                    SizedBox(width: width, child: _goalCard(goal)),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _exchangeNotice() => Panel(
    padding: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.currency_exchange_rounded, color: green, size: 21),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Seu objetivo em dólar, visto em reais',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Atualizar câmbio das metas',
              onPressed: _loading ? null : _fetch,
              icon: const Icon(Icons.refresh_rounded, color: green),
            ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(
            'Estimativa indisponível. $_error',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          TextButton(onPressed: _fetch, child: const Text('Tentar novamente')),
        ] else if (_quote != null && !_loading)
          Text(
            'US\$ 1 = ${money((_quote!.rate * 100).round())} · ${DateFormat('dd/MM/yyyy').format(_quote!.date)}\nReferência diária Frankfurter. Estimativa sem impostos ou tarifas.',
            style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
          ),
      ],
    ),
  );

  Widget _goalCard(SavingsGoal goal) {
    final remaining = goal.targetCents - goal.savedCents;
    final complete = remaining <= 0;
    final progress = (goal.savedCents / goal.targetCents).clamp(0.0, 1.0);
    final date = goal.deadline;
    final today = DateUtils.dateOnly(DateTime.now());
    final late =
        date != null && DateUtils.dateOnly(date).isBefore(today) && !complete;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF4E2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  complete
                      ? Icons.verified_rounded
                      : goal.currency == 'USD'
                      ? Icons.flight_takeoff_rounded
                      : Icons.savings_outlined,
                  color: green,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  goal.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções da meta ${goal.title}',
                onSelected: (value) {
                  if (value == 'edit') _edit(goal);
                  if (value == 'delete') widget.onDelete(goal);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar meta')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir meta')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'VALOR GUARDADO',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _goalMoney(goal.savedCents, goal.currency),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 31,
                color: ink,
                letterSpacing: -.6,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'de ${_goalMoney(goal.targetCents, goal.currency)}',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 19),
          LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: canvas,
            color: green,
          ),
          const SizedBox(height: 12),
          Text(
            complete
                ? 'Meta concluída. Você chegou lá!'
                : '${(progress * 100).toStringAsFixed(0)}% do caminho · faltam ${_goalMoney(remaining, goal.currency)}',
            style: const TextStyle(
              color: green,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          if (date != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${late ? 'Prazo ultrapassado' : 'Prazo'}: ${DateFormat('dd/MM/yyyy').format(date)}',
                style: TextStyle(color: late ? coral : muted, fontSize: 12),
              ),
            ),
          if (goal.currency == 'USD' &&
              _quote != null &&
              _error == null &&
              !_loading)
            Container(
              margin: const EdgeInsets.only(top: 18),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: canvas,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Objetivo ≈ ${money((goal.targetCents * _quote!.rate).round())}\nFalta guardar ≈ ${money((remaining * _quote!.rate).round())} em reais na cotação de referência.',
                style: const TextStyle(fontSize: 12, color: muted, height: 1.6),
              ),
            ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!complete)
                FilledButton.icon(
                  onPressed: () => _changeSaved(goal, withdraw: false),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Guardar'),
                ),
              if (goal.savedCents > 0)
                OutlinedButton(
                  onPressed: () => _changeSaved(goal, withdraw: true),
                  child: const Text('Retirar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalForm extends StatefulWidget {
  const _GoalForm({this.goal, required this.onSave});
  final SavingsGoal? goal;
  final Future<void> Function(SavingsGoal) onSave;
  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _target, _saved;
  late String _currency;
  DateTime? _deadline;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _title = TextEditingController(text: goal?.title ?? '');
    _target = TextEditingController(
      text: goal == null ? '' : moneyInput(goal.targetCents),
    );
    _saved = TextEditingController(text: moneyInput(goal?.savedCents ?? 0));
    _currency = goal?.currency ?? 'BRL';
    _deadline = goal?.deadline;
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        SavingsGoal(
          id:
              widget.goal?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          title: _title.text.trim(),
          targetCents: parseMoney(_target.text)!,
          savedCents: parseMoney(_saved.text)!,
          currency: _currency,
          deadline: _deadline,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar a meta. Tente novamente.';
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
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.goal == null ? 'Criar uma meta' : 'Editar meta',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar formulário de meta',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                enabled: !_saving,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Nome da meta',
                  hintText: 'Ex.: Meu primeiro notebook',
                  counterText: '',
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Dê um nome à sua meta.'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'Moeda da meta'),
                items: const [
                  DropdownMenuItem(value: 'BRL', child: Text('Real (R\$)')),
                  DropdownMenuItem(value: 'USD', child: Text('Dólar (US\$)')),
                ],
                onChanged: _saving || widget.goal != null
                    ? null
                    : (value) => setState(() => _currency = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _target,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Valor do objetivo',
                  prefixText: _currency == 'USD' ? 'US\$ ' : 'R\$ ',
                ),
                validator: (value) {
                  final cents = parseMoney(value ?? '');
                  return cents == null || cents <= 0
                      ? 'Informe um valor maior que zero.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _saved,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Já guardado',
                  prefixText: _currency == 'USD' ? 'US\$ ' : 'R\$ ',
                ),
                validator: (value) {
                  final cents = parseMoney(value ?? '');
                  final target = parseMoney(_target.text);
                  if (cents == null) {
                    return 'Informe um valor válido, como 100,00.';
                  }
                  if (target != null && cents > target) {
                    return 'O valor guardado não pode superar o objetivo.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _deadline ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100, 12, 31),
                          helpText: 'Prazo para sua meta',
                        );
                        if (date != null && mounted) {
                          setState(() => _deadline = date);
                        }
                      },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  _deadline == null
                      ? 'Adicionar prazo (opcional)'
                      : 'Prazo: ${DateFormat('dd/MM/yyyy').format(_deadline!)}',
                ),
              ),
              if (_deadline != null)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _deadline = null),
                  child: const Text('Remover prazo'),
                ),
              const SizedBox(height: 14),
              Text(
                'Informe os valores em ${_currency == 'USD' ? 'dólares' : 'reais'}. Este registro não debita dinheiro dos lançamentos.',
                style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: coral)),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvando…' : 'Salvar meta'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ContributionDialog extends StatefulWidget {
  const _ContributionDialog({
    required this.goal,
    required this.withdraw,
    required this.onSave,
  });
  final SavingsGoal goal;
  final bool withdraw;
  final Future<void> Function(SavingsGoal) onSave;
  @override
  State<_ContributionDialog> createState() => _ContributionDialogState();
}

class _ContributionDialogState extends State<_ContributionDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final goal = widget.goal;
    final cents = parseMoney(_amount.text)!;
    try {
      await widget.onSave(
        SavingsGoal(
          id: goal.id,
          title: goal.title,
          targetCents: goal.targetCents,
          savedCents: goal.savedCents + (widget.withdraw ? -cents : cents),
          currency: goal.currency,
          deadline: goal.deadline,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível atualizar a meta.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.withdraw ? 'Retirar da meta' : 'Guardar para a meta'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.goal.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text(
                'Atualize o acompanhamento do valor separado. Não há movimentação de dinheiro.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amount,
                enabled: !_saving,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      'Valor para ${widget.withdraw ? 'retirar' : 'guardar'}',
                  prefixText: widget.goal.currency == 'USD' ? 'US\$ ' : 'R\$ ',
                ),
                validator: (value) {
                  final amount = parseMoney(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Informe um valor maior que zero.';
                  }
                  final maximum = widget.withdraw
                      ? widget.goal.savedCents
                      : widget.goal.targetCents - widget.goal.savedCents;
                  if (amount > maximum) {
                    return 'O máximo é ${_goalMoney(maximum, widget.goal.currency)}.';
                  }
                  return null;
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: coral)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvando…' : 'Confirmar valor'),
        ),
      ],
    ),
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/finance_database.dart';
import '../models/finance_entry.dart';
import '../models/month_summary.dart';
import '../models/savings_goal.dart';
import 'goals_view.dart';
import '../widgets/backup_dialog.dart';
import '../widgets/monthly_overview.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../widgets/entry_form.dart';
import '../widgets/exchange_card.dart';
import '../widgets/finance_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.database});
  final FinanceDatabase? database;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FinanceDatabase _database;
  List<FinanceEntry> _entries = [];
  List<SavingsGoal> _goals = [];
  bool _onlyPending = false;
  Map<String, int> _budgets = {};
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _tab = 0;
  int _filter = 0;
  String _query = '';
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _search = TextEditingController();

  // initState é chamado uma vez por State: o banco não é aberto dentro de build.
  @override
  void initState() {
    super.initState();
    _database = widget.database ?? FinanceDatabase();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    if (widget.database == null) unawaited(_database.close());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _database.init();
      final entries = await _database.getEntries();
      final budgets = await _database.getBudgets();
      final goals = await _database.getGoals();
      // A tela pode ser removida enquanto o banco responde.
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _budgets = budgets;
        _goals = goals;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível abrir seus dados neste dispositivo.';
        });
      }
    }
  }

  Future<void> _refresh() async {
    final entries = await _database.getEntries();
    final budgets = await _database.getBudgets();
    final goals = await _database.getGoals();
    if (mounted) {
      setState(() {
        _entries = entries;
        _budgets = budgets;
        _goals = goals;
      });
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _edit([FinanceEntry? entry]) async {
    final now = DateTime.now();
    final date = now.year == _month.year && now.month == _month.month
        ? now
        : _month;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => EntryForm(
        entry: entry,
        initialDate: date,
        onSave: (value) async {
          await _database.saveEntry(value);
          await _refresh();
          if (mounted) {
            setState(
              () => _month = DateTime(value.date.year, value.date.month),
            );
          }
        },
      ),
    );
    if (saved == true) {
      _message(
        entry == null ? 'Lançamento adicionado.' : 'Lançamento atualizado.',
      );
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _delete(FinanceEntry entry) async {
    if (!await _confirm(
      'Excluir lançamento?',
      '“${entry.title}” será removido do seu histórico.',
      'Excluir',
    )) {
      return;
    }
    try {
      await _database.deleteEntry(entry.id);
      await _refresh();
      _message('Lançamento excluído.');
    } catch (_) {
      _message('Não foi possível excluir. Tente novamente.');
    }
  }

  Future<void> _demo() async {
    if (_busy) return;
    if (_entries.isNotEmpty &&
        !await _confirm(
          'Adicionar exemplos?',
          'Serão adicionados lançamentos fictícios ao mês selecionado. Seus registros serão mantidos.',
          'Adicionar',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _database.seedDemoData(_month);
      await _refresh();
      _message('Exemplos carregados. São dados fictícios para explorar o app.');
    } catch (_) {
      _message('Não foi possível carregar os exemplos.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (!await _confirm(
      'Apagar todos os dados?',
      'Todos os lançamentos, limites e metas deste dispositivo serão apagados. Esta ação não pode ser desfeita.',
      'Apagar dados',
    )) {
      return;
    }
    try {
      await _database.clearAll();
      await _refresh();
      _message('Dados apagados. Você pode começar de novo.');
    } catch (_) {
      _message('Não foi possível apagar os dados.');
    }
  }

  Future<void> _budget(String category) async {
    final controller = TextEditingController(
      text: moneyInput(_budgets[category] ?? 0),
    );
    final form = GlobalKey<FormState>();
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Limite de $category'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Este limite se repete a cada mês. Use zero para remover.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Limite mensal',
                  prefixText: 'R\$ ',
                ),
                validator: (value) => parseMoney(value ?? '') == null
                    ? 'Use um valor como 500,00.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, parseMoney(controller.text));
              }
            },
            child: const Text('Salvar limite'),
          ),
        ],
      ),
    );
    // O Dialog ainda anima após pop; dispose depois do fim da transição.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (value == null) return;
    try {
      await _database.saveBudget(category, value);
      await _refresh();
      _message('Limite atualizado.');
    } catch (_) {
      _message('Não foi possível salvar o limite.');
    }
  }

  void _about() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Um pouco mais de clareza.'),
      content: const SingleChildScrollView(
        child: Text(
          'Saldo é um projeto acadêmico de organização financeira pessoal.\n\nSeus lançamentos ficam no banco SQLite deste dispositivo. Não há login, sincronização ou conexão com seu banco. No navegador, limpar os dados do site também apaga o banco local.\n\nA cotação do dólar vem da API pública Frankfurter. É uma referência diária, não uma cotação em tempo real. Seus lançamentos não são enviados à API.\n\nO resultado do mês considera receitas recebidas e despesas pagas. Pendentes entram na previsão; os limites incluem as despesas pagas e pendentes. As metas são um acompanhamento manual e não movimentam o saldo.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
  void _changeMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _togglePaid(FinanceEntry entry) async {
    try {
      await _database.saveEntry(entry.copyWith(isPaid: !entry.isPaid));
      await _refresh();
      _message(
        entry.isPaid
            ? 'Lançamento marcado como pendente.'
            : 'Lançamento concluído. Resultado atualizado.',
      );
    } catch (_) {
      _message('Não foi possível atualizar o lançamento.');
    }
  }

  Future<void> _saveGoal(SavingsGoal goal) async {
    await _database.saveGoal(goal);
    await _refresh();
    _message('Meta atualizada. Cada passo conta!');
  }

  Future<void> _deleteGoal(SavingsGoal goal) async {
    if (!await _confirm(
      'Excluir meta?',
      'O acompanhamento de “${goal.title}” será apagado. Isso não altera seus lançamentos.',
      'Excluir meta',
    )) {
      return;
    }
    try {
      await _database.deleteGoal(goal.id);
      await _refresh();
      _message('Meta excluída.');
    } catch (_) {
      _message('Não foi possível excluir a meta.');
    }
  }

  Future<void> _backup() => showDialog<void>(
    context: context,
    builder: (_) => BackupDialog(
      onExport: _database.exportBackup,
      onImport: (data) async {
        await _database.importBackup(data);
        await _refresh();
      },
    ),
  );

  Widget _goalTeaser() {
    final goal = _goals.isEmpty ? null : _goals.first;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lime,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flag_outlined, color: ink),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Seu próximo objetivo',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            goal?.title ?? 'O que você quer conquistar?',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            goal == null
                ? 'Um notebook, uma reserva ou uma viagem. Transforme a ideia em uma meta.'
                : '${(goal.progress * 100).toStringAsFixed(0)}% da meta já foi reservado no seu acompanhamento.',
            style: const TextStyle(color: muted, height: 1.5),
          ),
          if (goal != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: canvas,
                color: green,
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _tab = 3),
            child: Text(
              goal == null
                  ? 'Criar minha primeira meta →'
                  : 'Acompanhar minhas metas →',
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingPanel(MonthSummary summary) {
    final pending = summary.entries.where((entry) => !entry.isPaid).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Panel(
      padding: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_outlined, color: coral, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'No seu radar',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _tab = 1;
                  _onlyPending = true;
                  _filter = 0;
                  _query = '';
                  _search.clear();
                }),
                child: Text('Ver ${pending.length}'),
              ),
            ],
          ),
          const Text(
            'Pendências do mês, por vencimento.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final entry in pending.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${entry.date.isBefore(today) ? 'Vencido em' : 'Vence em'} ${DateFormat('dd/MM').format(entry.date)} · ${entry.isIncome ? 'A receber' : 'A pagar'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: entry.date.isBefore(today) ? coral : muted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          money(entry.amountCents),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _togglePaid(entry),
                    tooltip:
                        '${entry.isIncome ? 'Receber' : 'Pagar'} ${entry.title}',
                    icon: const Icon(Icons.check_rounded, size: 20),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final summary = MonthSummary(_entries, _month);
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _sidebar(),
            Expanded(
              child: Column(
                children: [
                  _topBar(wide),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 44,
                                  color: muted,
                                ),
                                const SizedBox(height: 16),
                                Text(_error!),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _loading = true);
                                    _load();
                                  },
                                  child: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            key: ValueKey(_tab),
                            padding: EdgeInsets.fromLTRB(
                              wide ? 36 : 20,
                              28,
                              wide ? 36 : 20,
                              100,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1180,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _heading(wide),
                                    const SizedBox(height: 26),
                                    if (_tab == 0)
                                      _dashboard(summary)
                                    else if (_tab == 1)
                                      _history(summary)
                                    else if (_tab == 2)
                                      _planning(summary)
                                    else
                                      GoalsView(
                                        goals: _goals,
                                        onSave: _saveGoal,
                                        onDelete: _deleteGoal,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: !wide && _tab != 3 && !_loading && _error == null
          ? FloatingActionButton.extended(
              onPressed: () => _edit(),
              backgroundColor: ink,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Novo lançamento'),
            )
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (index) => setState(() => _tab = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard_rounded),
                  label: 'Visão geral',
                ),
                NavigationDestination(
                  icon: Icon(Icons.swap_vert_rounded),
                  label: 'Lançamentos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.donut_small_outlined),
                  label: 'Planejamento',
                ),
                NavigationDestination(
                  icon: Icon(Icons.flag_outlined),
                  selectedIcon: Icon(Icons.flag_rounded),
                  label: 'Metas',
                ),
              ],
            ),
    );
  }

  Widget _logo() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 37,
        height: 37,
        decoration: BoxDecoration(
          color: lime,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.stacked_bar_chart_rounded, color: ink),
      ),
      const SizedBox(width: 10),
      const Text(
        'saldo',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 27,
          letterSpacing: -1,
          color: ink,
        ),
      ),
      const Text(
        '.',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 29,
          color: green,
        ),
      ),
    ],
  );
  Widget _sidebar() => Container(
    width: 228,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: line)),
    ),
    padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _logo(),
        const SizedBox(height: 12),
        const Text(
          'Seu dinheiro, com direção.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 46),
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 14),
          child: Text(
            'SEU ESPAÇO',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.7,
            ),
          ),
        ),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: _tab == i ? const Color(0xFFEDF5E4) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(
                  [
                    Icons.space_dashboard_outlined,
                    Icons.swap_vert_rounded,
                    Icons.donut_small_outlined,
                    Icons.flag_outlined,
                  ][i],
                  size: 22,
                  color: _tab == i ? green : muted,
                ),
                title: Text(
                  ['Visão geral', 'Lançamentos', 'Planejamento', 'Metas'][i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w500,
                    color: _tab == i ? green : muted,
                  ),
                ),
                onTap: () => setState(() => _tab = i),
              ),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: canvas,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.spa_outlined, color: green),
              SizedBox(height: 12),
              Text(
                'Pequenos hábitos.\nGrandes conquistas.',
                style: TextStyle(fontWeight: FontWeight.w700, height: 1.5),
              ),
              SizedBox(height: 8),
              Text(
                'Organizar hoje é cuidar do seu amanhã.',
                style: TextStyle(fontSize: 12, color: muted, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _topBar(bool wide) => Container(
    height: 82,
    padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 20),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        if (wide)
          const Text(
            'FINANÇAS PESSOAIS',
            style: TextStyle(
              color: muted,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: _logo()),
            ),
          ),
        if (wide) const Spacer(),
        if (wide)
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 14, color: muted),
              const SizedBox(width: 6),
              const Text(
                'Dados neste dispositivo',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(width: 22),
            ],
          ),
        PopupMenuButton<String>(
          tooltip: 'Configurações',
          icon: const Icon(Icons.tune_rounded, color: ink),
          onSelected: (value) {
            if (value == 'about') _about();
            if (value == 'backup' && !_loading && _error == null) _backup();
            if (value == 'demo' && !_loading && _error == null) _demo();
            if (value == 'clear' && !_loading && _error == null) _clear();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'about', child: Text('Sobre o Saldo')),
            PopupMenuItem(
              value: 'backup',
              enabled: !_loading && _error == null,
              child: const Text('Backup e restauração'),
            ),
            PopupMenuItem(
              value: 'demo',
              enabled: !_busy && !_loading && _error == null,
              child: const Text('Carregar dados de exemplo'),
            ),
            PopupMenuItem(
              value: 'clear',
              enabled: !_busy && !_loading && _error == null,
              child: const Text('Apagar dados locais'),
            ),
          ],
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Backup dos dados',
          onPressed: _loading || _error != null ? null : _backup,
          icon: const Icon(Icons.cloud_download_outlined, color: green),
        ),
      ],
    ),
  );
  Widget _heading(bool wide) {
    final title = [
      'Seu mês, mais leve.',
      'Tudo no seu lugar.',
      'Um plano para ir além.',
      'Dê um destino aos seus sonhos.',
    ][_tab];
    final subtitle = [
      'Mais clareza para fazer boas escolhas.',
      'Acompanhe cada entrada e cada saída.',
      'Defina limites. Transforme intenção em hábito.',
      'Uma conquista de cada vez, em reais ou dólares.',
    ][_tab];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: wide
              ? Theme.of(context).textTheme.headlineLarge
              : Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: muted)),
        if (_tab != 3) const SizedBox(height: 24),
        if (_tab != 3)
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Mês anterior',
                      onPressed: _month.year <= 2000 && _month.month == 1
                          ? null
                          : () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left, size: 20),
                    ),
                    Text(
                      DateFormat('MMMM yyyy', 'pt_BR').format(_month),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Próximo mês',
                      onPressed: _month.year >= 2100 && _month.month == 12
                          ? null
                          : () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right, size: 20),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (wide)
                FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text('Novo lançamento'),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dashboard(MonthSummary summary) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MonthlyOverview(summary: summary),
      const SizedBox(height: 20),
      if (summary.entries.any((e) => !e.isPaid)) ...[
        _pendingPanel(summary),
        const SizedBox(height: 20),
      ],
      if (_entries.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seu próximo passo começa aqui.',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Registre seu primeiro lançamento ou explore com dados fictícios.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _edit(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Começar agora'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _demo,
                      child: Text(
                        _busy ? 'Carregando…' : 'Explorar demonstração',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      LayoutBuilder(
        builder: (context, constraints) {
          final left = Column(
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Últimos lançamentos',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _tab = 1),
                          child: const Text('Ver todos'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (summary.entries.isEmpty)
                      _empty(
                        'Nenhum lançamento neste mês.',
                        'Que tal começar pelo café de hoje?',
                      )
                    else
                      for (final entry in summary.entries.take(5))
                        EntryTile(
                          entry: entry,
                          onEdit: () => _edit(entry),
                          onDelete: () => _delete(entry),
                          onTogglePaid: () => _togglePaid(entry),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _insight(summary),
              const SizedBox(height: 20),
              _goalTeaser(),
            ],
          );
          final right = Column(
            children: [
              ExpenseChart(summary: summary),
              const SizedBox(height: 20),
              const ExchangeCard(),
            ],
          );
          return constraints.maxWidth >= 760
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: left),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: right),
                  ],
                )
              : Column(children: [left, const SizedBox(height: 20), right]);
        },
      ),
    ],
  );
  Widget _insight(MonthSummary summary) {
    final text = summary.entries.isEmpty
        ? 'Registrar os pequenos gastos ajuda a enxergar o mês inteiro.'
        : summary.balance < 0
        ? 'As despesas superaram as receitas em ${money(-summary.balance)}. Reveja seus limites no planejamento.'
        : summary.income == 0
        ? 'Registre suas receitas para acompanhar o resultado do mês.'
        : '${(summary.balance / summary.income * 100).toStringAsFixed(0)}% das receitas do mês ainda não foram consumidas pelas despesas registradas.';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF4E2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: green),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Um olhar sobre seu mês',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: Color(0xFF51654D),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _tab = 2),
                  child: const Text('Revisar planejamento →'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _history(MonthSummary summary) {
    final entries = summary.entries
        .where(
          (entry) =>
              (!_onlyPending || !entry.isPaid) &&
              (_filter == 0 ||
                  (_filter == 1 ? entry.isIncome : !entry.isIncome)) &&
              ('${entry.title} ${entry.category}'.toLowerCase().contains(
                _query.toLowerCase(),
              )),
        )
        .toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Buscar descrição ou categoria',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text(['Todos', 'Receitas', 'Despesas'][i]),
                  selected: _filter == i,
                  onSelected: (_) => setState(() => _filter = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Só pendentes'),
              selected: _onlyPending,
              onSelected: (value) => setState(() => _onlyPending = value),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '${entries.length} lançamento(s) no filtro',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            _empty(
              'Nada por aqui ainda.',
              'Adicione um lançamento ou ajuste os filtros.',
            )
          else
            for (final entry in entries)
              EntryTile(
                entry: entry,
                onEdit: () => _edit(entry),
                onDelete: () => _delete(entry),
                onTogglePaid: () => _togglePaid(entry),
              ),
        ],
      ),
    );
  }

  Widget _planning(MonthSummary summary) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF4E2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.track_changes_rounded, color: green),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Seus limites se repetem a cada mês. O consumo inclui despesas pagas e pendentes do mês selecionado.',
                style: TextStyle(color: ink, height: 1.5),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      for (final category in expenseCategories)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            padding: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      categoryIcon(category),
                      color: categoryColor(category),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _budget(category),
                          child: Text(
                            (_budgets[category] ?? 0) > 0
                                ? 'Editar limite'
                                : 'Definir limite',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${money(summary.committedByCategory[category] ?? 0)} comprometidos',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      (_budgets[category] ?? 0) > 0
                          ? 'de ${money(_budgets[category]!)}'
                          : 'Sem limite',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: (_budgets[category] ?? 0) == 0
                      ? 0
                      : ((summary.committedByCategory[category] ?? 0) /
                                _budgets[category]!)
                            .clamp(0, 1),
                  backgroundColor: canvas,
                  color:
                      (summary.committedByCategory[category] ?? 0) >
                              (_budgets[category] ?? 0) &&
                          (_budgets[category] ?? 0) > 0
                      ? coral
                      : green,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(10),
                ),
                if ((_budgets[category] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      (summary.committedByCategory[category] ?? 0) >
                              _budgets[category]!
                          ? '${money((summary.committedByCategory[category] ?? 0) - _budgets[category]!)} acima do limite'
                          : '${money(_budgets[category]! - (summary.committedByCategory[category] ?? 0))} disponíveis no limite',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            (summary.committedByCategory[category] ?? 0) >
                                _budgets[category]!
                            ? coral
                            : muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
  Widget _empty(String title, String subtitle) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34),
    child: Center(
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, color: muted, size: 32),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

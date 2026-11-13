import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/finance_entry.dart';
import '../models/savings_goal.dart';

/// Repositório SQLite: a interface não precisa conhecer SQL nem a plataforma.
/// Android: arquivo SQLite no aparelho. Web: SQLite/WASM persistido no IndexedDB.
class FinanceDatabase {
  FinanceDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory,
      _databasePath = databasePath;

  final DatabaseFactory? _factory;
  final String? _databasePath;
  Future<Database>? _opening;

  Future<void> init() async {
    await _db;
  }

  Future<Database> get _db => _opening ??= _open();

  Future<Database> _open() async {
    try {
      final factory =
          _factory ?? (kIsWeb ? databaseFactoryFfiWeb : databaseFactory);
      final databasePath =
          _databasePath ??
          (kIsWeb
              ? 'saldo.db'
              : path.join(await factory.getDatabasesPath(), 'saldo.db'));
      return await factory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE entries (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL CHECK(length(trim(title)) > 0),
                category TEXT NOT NULL,
                amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
                date TEXT NOT NULL,
                is_income INTEGER NOT NULL CHECK(is_income IN (0, 1)),
                is_paid INTEGER NOT NULL DEFAULT 1 CHECK(is_paid IN (0, 1))
              )
            ''');
            await db.execute('CREATE INDEX entries_date ON entries(date)');
            await db.execute('''
              CREATE TABLE budgets (
                category TEXT PRIMARY KEY,
                limit_cents INTEGER NOT NULL CHECK(limit_cents > 0)
              )
            ''');
            await _createGoals(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              // Lançamentos antigos continuam realizados; nenhum dado é apagado.
              await db.execute(
                'ALTER TABLE entries ADD COLUMN is_paid INTEGER NOT NULL DEFAULT 1 CHECK(is_paid IN (0, 1))',
              );
              await _createGoals(db);
            }
          },
        ),
      );
    } catch (_) {
      // Permite tentar novamente depois de uma falha ao inicializar.
      _opening = null;
      rethrow;
    }
  }

  Future<List<FinanceEntry>> getEntries() async {
    final rows = await (await _db).query(
      'entries',
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(FinanceEntry.fromMap).toList();
  }

  Future<void> saveEntry(FinanceEntry entry) async {
    _validateEntry(entry);
    // Os parâmetros são tratados pelo driver; não concatenamos texto do usuário.
    await (await _db).insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteEntry(String id) async {
    await (await _db).delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Limites mensais recorrentes: o mesmo limite vale para cada mês consultado.
  Future<Map<String, int>> getBudgets() async {
    final rows = await (await _db).query('budgets');
    return {
      for (final row in rows)
        row['category'] as String: row['limit_cents'] as int,
    };
  }

  /// Zero remove o limite da categoria; ausência significa "sem limite".
  Future<void> saveBudget(String category, int amountCents) async {
    if (!expenseCategories.contains(category) ||
        amountCents < 0 ||
        amountCents > _maxCents) {
      throw ArgumentError('Categoria ou limite inválido.');
    }
    final db = await _db;
    if (amountCents == 0) {
      await db.delete('budgets', where: 'category = ?', whereArgs: [category]);
      return;
    }
    await db.insert('budgets', {
      'category': category,
      'limit_cents': amountCents,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static const _maxCents = 99999999999;

  static Future<void> _createGoals(DatabaseExecutor db) => db.execute('''
    CREATE TABLE goals (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      target_cents INTEGER NOT NULL CHECK(target_cents > 0),
      saved_cents INTEGER NOT NULL CHECK(saved_cents >= 0 AND saved_cents <= target_cents),
      currency TEXT NOT NULL CHECK(currency IN ('BRL', 'USD')),
      deadline TEXT
    )
  ''');

  static bool _validDate(DateTime date) =>
      date.year >= 2000 && date.year <= 2100;

  static void _validateEntry(FinanceEntry entry) {
    if (entry.id.trim().isEmpty ||
        entry.id.length > 150 ||
        entry.title.trim().isEmpty ||
        entry.title.length > 60 ||
        entry.amountCents <= 0 ||
        entry.amountCents > _maxCents ||
        !_validDate(entry.date)) {
      throw ArgumentError(
        'Lançamento inválido: confira descrição, data e valor.',
      );
    }
    final categories = entry.isIncome ? incomeCategories : expenseCategories;
    if (!categories.contains(entry.category)) {
      throw ArgumentError('Categoria inválida para esse lançamento.');
    }
  }

  static void _validateGoal(SavingsGoal goal) {
    if (goal.id.trim().isEmpty ||
        goal.id.length > 150 ||
        goal.title.trim().isEmpty ||
        goal.title.length > 60 ||
        goal.targetCents <= 0 ||
        goal.targetCents > _maxCents ||
        goal.savedCents < 0 ||
        goal.savedCents > goal.targetCents ||
        !const ['BRL', 'USD'].contains(goal.currency) ||
        (goal.deadline != null && !_validDate(goal.deadline!))) {
      throw ArgumentError(
        'Meta inválida: confira nome, moeda, data e valores.',
      );
    }
  }

  Future<List<SavingsGoal>> getGoals() async {
    final rows = await (await _db).query(
      'goals',
      orderBy: 'title COLLATE NOCASE',
    );
    return rows.map(SavingsGoal.fromMap).toList();
  }

  Future<void> saveGoal(SavingsGoal goal) async {
    _validateGoal(goal);
    await (await _db).insert(
      'goals',
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteGoal(String id) async {
    await (await _db).delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  /// Snapshot consistente de todas as tabelas em um formato JSON versionado.
  Future<Map<String, dynamic>> exportBackup() async {
    final db = await _db;
    return db.transaction(
      (txn) async => {
        'app': 'saldo',
        'schemaVersion': 2,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'entries': await txn.query('entries', orderBy: 'id'),
        'budgets': await txn.query('budgets', orderBy: 'category'),
        'goals': await txn.query('goals', orderBy: 'id'),
      },
    );
  }

  /// Valida tudo antes de substituir; uma falha mantém o banco anterior intacto.
  /// A interface deve pedir confirmação antes de chamar este método.
  Future<void> importBackup(Map<String, dynamic> backup) async {
    if (backup['app'] != 'saldo' ||
        backup['schemaVersion'] != 2 ||
        backup['entries'] is! List ||
        backup['budgets'] is! List ||
        backup['goals'] is! List) {
      throw const FormatException(
        'O arquivo não é um backup Saldo compatível.',
      );
    }
    final entries = <FinanceEntry>[];
    final budgets = <String, int>{};
    final goals = <SavingsGoal>[];
    final entryIds = <String>{};
    final goalIds = <String>{};
    try {
      for (final raw in backup['entries'] as List) {
        final row = _backupRow(raw);
        if (!_isFlag(row['is_income']) || !_isFlag(row['is_paid'])) {
          throw const FormatException(
            'Tipo ou situação do lançamento inválido.',
          );
        }
        _parseBackupDate(row['date']);
        final entry = FinanceEntry.fromMap(row);
        _validateEntry(entry);
        if (!entryIds.add(entry.id)) {
          throw const FormatException('Lançamento duplicado.');
        }
        entries.add(entry);
      }
      for (final raw in backup['budgets'] as List) {
        final row = _backupRow(raw);
        final category = row['category'];
        final cents = row['limit_cents'];
        if (category is! String ||
            !expenseCategories.contains(category) ||
            cents is! int ||
            cents <= 0 ||
            cents > _maxCents ||
            budgets.containsKey(category)) {
          throw const FormatException('Limite de categoria inválido.');
        }
        budgets[category] = cents;
      }
      for (final raw in backup['goals'] as List) {
        final row = _backupRow(raw);
        if (row['deadline'] != null) _parseBackupDate(row['deadline']);
        final goal = SavingsGoal.fromMap(row);
        _validateGoal(goal);
        if (!goalIds.add(goal.id)) {
          throw const FormatException('Meta duplicada.');
        }
        goals.add(goal);
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'O backup contém campos ou valores inválidos.',
      );
    }
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('entries');
      await txn.delete('budgets');
      await txn.delete('goals');
      for (final entry in entries) {
        await txn.insert('entries', entry.toMap());
      }
      for (final budget in budgets.entries) {
        await txn.insert('budgets', {
          'category': budget.key,
          'limit_cents': budget.value,
        });
      }
      for (final goal in goals) {
        await txn.insert('goals', goal.toMap());
      }
    });
  }

  static Map<String, Object?> _backupRow(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Registro inválido.');
    }
    return Map<String, Object?>.from(raw);
  }

  static bool _isFlag(Object? value) =>
      value is int && (value == 0 || value == 1);

  static void _parseBackupDate(Object? raw) {
    if (raw is! String) throw const FormatException('Data inválida.');
    final date = DateTime.tryParse(raw);
    if (date == null || !_validDate(date) || date.toIso8601String() != raw) {
      throw const FormatException('Data inválida.');
    }
  }

  /// Executado somente quando a pessoa escolhe carregar os exemplos.
  /// IDs determinísticos tornam a operação repetível, sem duplicar lançamentos.
  Future<void> seedDemoData(DateTime month) async {
    final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final examples = <(String, String, int, int, bool)>[
      ('Salário do mês', 'Salário', 480000, 5, true),
      ('Projeto freelance', 'Freelance', 40000, 18, true),
      ('Aluguel', 'Moradia', 145000, 6, false),
      ('Compras do mercado', 'Alimentação', 42800, 8, false),
      ('Almoços da semana', 'Alimentação', 24900, 20, false),
      ('Transporte do mês', 'Transporte', 18900, 10, false),
      ('Farmácia', 'Saúde', 12500, 16, false),
      ('Curso de Flutter', 'Educação', 15900, 21, false),
      ('Passeio de fim de semana', 'Lazer', 24500, 24, false),
    ];
    final db = await _db;
    await db.transaction((txn) async {
      for (var i = 0; i < examples.length; i++) {
        final (title, category, cents, day, income) = examples[i];
        final entry = FinanceEntry(
          id: 'demo-$monthKey-$i',
          title: title,
          category: category,
          amountCents: cents,
          date: DateTime(month.year, month.month, day),
          isIncome: income,
        );
        await txn.insert(
          'entries',
          entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      const limits = {
        'Alimentação': 80000,
        'Moradia': 160000,
        'Transporte': 25000,
        'Lazer': 30000,
        'Saúde': 20000,
        'Educação': 20000,
      };
      for (final entry in limits.entries) {
        await txn.insert('budgets', {
          'category': entry.key,
          'limit_cents': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final goal in [
        const SavingsGoal(
          id: 'demo-goal-notebook',
          title: 'Meu próximo notebook',
          targetCents: 400000,
          savedCents: 120000,
        ),
        const SavingsGoal(
          id: 'demo-goal-travel',
          title: 'Viagem dos sonhos',
          targetCents: 100000,
          savedCents: 20000,
          currency: 'USD',
        ),
      ]) {
        await txn.insert(
          'goals',
          goal.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<void> clearAll() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('entries');
      await txn.delete('budgets');
      await txn.delete('goals');
    });
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }

  Future<void> dispose() => close();
}

import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/data/finance_database.dart';
import 'package:saldo/models/finance_entry.dart';
import 'package:saldo/models/savings_goal.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporary;
  late FinanceDatabase database;
  late String databasePath;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('saldo_database_test_');
    databasePath = '${temporary.path}/test.db';
    database = FinanceDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    await database.init();
  });
  tearDown(() async {
    await database.close();
    await temporary.delete(recursive: true);
  });

  test('cria vazio e persiste lançamento depois de fechar e reabrir', () async {
    expect(await database.getEntries(), isEmpty);
    final entry = FinanceEntry(
      id: '1',
      title: "Café d'Ávila",
      category: 'Alimentação',
      amountCents: 1234,
      date: DateTime(2026, 10, 29),
      isIncome: false,
    );
    await database.saveEntry(entry);
    await database.close();
    database = FinanceDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final saved = (await database.getEntries()).single;
    expect(saved.toMap(), entry.toMap());
  });

  test('edita pelo id e exclui somente o lançamento escolhido', () async {
    await database.seedDemoData(DateTime(2026, 10));
    final original = (await database.getEntries()).first;
    await database.saveEntry(
      FinanceEntry(
        id: original.id,
        title: 'Valor corrigido',
        category: original.category,
        amountCents: 22222,
        date: original.date,
        isIncome: original.isIncome,
      ),
    );
    final entries = await database.getEntries();
    expect(entries, hasLength(9));
    expect(entries.first.amountCents, 22222);
    await database.deleteEntry(original.id);
    expect(await database.getEntries(), hasLength(8));
  });

  test(
    'exemplos são idempotentes e os totais em centavos são exatos',
    () async {
      await database.seedDemoData(DateTime(2026, 10));
      await database.seedDemoData(DateTime(2026, 10));
      final entries = await database.getEntries();
      expect(entries, hasLength(9));
      final income = entries
          .where((e) => e.isIncome)
          .fold(0, (sum, e) => sum + e.amountCents);
      final expenses = entries
          .where((e) => !e.isIncome)
          .fold(0, (sum, e) => sum + e.amountCents);
      expect(income, 520000);
      expect(expenses, 284500);
      expect(income - expenses, 235500);
    },
  );

  test('limite pode ser definido, editado e removido', () async {
    await database.saveBudget('Alimentação', 50000);
    expect((await database.getBudgets())['Alimentação'], 50000);
    await database.saveBudget('Alimentação', 60000);
    expect((await database.getBudgets())['Alimentação'], 60000);
    await database.saveBudget('Alimentação', 0);
    expect(await database.getBudgets(), isEmpty);
  });

  test('rejeita valores negativos e categoria incompatível', () async {
    await expectLater(database.saveBudget('Lazer', -1), throwsArgumentError);
    await expectLater(
      database.saveEntry(
        FinanceEntry(
          id: 'bad',
          title: 'Inválido',
          category: 'Salário',
          amountCents: 100,
          date: DateTime(2026, 10),
          isIncome: false,
        ),
      ),
      throwsArgumentError,
    );
    expect(await database.getEntries(), isEmpty);
  });

  test('limpeza remove lançamentos e limites juntos', () async {
    await database.seedDemoData(DateTime(2026, 10));
    await database.clearAll();
    expect(await database.getEntries(), isEmpty);
    expect(await database.getBudgets(), isEmpty);
    expect(await database.getGoals(), isEmpty);
  });

  test(
    'migração v1 preserva lançamentos e limites e marca históricos pagos',
    () async {
      await database.close();
      final legacyPath = '${temporary.path}/legacy.db';
      final old = await databaseFactoryFfi.openDatabase(
        legacyPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE entries (id TEXT PRIMARY KEY, title TEXT NOT NULL, category TEXT NOT NULL, amount_cents INTEGER NOT NULL, date TEXT NOT NULL, is_income INTEGER NOT NULL)',
            );
            await db.execute('CREATE INDEX entries_date ON entries(date)');
            await db.execute(
              'CREATE TABLE budgets (category TEXT PRIMARY KEY, limit_cents INTEGER NOT NULL)',
            );
          },
        ),
      );
      await old.insert('entries', {
        'id': 'legacy',
        'title': 'Mercado antigo',
        'category': 'Alimentação',
        'amount_cents': 12345,
        'date': DateTime(2026, 10, 1).toIso8601String(),
        'is_income': 0,
      });
      await old.insert('budgets', {
        'category': 'Alimentação',
        'limit_cents': 70000,
      });
      await old.close();
      database = FinanceDatabase(
        factory: databaseFactoryFfi,
        databasePath: legacyPath,
      );
      final entry = (await database.getEntries()).single;
      expect(entry.id, 'legacy');
      expect(entry.amountCents, 12345);
      expect(entry.isPaid, isTrue);
      expect(await database.getBudgets(), {'Alimentação': 70000});
      expect(await database.getGoals(), isEmpty);
      await database.saveGoal(
        const SavingsGoal(
          id: 'migrated',
          title: 'Reserva',
          targetCents: 100000,
          savedCents: 0,
        ),
      );
      expect((await database.getGoals()).single.title, 'Reserva');
    },
  );

  test('situação pendente é persistida e pode ser marcada como paga', () async {
    final entry = FinanceEntry(
      id: 'pending',
      title: 'Internet',
      category: 'Moradia',
      amountCents: 9900,
      date: DateTime(2026, 11, 10),
      isIncome: false,
      isPaid: false,
    );
    await database.saveEntry(entry);
    expect((await database.getEntries()).single.isPaid, isFalse);
    await database.saveEntry(entry.copyWith(isPaid: true));
    final entries = await database.getEntries();
    expect(entries, hasLength(1));
    expect(entries.single.isPaid, isTrue);
    expect(entries.single.amountCents, 9900);
  });

  test(
    'meta USD persiste, atualiza e exclui sem alterar lançamentos',
    () async {
      await database.seedDemoData(DateTime(2026, 11));
      final before = (await database.getEntries())
          .map((e) => e.toMap())
          .toList();
      final goal = SavingsGoal(
        id: 'trip',
        title: 'Viagem',
        targetCents: 100000,
        savedCents: 20000,
        currency: 'USD',
        deadline: DateTime(2027, 4, 1),
      );
      await database.saveGoal(goal);
      await database.close();
      expect(
        (await database.getGoals()).firstWhere((g) => g.id == 'trip').toMap(),
        goal.toMap(),
      );
      await database.saveGoal(goal.copyWith(savedCents: 35000));
      expect(
        (await database.getGoals())
            .firstWhere((g) => g.id == 'trip')
            .remainingCents,
        65000,
      );
      await database.deleteGoal('trip');
      expect((await database.getGoals()).any((g) => g.id == 'trip'), isFalse);
      expect(
        (await database.getEntries()).map((e) => e.toMap()).toList(),
        before,
      );
    },
  );

  test('rejeita metas com moeda ou valores inconsistentes', () async {
    const valid = SavingsGoal(
      id: 'g',
      title: 'Reserva',
      targetCents: 10000,
      savedCents: 1000,
    );
    for (final goal in [
      valid.copyWith(currency: 'EUR'),
      valid.copyWith(savedCents: 10001),
      valid.copyWith(savedCents: -1),
      valid.copyWith(targetCents: 0),
    ]) {
      await expectLater(database.saveGoal(goal), throwsArgumentError);
    }
    expect(await database.getGoals(), isEmpty);
  });

  test(
    'backup restaura snapshot completo depois de ida e volta JSON',
    () async {
      await database.seedDemoData(DateTime(2026, 11));
      final first = (await database.getEntries()).first;
      await database.saveEntry(first.copyWith(isPaid: false));
      final snapshot =
          jsonDecode(jsonEncode(await database.exportBackup()))
              as Map<String, dynamic>;
      await database.clearAll();
      await database.saveBudget('Outros', 100);
      await database.importBackup(snapshot);
      final restored = await database.exportBackup();
      for (final table in ['entries', 'budgets', 'goals']) {
        expect(restored[table], snapshot[table]);
      }
      expect((await database.getEntries()).first.isPaid, isFalse);
      expect(await database.getGoals(), hasLength(2));
    },
  );

  test(
    'backup malformado é rejeitado antes de apagar dados existentes',
    () async {
      await database.seedDemoData(DateTime(2026, 11));
      final original = await database.exportBackup();
      for (final alter in <void Function(Map<String, dynamic>)>[
        (b) => b['schemaVersion'] = 999,
        (b) => b['budgets'] = {},
        (b) => b['entries'][0]['amount_cents'] = -10,
        (b) => b['entries'][0]['is_paid'] = 2,
        (b) => b['entries'][0]['date'] = '2026-02-31T00:00:00.000',
        (b) => b['entries'].add(b['entries'][0]),
        (b) => b['goals'][0]['currency'] = 'EUR',
        (b) => b['goals'][0]['saved_cents'] = 99999999,
        (b) => b['budgets'][0]['limit_cents'] = 'abc',
      ]) {
        final bad = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
        alter(bad);
        await expectLater(database.importBackup(bad), throwsFormatException);
        final current = await database.exportBackup();
        for (final table in ['entries', 'budgets', 'goals']) {
          expect(current[table], original[table]);
        }
      }
    },
  );
}

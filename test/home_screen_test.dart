import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saldo/data/finance_database.dart';
import 'package:saldo/models/finance_entry.dart';
import 'package:saldo/screens/home_screen.dart';
import 'package:saldo/theme.dart';
import 'package:saldo/utils/money.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> mountHome(
  WidgetTester tester,
  FinanceDatabase db, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await http.runWithClient(
    () async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: HomeScreen(database: db),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
    },
    () => MockClient(
      (_) async => http.Response(
        '{"date":"2026-10-29","base":"USD","quote":"BRL","rate":5.35}',
        200,
      ),
    ),
  );
}

void main() {
  late FinanceDatabase db;
  final now = DateTime.now();
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('pt_BR');
  });
  setUp(() async {
    db = FinanceDatabase(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    await db.init();
  });
  tearDown(() async => db.close());

  testWidgets('cria despesa pela interface e atualiza o resultado persistido', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await mountHome(tester, db);
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Novo lançamento'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '25,90');
      await tester.enterText(find.byType(TextFormField).at(1), 'Café de teste');
      await tester.ensureVisible(find.text('Salvar lançamento'));
      await tester.tap(find.text('Salvar lançamento'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      final saved = await db.getEntries();
      expect(saved, hasLength(1));
      expect(saved.single.title, 'Café de teste');
      expect(saved.single.amountCents, 2590);
      expect(saved.single.isIncome, isFalse);
      expect(find.text(money(-2590)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('edita, filtra receitas e exclui após confirmação', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await db.saveEntry(
        FinanceEntry(
          id: 'expense',
          title: 'Café',
          category: 'Alimentação',
          amountCents: 1000,
          date: now,
          isIncome: false,
        ),
      );
      await db.saveEntry(
        FinanceEntry(
          id: 'income',
          title: 'Bolsa de estudos',
          category: 'Outros',
          amountCents: 150000,
          date: now,
          isIncome: true,
        ),
      );
      await mountHome(tester, db);
      await tester.tap(find.text('Lançamentos'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Opções de Café'));
      await tester.tap(find.byTooltip('Opções de Café'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '15,75');
      await tester.ensureVisible(find.text('Salvar lançamento'));
      await tester.tap(find.text('Salvar lançamento'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(
        (await db.getEntries())
            .firstWhere((e) => e.id == 'expense')
            .amountCents,
        1575,
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Receitas'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Receitas'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(find.text('Bolsa de estudos'), findsOneWidget);
      expect(find.text('Café'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Opções de Café'));
      await tester.tap(find.byTooltip('Opções de Café'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(await db.getEntries(), hasLength(2));
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect((await db.getEntries()).single.id, 'income');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('troca de mês isola os lançamentos no histórico', (tester) async {
    await tester.runAsync(() async {
      await db.saveEntry(
        FinanceEntry(
          id: 'now',
          title: 'Mês atual',
          category: 'Lazer',
          amountCents: 1000,
          date: now,
          isIncome: false,
        ),
      );
      await db.saveEntry(
        FinanceEntry(
          id: 'before',
          title: 'Mês passado',
          category: 'Lazer',
          amountCents: 2000,
          date: DateTime(now.year, now.month - 1, 15),
          isIncome: false,
        ),
      );
      await mountHome(tester, db);
      await tester.tap(find.text('Lançamentos'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(find.text('Mês atual'), findsOneWidget);
      expect(find.text('Mês passado'), findsNothing);
      await tester.tap(find.byTooltip('Mês anterior'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(find.text('Mês atual'), findsNothing);
      expect(find.text('Mês passado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('painel e planejamento cabem em celular com texto ampliado', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await db.seedDemoData(now);
      await mountHome(tester, db, scale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Planejamento'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('concluir pendência muda resultado e salva situação no banco', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await db.saveEntry(
        FinanceEntry(
          id: 'income',
          title: 'Bolsa',
          category: 'Outros',
          amountCents: 10000,
          date: now,
          isIncome: true,
        ),
      );
      await db.saveEntry(
        FinanceEntry(
          id: 'bill',
          title: 'Internet',
          category: 'Moradia',
          amountCents: 2500,
          date: now,
          isIncome: false,
          isPaid: false,
        ),
      );
      await mountHome(tester, db);
      expect(find.text('Previsão ao concluir tudo'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Pagar Internet'));
      await tester.tap(find.byTooltip('Pagar Internet'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(
        (await db.getEntries()).firstWhere((e) => e.id == 'bill').isPaid,
        isTrue,
      );
      expect(find.text('Previsão ao concluir tudo'), findsNothing);
      expect(find.text(money(7500)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

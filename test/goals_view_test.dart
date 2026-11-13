import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saldo/models/savings_goal.dart';
import 'package:saldo/screens/goals_view.dart';
import 'package:saldo/services/exchange_service.dart';
import 'package:saldo/theme.dart';

const _quote = '{"date":"2026-11-03","base":"USD","quote":"BRL","rate":5.35}';
const _brlGoal = SavingsGoal(
  id: 'g1',
  title: 'Notebook para estudar',
  targetCents: 400000,
  savedCents: 120000,
);

Widget _app({
  List<SavingsGoal> goals = const [],
  ExchangeService? service,
  Future<void> Function(SavingsGoal)? onSave,
  double scale = 1,
}) => MaterialApp(
  theme: appTheme,
  locale: const Locale('pt', 'BR'),
  supportedLocales: const [Locale('pt', 'BR')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GoalsView(
          goals: goals,
          service: service,
          onSave: onSave ?? (_) async {},
          onDelete: (_) async {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'meta em dólar mostra referência e estimativa em tela estreita com fonte ampliada',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ExchangeService(
        client: MockClient((_) async => http.Response(_quote, 200)),
      );
      await tester.pumpWidget(
        _app(
          goals: [
            SavingsGoal(
              id: 'usd',
              title: 'Viagem de formatura',
              targetCents: 100000,
              savedCents: 20000,
              currency: 'USD',
              deadline: DateTime(2027, 12, 1),
            ),
          ],
          service: service,
          scale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('03/11/2026'), findsOneWidget);
      expect(find.textContaining('5.350,00'), findsOneWidget);
      expect(find.textContaining('4.280,00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('formulário rejeita meta vazia e guarda valores em centavos', (
    tester,
  ) async {
    SavingsGoal? saved;
    await tester.pumpWidget(_app(onSave: (goal) async => saved = goal));
    await tester.tap(find.text('Nova meta'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar meta'));
    await tester.tap(find.text('Salvar meta'));
    await tester.pumpAndSettle();
    expect(find.text('Dê um nome à sua meta.'), findsOneWidget);
    expect(saved, isNull);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Reserva de emergência',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '5.000,00');
    await tester.enterText(find.byType(TextFormField).at(2), '125,90');
    await tester.ensureVisible(find.text('Salvar meta'));
    await tester.tap(find.text('Salvar meta'));
    await tester.pumpAndSettle();
    expect(saved?.title, 'Reserva de emergência');
    expect(saved?.targetCents, 500000);
    expect(saved?.savedCents, 12590);
    expect(saved?.currency, 'BRL');
    expect(find.text('Criar uma meta'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'guardar limita o valor ao que falta e atualiza sem criar lançamento',
    (tester) async {
      SavingsGoal? saved;
      await tester.pumpWidget(
        _app(goals: const [_brlGoal], onSave: (goal) async => saved = goal),
      );
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '3000,00');
      await tester.tap(find.text('Confirmar valor'));
      await tester.pumpAndSettle();
      expect(find.textContaining('O máximo é'), findsOneWidget);
      expect(saved, isNull);
      await tester.enterText(find.byType(TextFormField), '50,25');
      await tester.tap(find.text('Confirmar valor'));
      await tester.pumpAndSettle();
      expect(saved?.id, 'g1');
      expect(saved?.targetCents, 400000);
      expect(saved?.savedCents, 125025);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retirar não permite valor maior do que o guardado', (
    tester,
  ) async {
    SavingsGoal? saved;
    await tester.pumpWidget(
      _app(goals: const [_brlGoal], onSave: (goal) async => saved = goal),
    );
    await tester.ensureVisible(find.text('Retirar'));
    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '1201');
    await tester.tap(find.text('Confirmar valor'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    await tester.enterText(find.byType(TextFormField), '1200');
    await tester.tap(find.text('Confirmar valor'));
    await tester.pumpAndSettle();
    expect(saved?.savedCents, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'falha de câmbio mantém meta disponível e permite tentar novamente',
    (tester) async {
      var attempts = 0;
      final service = ExchangeService(
        client: MockClient(
          (_) async => ++attempts == 1
              ? http.Response('indisponível', 503)
              : http.Response(_quote, 200),
        ),
      );
      await tester.pumpWidget(
        _app(
          goals: const [
            SavingsGoal(
              id: 'usd',
              title: 'Viagem',
              targetCents: 100000,
              savedCents: 20000,
              currency: 'USD',
            ),
          ],
          service: service,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Estimativa indisponível'), findsOneWidget);
      expect(find.text('Viagem'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      await tester.ensureVisible(find.text('Tentar novamente'));
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.textContaining('5.350,00'), findsOneWidget);
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );
}

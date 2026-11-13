import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saldo/services/exchange_service.dart';
import 'package:saldo/widgets/exchange_card.dart';

const _body = '{"date":"2026-10-29","base":"USD","quote":"BRL","rate":5.35}';

Widget _app(ExchangeService service) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: SizedBox(width: 320, child: ExchangeCard(service: service)),
    ),
  ),
);

void main() {
  testWidgets(
    'mostra cotação, data e conversão sem overflow em tela estreita',
    (tester) async {
      final service = ExchangeService(
        client: MockClient((_) async => http.Response(_body, 200)),
      );
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      expect(find.text('Referência: 29/10/2026'), findsOneWidget);
      expect(find.textContaining('535,00'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '20,50');
      await tester.pump();
      expect(find.textContaining('109,68'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('permite tentar novamente após falha HTTP', (tester) async {
    var calls = 0;
    final service = ExchangeService(
      client: MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('Unavailable', 503)
            : http.Response(_body, 200);
      }),
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Referência: 29/10/2026'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('ignora resposta que chega depois de dispose', (tester) async {
    final response = Completer<http.Response>();
    final service = ExchangeService(client: MockClient((_) => response.future));
    await tester.pumpWidget(_app(service));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    response.complete(http.Response(_body, 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

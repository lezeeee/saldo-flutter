import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saldo/services/exchange_service.dart';

void main() {
  test(
    'consulta USD/BRL e interpreta o valor e a data de referência',
    () async {
      final service = ExchangeService(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.frankfurter.dev/v2/rate/USD/BRL',
          );
          return http.Response(
            '{"date":"2026-10-29","base":"USD","quote":"BRL","rate":5.3544}',
            200,
          );
        }),
      );
      final quote = await service.fetchDollarQuote();
      expect(quote.rate, 5.3544);
      expect(quote.date, DateTime(2026, 10, 29));
    },
  );

  test('converte falha HTTP em mensagem utilizável pela interface', () async {
    final service = ExchangeService(
      client: MockClient((_) async => http.Response('Unavailable', 503)),
    );
    await expectLater(
      service.fetchDollarQuote(),
      throwsA(
        isA<ExchangeException>().having(
          (e) => e.message,
          'message',
          contains('indisponível'),
        ),
      ),
    );
  });

  for (final body in [
    '{}',
    'invalid json',
    '{"date":"2026-10-29","base":"EUR","quote":"BRL","rate":5.35}',
    '{"date":"2026-10-29","base":"USD","quote":"BRL","rate":-5.35}',
    '{"date":"2026-02-31","base":"USD","quote":"BRL","rate":5.35}',
    '{"date":"2026-10-29","base":"USD","quote":"BRL","rate":"5.35"}',
  ]) {
    test('rejeita resposta inválida: $body', () async {
      final service = ExchangeService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        service.fetchDollarQuote(),
        throwsA(isA<ExchangeException>()),
      );
    });
  }

  test('informa erro de conexão', () async {
    final service = ExchangeService(
      client: MockClient((_) async => throw http.ClientException('network')),
    );
    await expectLater(
      service.fetchDollarQuote(),
      throwsA(
        isA<ExchangeException>().having(
          (e) => e.message,
          'message',
          contains('conexão'),
        ),
      ),
    );
  });

  test('limita o tempo de espera', () async {
    final response = Completer<http.Response>();
    final service = ExchangeService(
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) => response.future),
    );
    await expectLater(
      service.fetchDollarQuote(),
      throwsA(
        isA<ExchangeException>().having(
          (e) => e.message,
          'message',
          contains('demorou'),
        ),
      ),
    );
    response.complete(http.Response('{}', 200));
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Valor de referência de um dólar em reais e a data informada pela API.
class DollarQuote {
  const DollarQuote({required this.rate, required this.date});

  final double rate;
  final DateTime date;
}

class ExchangeException implements Exception {
  const ExchangeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Serviço HTTP separado da interface para facilitar testes e explicação.
/// Documentação pública: https://frankfurter.dev/ (API v2, sem chave).
class ExchangeService {
  ExchangeService({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  static final endpoint = Uri.https('api.frankfurter.dev', '/v2/rate/USD/BRL');

  Future<DollarQuote> fetchDollarQuote() async {
    try {
      final response = await _client.get(endpoint).timeout(timeout);
      if (response.statusCode != 200) {
        throw const ExchangeException(
          'A cotação está indisponível. Tente novamente.',
        );
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic> ||
          payload['base'] != 'USD' ||
          payload['quote'] != 'BRL' ||
          payload['rate'] is! num ||
          payload['date'] is! String) {
        throw const FormatException('Resposta inesperada da API.');
      }
      final rate = (payload['rate'] as num).toDouble();
      final rawDate = payload['date'] as String;
      final date = DateTime.tryParse(rawDate);
      // DateTime aceita datas que transbordam (ex.: dia 32); confira a volta.
      if (!rate.isFinite ||
          rate <= 0 ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate) ||
          date == null ||
          date.toIso8601String().substring(0, 10) != rawDate) {
        throw const FormatException('Cotação ou data inválida.');
      }
      return DollarQuote(rate: rate, date: date);
    } on ExchangeException {
      rethrow;
    } on TimeoutException {
      throw const ExchangeException(
        'A conexão demorou demais. Tente novamente.',
      );
    } on FormatException {
      throw const ExchangeException('A API retornou uma cotação inválida.');
    } on http.ClientException {
      throw const ExchangeException(
        'Sem acesso à cotação. Verifique sua conexão.',
      );
    } catch (_) {
      throw const ExchangeException(
        'Não foi possível consultar o dólar agora.',
      );
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

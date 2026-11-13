import 'package:intl/intl.dart';

final _brl = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 2,
);
String money(int cents) => _brl.format(cents / 100);

// Inteiros em centavos evitam erros de arredondamento de double.
// Entrada pt-BR: 1250,50 ou 1.250,50. Ponto sozinho é separador de milhar.
int? parseMoney(String input) {
  final value = input.trim().replaceAll('R\$', '').trim();
  if (!RegExp(r'^(\d+|\d{1,3}(\.\d{3})+)(,\d{1,2})?$').hasMatch(value)) {
    return null;
  }
  final parts = value.replaceAll('.', '').split(',');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 999999999) return null;
  return whole * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
}

String moneyInput(int cents) =>
    '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

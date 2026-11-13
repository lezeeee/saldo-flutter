import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/exchange_service.dart';

/// Tem estado próprio: requisição, resultado e valor digitado no conversor.
class ExchangeCard extends StatefulWidget {
  const ExchangeCard({super.key, this.service});
  final ExchangeService? service;

  @override
  State<ExchangeCard> createState() => _ExchangeCardState();
}

class _ExchangeCardState extends State<ExchangeCard> {
  static const _green = Color(0xFF187451);
  static const _ink = Color(0xFF17352B);
  late final ExchangeService _service;
  final _amountController = TextEditingController(text: '100');
  final _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );
  DollarQuote? _quote;
  String? _error;
  bool _loading = true;

  // initState roda uma vez para esta instância de State, nunca a cada build.
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ExchangeService();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quote = await _service.fetchDollarQuote();
      // A tela pode ter saído da árvore durante o await.
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _loading = false;
      });
    } on ExchangeException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  double? get _amount {
    final normalized = _amountController.text.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final amount = _amount;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5EBE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6E4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.currency_exchange_rounded,
                  color: _green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'CÂMBIO • USD / BRL',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: _ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Atualizar cotação',
                onPressed: _loading ? null : _fetch,
                icon: const Icon(Icons.refresh_rounded, size: 21),
                color: _green,
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (_loading) ...[
            const LinearProgressIndicator(
              color: _green,
              backgroundColor: Color(0xFFEAF1EB),
            ),
            const SizedBox(height: 16),
            const Text(
              'Buscando a cotação do dólar…',
              style: TextStyle(color: _ink),
            ),
          ] else if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: _ink)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ] else if (quote != null) ...[
            const Text(
              'Um dólar vale',
              style: TextStyle(color: Color(0xFF718078), fontSize: 13),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _currency.format(quote.rate),
                style: const TextStyle(
                  fontSize: 34,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Referência: ${DateFormat('dd/MM/yyyy').format(quote.date)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF718078)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1, color: Color(0xFFE5EBE8)),
            ),
            const Text(
              'Planeje um valor em dólar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _ink,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                LengthLimitingTextInputFormatter(12),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: 'US\$  ',
                labelText: 'Valor em dólar',
                errorText: amount == null
                    ? 'Digite um valor válido, como 100,50'
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F7F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                amount == null
                    ? '—'
                    : '≈ ${_currency.format((amount * quote.rate * 100).round() / 100)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _green,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Fonte: Frankfurter • Cotação diária de referência, atualizada em dias úteis. Conversão estimada, sem impostos ou tarifas.',
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: Color(0xFF718078),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/month_summary.dart';
import '../theme.dart';
import '../utils/money.dart';

/// Só apresenta dados recebidos. Quem muda o estado é a HomeScreen.
class MonthlyOverview extends StatelessWidget {
  const MonthlyOverview({super.key, required this.summary});
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: ink,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: lime, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Resultado do mês',
                style: TextStyle(color: Color(0xFFD1DFD6)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            money(summary.balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Recebido menos pago no mês selecionado',
          style: TextStyle(color: Color(0xFFB4C8BC), fontSize: 12),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 17),
          child: Divider(color: Color(0xFF365348)),
        ),
        Row(
          children: [
            Expanded(child: _metric('Recebido', summary.income, true)),
            const SizedBox(width: 16),
            Expanded(child: _metric('Pago', summary.expenses, false)),
          ],
        ),
        if (summary.pendingIncome + summary.pendingExpenses > 0) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    Text(
                      'A receber: ${money(summary.pendingIncome)}',
                      style: const TextStyle(
                        color: Color(0xFFD1DFD6),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'A pagar: ${money(summary.pendingExpenses)}',
                      style: const TextStyle(
                        color: Color(0xFFF4B79A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Previsão ao concluir tudo',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      money(summary.projectedBalance),
                      style: const TextStyle(
                        color: lime,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget _metric(String label, int value, bool incoming) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            incoming ? Icons.south_west : Icons.north_east,
            size: 15,
            color: incoming ? lime : const Color(0xFFF4B79A),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFD1DFD6), fontSize: 12),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          money(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

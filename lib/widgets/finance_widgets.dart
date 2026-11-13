import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_entry.dart';
import '../models/month_summary.dart';
import '../theme.dart';
import '../utils/money.dart';

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = 24});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    this.onTogglePaid,
  });
  final FinanceEntry entry;
  final VoidCallback onEdit, onDelete;
  final VoidCallback? onTogglePaid;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(entry.category);
    final now = DateTime.now();
    final overdue =
        !entry.isPaid &&
        entry.date.isBefore(DateTime(now.year, now.month, now.day));
    final status = entry.isPaid
        ? (entry.isIncome ? 'Recebido' : 'Pago')
        : (overdue ? 'Vencido' : 'Pendente');
    final amount = Text(
      '${entry.isIncome ? '+' : '−'} ${money(entry.amountCents)}',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: entry.isIncome ? green : ink,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  categoryIcon(entry.category),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${entry.category} · ${DateFormat('dd/MM').format(entry.date)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 10,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (compact) amount,
                            Text(
                              status,
                              style: TextStyle(
                                color: overdue
                                    ? coral
                                    : entry.isPaid
                                    ? muted
                                    : Color(0xFF98702B),
                                fontSize: 11,
                                fontWeight: entry.isPaid
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 155),
                  child: amount,
                ),
              ],
              PopupMenuButton<String>(
                tooltip: 'Opções de ${entry.title}',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'status') onTogglePaid?.call();
                },
                itemBuilder: (_) => [
                  if (onTogglePaid != null)
                    PopupMenuItem(
                      value: 'status',
                      child: Text(
                        entry.isPaid
                            ? 'Marcar como pendente'
                            : entry.isIncome
                            ? 'Marcar como recebido'
                            : 'Marcar como pago',
                      ),
                    ),
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class ExpenseChart extends StatelessWidget {
  const ExpenseChart({super.key, required this.summary});
  final MonthSummary summary;
  @override
  Widget build(BuildContext context) {
    final values = summary.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Para onde foi seu dinheiro',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          const Text(
            'Despesas pagas por categoria',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 196,
              height: 196,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _DonutPainter(values)),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Total pago',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        money(summary.expenses),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (values.isEmpty)
            const Text(
              'Seu gráfico aparece ao registrar a primeira despesa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          for (final item in values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: categoryColor(item.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.key, style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    '${(item.value / summary.expenses * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    money(item.value),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values);
  final List<MapEntry<String, int>> values;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(14, 14, size.width - 28, size.height - 28);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = line);
    final total = values.fold<int>(0, (sum, e) => sum + e.value);
    var start = -math.pi / 2;
    for (final item in values) {
      final sweep = item.value / total * math.pi * 2;
      final gap = math.min(.045, sweep * .2);
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep - gap,
        false,
        paint..color = categoryColor(item.key),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

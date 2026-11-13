import 'finance_entry.dart';

// Regra de negócio pura: a mesma conta alimenta cartões, gráfico e orçamento.
class MonthSummary {
  MonthSummary(List<FinanceEntry> all, DateTime month)
    : entries =
          all
              .where(
                (e) => e.date.year == month.year && e.date.month == month.month,
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
  final List<FinanceEntry> entries;
  int get income => entries
      .where((e) => e.isIncome && e.isPaid)
      .fold(0, (sum, e) => sum + e.amountCents);
  int get expenses => entries
      .where((e) => !e.isIncome && e.isPaid)
      .fold(0, (sum, e) => sum + e.amountCents);
  int get balance => income - expenses;
  int get pendingIncome => entries
      .where((e) => e.isIncome && !e.isPaid)
      .fold(0, (sum, e) => sum + e.amountCents);
  int get pendingExpenses => entries
      .where((e) => !e.isIncome && !e.isPaid)
      .fold(0, (sum, e) => sum + e.amountCents);
  int get projectedBalance => balance + pendingIncome - pendingExpenses;

  /// Gráfico: somente despesas efetivamente pagas.
  Map<String, int> get byCategory => _groupExpenses(paidOnly: true);

  /// Orçamento: despesas pagas e pendentes já comprometem o limite.
  Map<String, int> get committedByCategory => _groupExpenses(paidOnly: false);

  Map<String, int> _groupExpenses({required bool paidOnly}) {
    final result = <String, int>{};
    for (final entry in entries.where(
      (e) => !e.isIncome && (!paidOnly || e.isPaid),
    )) {
      result.update(
        entry.category,
        (sum) => sum + entry.amountCents,
        ifAbsent: () => entry.amountCents,
      );
    }
    return result;
  }
}

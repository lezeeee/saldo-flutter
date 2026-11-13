import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/models/finance_entry.dart';
import 'package:saldo/models/month_summary.dart';
import 'package:saldo/utils/money.dart';

void main() {
  test('valores brasileiros são interpretados exatamente em centavos', () {
    expect(parseMoney('1.250,50'), 125050);
    expect(parseMoney('R\$ 0,01'), 1);
    expect(parseMoney('12,5'), 1250);
    expect(parseMoney('1.000'), 100000);
    expect(parseMoney('0'), 0);
    expect(parseMoney('999999999,99'), 99999999999);
    expect(moneyInput(125050), '1250,50');
    expect(parseMoney(moneyInput(125050)), 125050);
  });

  test('rejeita valores ambíguos, negativos e maiores que o limite', () {
    for (final input in [
      '',
      '-10,00',
      '1.25',
      '1,234',
      '1,2,3',
      'NaN',
      'Infinity',
      '1000000000',
      '12abc',
    ]) {
      expect(parseMoney(input), isNull, reason: input);
    }
  });

  test(
    'resumo separa ano e mês, soma despesas por categoria e ordena por data',
    () {
      FinanceEntry entry(
        String id,
        int cents,
        DateTime date, {
        bool income = false,
        String category = 'Alimentação',
      }) => FinanceEntry(
        id: id,
        title: id,
        category: category,
        amountCents: cents,
        date: date,
        isIncome: income,
      );
      final entries = [
        entry(
          'salary',
          200000,
          DateTime(2026, 10, 5),
          income: true,
          category: 'Salário',
        ),
        entry('coffee', 10, DateTime(2026, 10, 10)),
        entry('lunch', 20, DateTime(2026, 10, 12)),
        entry('rent', 70000, DateTime(2026, 10, 1), category: 'Moradia'),
        entry('previous month', 999999, DateTime(2026, 9, 30)),
        entry('previous year', 999999, DateTime(2025, 10, 10)),
      ];
      final summary = MonthSummary(entries, DateTime(2026, 10));
      expect(summary.entries.map((e) => e.id), [
        'lunch',
        'coffee',
        'salary',
        'rent',
      ]);
      expect(summary.income, 200000);
      expect(summary.expenses, 70030);
      expect(summary.balance, 129970);
      expect(summary.byCategory, {'Alimentação': 30, 'Moradia': 70000});
      final empty = MonthSummary(entries, DateTime(2026, 12));
      expect(empty.balance, 0);
      expect(empty.byCategory, isEmpty);
    },
  );

  test(
    'distingue realizado, pendente e comprometido sem duplicar ao pagar',
    () {
      final salary = FinanceEntry(
        id: 'salary',
        title: 'Salário',
        category: 'Salário',
        amountCents: 300000,
        date: DateTime(2026, 11, 1),
        isIncome: true,
      );
      final rent = FinanceEntry(
        id: 'rent',
        title: 'Aluguel',
        category: 'Moradia',
        amountCents: 100000,
        date: DateTime(2026, 11, 10),
        isIncome: false,
        isPaid: false,
      );
      final coffee = FinanceEntry(
        id: 'coffee',
        title: 'Café',
        category: 'Alimentação',
        amountCents: 1000,
        date: DateTime(2026, 11, 1),
        isIncome: false,
      );
      final freelance = FinanceEntry(
        id: 'job',
        title: 'Projeto',
        category: 'Freelance',
        amountCents: 50000,
        date: DateTime(2026, 11, 15),
        isIncome: true,
        isPaid: false,
      );
      final before = MonthSummary([
        salary,
        rent,
        coffee,
        freelance,
      ], DateTime(2026, 11));
      expect(before.income, 300000);
      expect(before.expenses, 1000);
      expect(before.balance, 299000);
      expect(before.pendingExpenses, 100000);
      expect(before.pendingIncome, 50000);
      expect(before.projectedBalance, 249000);
      expect(before.byCategory, {'Alimentação': 1000});
      expect(before.committedByCategory, {
        'Moradia': 100000,
        'Alimentação': 1000,
      });
      final after = MonthSummary([
        salary,
        rent.copyWith(isPaid: true),
        coffee,
        freelance,
      ], DateTime(2026, 11));
      expect(after.balance, 199000);
      expect(after.pendingExpenses, 0);
      expect(after.projectedBalance, 249000);
      expect(after.committedByCategory, before.committedByCategory);
      expect(after.entries, hasLength(4));
    },
  );
}

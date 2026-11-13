/// Um lançamento é imutável: ao editar, criamos outro objeto com o mesmo id.
/// Valores são guardados em centavos para evitar erros de ponto flutuante.
class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.amountCents,
    required this.date,
    required this.isIncome,
    this.isPaid = true,
  });

  final String id;
  final String title;
  final String category;
  final int amountCents;
  final DateTime date;
  final bool isIncome;
  final bool isPaid;

  FinanceEntry copyWith({
    String? title,
    String? category,
    int? amountCents,
    DateTime? date,
    bool? isIncome,
    bool? isPaid,
  }) => FinanceEntry(
    id: id,
    title: title ?? this.title,
    category: category ?? this.category,
    amountCents: amountCents ?? this.amountCents,
    date: date ?? this.date,
    isIncome: isIncome ?? this.isIncome,
    isPaid: isPaid ?? this.isPaid,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'category': category,
    'amount_cents': amountCents,
    'date': date.toIso8601String(),
    // SQLite não possui tipo bool; usamos 0 e 1.
    'is_income': isIncome ? 1 : 0,
    'is_paid': isPaid ? 1 : 0,
  };

  factory FinanceEntry.fromMap(Map<String, Object?> map) => FinanceEntry(
    id: map['id'] as String,
    title: map['title'] as String,
    category: map['category'] as String,
    amountCents: map['amount_cents'] as int,
    date: DateTime.parse(map['date'] as String),
    isIncome: map['is_income'] == 1,
    isPaid: (map['is_paid'] ?? 1) == 1,
  );
}

const expenseCategories = [
  'Alimentação',
  'Moradia',
  'Transporte',
  'Lazer',
  'Saúde',
  'Educação',
  'Outros',
];

const incomeCategories = ['Salário', 'Freelance', 'Outros'];

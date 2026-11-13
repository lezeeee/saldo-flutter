/// Uma meta é um acompanhamento manual, separado das receitas e despesas.
/// Centavos pertencem à moeda da meta: BRL ou USD.
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.title,
    required this.targetCents,
    required this.savedCents,
    this.currency = 'BRL',
    this.deadline,
  });

  final String id;
  final String title;
  final int targetCents;
  final int savedCents;
  final String currency;
  final DateTime? deadline;

  int get remainingCents => targetCents - savedCents;
  double get progress => targetCents <= 0 ? 0 : savedCents / targetCents;
  bool get isComplete => savedCents >= targetCents;

  SavingsGoal copyWith({
    String? title,
    int? targetCents,
    int? savedCents,
    String? currency,
    DateTime? deadline,
    bool clearDeadline = false,
  }) => SavingsGoal(
    id: id,
    title: title ?? this.title,
    targetCents: targetCents ?? this.targetCents,
    savedCents: savedCents ?? this.savedCents,
    currency: currency ?? this.currency,
    deadline: clearDeadline ? null : (deadline ?? this.deadline),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'target_cents': targetCents,
    'saved_cents': savedCents,
    'currency': currency,
    'deadline': deadline?.toIso8601String(),
  };

  factory SavingsGoal.fromMap(Map<String, Object?> map) => SavingsGoal(
    id: map['id'] as String,
    title: map['title'] as String,
    targetCents: map['target_cents'] as int,
    savedCents: map['saved_cents'] as int,
    currency: map['currency'] as String,
    deadline: map['deadline'] == null
        ? null
        : DateTime.parse(map['deadline'] as String),
  );
}

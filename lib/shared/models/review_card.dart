/// SRS 복습 카드. 스케줄 UI는 아직 없다.
/// SRS復習カード。スケジュールUIはまだない。
class ReviewCard {
  const ReviewCard({
    required this.kanjiId,
    required this.intervalDays,
    required this.easeFactor,
    required this.repetitions,
    required this.dueAt,
    this.lastReviewedAt,
  });

  final String kanjiId;
  final int intervalDays;
  final int easeFactor;
  final int repetitions;
  final DateTime dueAt;
  final DateTime? lastReviewedAt;

  bool get isDue => !dueAt.isAfter(DateTime.now());
}

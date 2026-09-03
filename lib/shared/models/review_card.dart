/// SRS 복습 카드. 스케줄 UI는 아직 없다.
///
/// 카드를 카탈로그에 넣을 때 [AppDatabase]가 기본값으로 만들어 둔다.
/// [easeFactor]는 250 = 2.50. [isDue]는 dueAt이 지금 이전이면 true.
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

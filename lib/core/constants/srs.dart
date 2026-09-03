/// SM-2 스타일 복습 간격.
///
/// 복습 화면은 아직 없다. [ReviewCard] 필드 기본값만 맞춰 둔다.
/// [graduatingDays]는 연속 정답 시 간격(일), [defaultEaseFactor]는 250 = 2.50.
class SrsIntervals {
  static const List<int> graduatingDays = [1, 3, 7, 14, 30];
  static const int defaultEaseFactor = 250;
}

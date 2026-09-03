import '../../core/database/app_database.dart';
import '../../shared/models/review_card.dart';

/// 오늘 복습 목록.
///
/// 학습 홈에는 아직 연결하지 않았다. [AppDatabase.dueReviews] 래퍼다.
class SrsController {
  SrsController(this._db);

  final AppDatabase _db;

  List<ReviewCard> dueToday() => _db.dueReviews();
}

/// 세션용 인메모리 DB. SQLite가 아니다.
///
/// 앱이 켜져 있는 동안 카드·즐겨찾기·SRS 필드를 Map으로 들고 있다.
/// 사용자 한자와 즐겨찾기는 [UserStore] JSON에 저장한다.
/// 시드 에셋은 덮어쓰지 않고, 켤 때마다 JSON에서 다시 읽는다.
library;

import '../../shared/models/kanji.dart';
import '../../shared/models/review_card.dart';
import '../../shared/models/study_list.dart';
import '../constants/srs.dart';

class AppDatabase {
  final Map<String, Kanji> _kanjis = {};
  final Map<String, ReviewCard> _reviews = {};
  final Set<String> _favoriteIds = {};

  int get kanjiCount => _kanjis.length;

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  void upsertKanji(Kanji kanji) {
    _kanjis[kanji.id] = kanji;
    // 복습 UI는 아직 없지만, 카드를 넣을 때 리뷰 레코드도 만들어 둔다.
    _reviews.putIfAbsent(
      kanji.id,
      () => ReviewCard(
        kanjiId: kanji.id,
        intervalDays: 0,
        easeFactor: SrsIntervals.defaultEaseFactor,
        repetitions: 0,
        dueAt: DateTime.now(),
      ),
    );
  }

  void deleteKanji(String id) {
    _kanjis.remove(id);
    _reviews.remove(id);
    _favoriteIds.remove(id);
  }

  void setFavorites(Iterable<String> ids) {
    _favoriteIds
      ..clear()
      ..addAll(ids.where(_kanjis.containsKey));
  }

  bool isFavorite(String id) => _favoriteIds.contains(id);

  bool toggleFavorite(String id) {
    if (!_kanjis.containsKey(id)) {
      return false;
    }
    if (!_favoriteIds.add(id)) {
      _favoriteIds.remove(id);
    }
    return _favoriteIds.contains(id);
  }

  /// 같은 종류·글자를 두 번 넣지 않기 위한 검사. 수정 중이면 자기 id는 제외.
  bool containsLiteral(
    String literal, {
    String? exceptId,
    EntryKind? kind,
  }) {
    return _kanjis.values.any(
      (kanji) =>
          kanji.literal == literal &&
          kanji.id != exceptId &&
          (kind == null || kanji.kind == kind),
    );
  }

  List<Kanji> allKanjis() => _kanjis.values.toList(growable: false);

  Kanji? kanjiById(String id) => _kanjis[id];

  List<Kanji> favoriteKanjis() {
    return [
      for (final id in _favoriteIds)
        if (_kanjis[id] != null) _kanjis[id]!,
    ];
  }

  List<ReviewCard> dueReviews() {
    return _reviews.values.where((card) => card.isDue).toList(growable: false);
  }

  ReviewCard? reviewByKanjiId(String id) => _reviews[id];
}

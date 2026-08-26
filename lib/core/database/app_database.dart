/// kanjis / reviews / favorites.
/// 사용자 한자와 즐겨찾기는 UserStore JSON에 저장한다. 시드 n5.json은 덮어쓰지 않는다.
/// ユーザー漢字とお気に入りは UserStore JSON に保存する。シード n5.json は上書きしない。
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
    // 복습 UI는 아직 없지만, 한자를 넣을 때 리뷰 카드도 만들어 둔다.
    // 復習UIはまだないが、漢字を入れるときにレビューカードも作っておく。
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
  /// 同じ種類・字を二度入れないための検査。修正中なら自分の id は除外。
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

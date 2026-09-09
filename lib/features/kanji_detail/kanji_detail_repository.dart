import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/storage/user_store.dart';
import '../../shared/models/kanji.dart';
import '../../shared/models/review_card.dart';
import '../../shared/models/study_list.dart';

/// 시드 JSON + 로컬 수정을 합쳐 카탈로그를 만든다.
///
/// 폴더 이름은 kanji_detail이지만, 실제로는 앱 전체 카탈로그 repository다.
///
/// 로드 순서: 1) 번들 시드 2) 사용자 JSON upsert.
/// 순서를 바꾸면 수정분이 시드에 덮인다.
///
/// [_ready]가 true면 같은 프로세스에서 다시 읽지 않는다.
/// 에셋 JSON을 바꿨으면 핫 리로드가 아니라 핫 리스타트가 필요하다.

/// 예전 샘플 목록. 번들에 남아 있어도 목록에 넣지 않는다.
const _removedListIds = {'n5_word', 'n5_kanji'};

class KanjiRepository {
  KanjiRepository(this._db, this._store);

  final AppDatabase _db;
  final UserStore _store;
  bool _ready = false;

  /// 시드를 수정한 id도 persist 대상에 넣기 위한 집합.
  final Set<String> _persistedIds = {};
  List<StudyList> _builtinLists = const [];

  List<StudyList> get builtinLists => List.unmodifiable(_builtinLists);

  Future<void> ensureReady() async {
    if (_ready) {
      return;
    }
    final listsRaw = await rootBundle.loadString('assets/data/lists.json');
    _builtinLists = [
      for (final item in jsonDecode(listsRaw) as List<dynamic>)
        StudyList.fromJson(item as Map<String, dynamic>),
    ].where((list) => !_removedListIds.contains(list.id)).toList();
    for (final list in _builtinLists) {
      final asset = list.asset;
      if (asset == null) {
        continue;
      }
      final raw = await rootBundle.loadString(asset);
      final rows = jsonDecode(raw) as List<dynamic>;
      for (final item in rows) {
        final kanji = Kanji.fromJson(item as Map<String, dynamic>);
        _db.upsertKanji(
          kanji.copyWith(
            listId: kanji.listId.isEmpty ? list.id : kanji.listId,
            kind: kanji.kind == EntryKind.kanji && list.kind != EntryKind.mixed
                ? list.kind
                : kanji.kind,
          ),
        );
      }
    }
    final user = _store.load();
    for (final kanji in user.userKanjis) {
      _db.upsertKanji(kanji);
      _persistedIds.add(kanji.id);
    }
    _db.setFavorites(user.favoriteIds);
    _ready = true;
  }

  Future<void> _persist() {
    // 시드 원본은 저장하지 않고, 추가분·수정분만 UserStore에 남긴다.
    return _store.patch(
      favoriteIds: _db.favoriteIds,
      userKanjis: _db
          .allKanjis()
          .where((item) => item.isUserAdded || _persistedIds.contains(item.id))
          .toList(),
    );
  }

  Future<List<Kanji>> all() async {
    await ensureReady();
    return _db.allKanjis();
  }

  Future<Kanji?> byId(String id) async {
    await ensureReady();
    return _db.kanjiById(id);
  }

  Future<List<Kanji>> favorites() async {
    await ensureReady();
    return _db.favoriteKanjis();
  }

  Set<String> get favoriteIds => _db.favoriteIds;

  Future<bool> toggleFavorite(String id) async {
    await ensureReady();
    final starred = _db.toggleFavorite(id);
    await _persist();
    return starred;
  }

  Future<String?> addUserKanji(Kanji kanji) async {
    await ensureReady();
    if (_db.containsLiteral(kanji.literal, kind: kanji.kind)) {
      // UI에서 l10n.alreadyExists로 바꿔 보여 준다.
      return 'alreadyExists';
    }
    _db.upsertKanji(kanji);
    _persistedIds.add(kanji.id);
    await _persist();
    return null;
  }

  Future<String?> updateKanji(Kanji kanji) async {
    await ensureReady();
    if (_db.containsLiteral(
      kanji.literal,
      exceptId: kanji.id,
      kind: kanji.kind,
    )) {
      return 'alreadyExists';
    }
    _db.upsertKanji(kanji);
    _persistedIds.add(kanji.id);
    await _persist();
    return null;
  }

  Future<void> deleteUserKanji(String id) async {
    await ensureReady();
    final kanji = _db.kanjiById(id);
    // 시드 한자는 삭제하지 않는다. 수정만 persist.
    if (kanji == null || !kanji.isUserAdded) {
      return;
    }
    _db.deleteKanji(id);
    _persistedIds.remove(id);
    await _persist();
  }

  Future<List<ReviewCard>> dueToday() async {
    await ensureReady();
    return _db.dueReviews();
  }
}

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/storage/user_store.dart';
import '../../shared/models/kanji.dart';
import '../../shared/models/review_card.dart';

/// 시드 JSON + 로컬 수정을 합쳐 카탈로그를 만든다.
/// シードJSON + ローカル修正を合わせてカタログを作る。
class KanjiRepository {
  KanjiRepository(this._db, this._store);

  final AppDatabase _db;
  final UserStore _store;
  bool _ready = false;
  /// 시드를 수정한 id도 persist 대상에 넣기 위한 집합.
  /// シードを直した id も persist 対象に入れるための集合。
  final Set<String> _persistedIds = {};

  Future<void> ensureReady() async {
    if (_ready) {
      return;
    }
    // 1) 번들 시드 → 2) 사용자 JSON upsert. 순서를 바꾸면 수정분이 덮인다.
    // 1) バンドルシード → 2) ユーザーJSON upsert。順を変えると修正分が上書きされる。
    final raw = await rootBundle.loadString('assets/data/kanji/n5.json');
    final list = jsonDecode(raw) as List<dynamic>;
    for (final item in list) {
      _db.upsertKanji(Kanji.fromJson(item as Map<String, dynamic>));
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
    // シード原本は保存せず、追加分・修正分だけ UserStore に残す。
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
    if (_db.containsLiteral(kanji.literal)) {
      // UI에서 l10n.alreadyExists로 바꿔 보여 준다.
      // UI では l10n.alreadyExists に変えて見せる。
      return 'alreadyExists';
    }
    _db.upsertKanji(kanji);
    _persistedIds.add(kanji.id);
    await _persist();
    return null;
  }

  Future<String?> updateKanji(Kanji kanji) async {
    await ensureReady();
    if (_db.containsLiteral(kanji.literal, exceptId: kanji.id)) {
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
    // シード漢字は削除しない。修正だけ persist。
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

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/import/list_import.dart';
import '../../core/storage/user_store.dart';
import '../../shared/models/kanji.dart';
import '../../shared/models/review_card.dart';
import '../../shared/models/study_list.dart';

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
  List<StudyList> _builtinLists = const [];
  List<StudyList> _importedLists = const [];

  List<StudyList> get builtinLists => List.unmodifiable(_builtinLists);

  List<StudyList> get importedLists => List.unmodifiable(_importedLists);

  Future<void> ensureReady() async {
    if (_ready) {
      return;
    }
    // 1) 번들 시드 → 2) 사용자 JSON upsert. 순서를 바꾸면 수정분이 덮인다.
    // 1) バンドルシード → 2) ユーザーJSON upsert。順を変えると修正分が上書きされる。
    final listsRaw = await rootBundle.loadString('assets/data/lists.json');
    _builtinLists = [
      for (final item in jsonDecode(listsRaw) as List<dynamic>)
        StudyList.fromJson(item as Map<String, dynamic>),
    ];
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
    _importedLists = [...user.importedLists];
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
    final remaining = {
      for (final item in _db.allKanjis())
        if (item.isUserAdded || _persistedIds.contains(item.id)) item.listId,
    };
    _importedLists = [
      for (final list in _importedLists)
        if (remaining.contains(list.id)) list,
    ];
    return _store.patch(
      favoriteIds: _db.favoriteIds,
      userKanjis: _db
          .allKanjis()
          .where((item) => item.isUserAdded || _persistedIds.contains(item.id))
          .toList(),
      importedLists: _importedLists,
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
    // シード漢字は削除しない。修正だけ persist。
    if (kanji == null || !kanji.isUserAdded) {
      return;
    }
    _db.deleteKanji(id);
    _persistedIds.remove(id);
    await _persist();
  }

  /// JSON 목록을 가져와 새 리스트로 붙인다. 개수를 돌려준다.
  /// JSON一覧を入れて新しいリストにする。件数を返す。
  Future<int> importJson(String raw) async {
    await ensureReady();
    final parsed = parseImportJson(raw);
    var list = parsed.list;
    final taken = {
      for (final item in _builtinLists) item.id,
      for (final item in _importedLists) item.id,
      ListIds.all,
      ListIds.user,
      ListIds.favorites,
    };
    if (taken.contains(list.id)) {
      final nextId = '${list.id}_${DateTime.now().millisecondsSinceEpoch}';
      list = list.copyWith(id: nextId);
    }
    for (final item in parsed.items) {
      var kanji = item.copyWith(listId: list.id, isUserAdded: true);
      if (_db.kanjiById(kanji.id) != null ||
          _db.containsLiteral(kanji.literal, kind: kanji.kind)) {
        kanji = kanji.copyWith(
          id: '${kanji.id}_${DateTime.now().microsecondsSinceEpoch}',
        );
      }
      _db.upsertKanji(kanji);
      _persistedIds.add(kanji.id);
    }
    _importedLists = [..._importedLists, list];
    await _persist();
    return parsed.items.length;
  }

  Future<List<ReviewCard>> dueToday() async {
    await ensureReady();
    return _db.dueReviews();
  }
}

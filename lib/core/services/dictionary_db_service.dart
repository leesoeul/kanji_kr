import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kana_kit/kana_kit.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../shared/models/kanji.dart';
import '../../shared/models/reading.dart';
import '../../shared/models/study_list.dart';

/// `scripts/build_dictionary_db.py`의 DB_VERSION과 같아야 한다.
/// 기기에 있는 DB가 이보다 낮으면 에셋에서 다시 복사한다.
const int kDictionaryDbVersion = 4;

const _assetPath = 'assets/db/dictionary.db';
const _fileName = 'dictionary.db';

enum DictionaryFilter { all, kanji, word }

/// `entries` 한 행.
class DictionaryEntry {
  const DictionaryEntry({
    required this.source,
    required this.sourceId,
    required this.literal,
    required this.reading,
    required this.meaningKo,
    required this.meanings,
    required this.kind,
    required this.jlpt,
    required this.onYomi,
    required this.kunYomi,
    required this.strokeCount,
    required this.examples,
  });

  /// `seed`, `kanjidic`, `wiktionary`.
  final String source;

  /// 시드 카드 id (`kanji_1`, `verb_3`). 외부 사전이면 그쪽 id.
  final String sourceId;
  final String literal;
  final String reading;
  final String meaningKo;
  final List<String> meanings;
  final EntryKind kind;
  final String jlpt;
  final List<String> onYomi;
  final List<String> kunYomi;
  final int strokeCount;
  final List<KanjiExample> examples;

  bool get isWord => kind == EntryKind.word;

  /// 시드만 카탈로그에 카드가 있다. 외부 사전 항목은 `/kanji/:id`로 열 수 없다.
  bool get isSeed => source == 'seed';

  factory DictionaryEntry.fromRow(Map<String, Object?> row) {
    List<String> split(Object? raw) => (raw as String? ?? '')
        .split('・')
        .where((item) => item.isNotEmpty)
        .toList();

    final examples = jsonDecode(row['examples_json'] as String? ?? '[]')
        as List<dynamic>;
    return DictionaryEntry(
      source: row['source'] as String? ?? 'seed',
      sourceId: row['source_id'] as String,
      literal: row['literal'] as String,
      reading: row['reading'] as String? ?? '',
      meaningKo: row['meaning_ko'] as String? ?? '',
      meanings: (jsonDecode(row['meanings_json'] as String? ?? '[]')
              as List<dynamic>)
          .cast<String>(),
      kind: EntryKind.fromName(row['kind'] as String?),
      jlpt: row['jlpt'] as String? ?? '',
      onYomi: split(row['on_yomi']),
      kunYomi: split(row['kun_yomi']),
      strokeCount: row['stroke_count'] as int? ?? 0,
      examples: examples
          .map((item) => KanjiExample.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 내 목록에 넣을 사용자 카드 복사본. 같은 글자도 목록마다 따로 들어간다.
  Kanji toKanji(String listId) {
    final prefix = isWord ? 'user_word' : 'user_kanji';
    return Kanji(
      id: '${prefix}_${listId}_$literal',
      literal: literal,
      jlpt: jlpt,
      strokeCount: strokeCount,
      koreanMeaning: isWord ? meaningKo : meaningKo.replaceAll(' · ', '/'),
      meaningsKo: meanings.isEmpty ? [meaningKo] : meanings,
      onYomi: onYomi.map((kana) => Reading(kana: kana)).toList(),
      kunYomi: kunYomi.map((kana) => Reading(kana: kana)).toList(),
      examples: examples,
      kind: kind,
      listId: listId,
      reading: isWord ? reading : '',
      isUserAdded: true,
    );
  }

  /// AI 추천 카드의 뜻·읽기를 사전 값으로 바꾼다. 예문과 id는 추천 결과를 유지한다.
  /// 사전에 비어 있는 항목은 추천 값을 남긴다.
  Kanji overlaySuggestion(Kanji suggestion) {
    final meaning = isWord ? meaningKo : meaningKo.replaceAll(' · ', '/');
    final dictOn = onYomi.map((kana) => Reading(kana: kana)).toList();
    final dictKun = kunYomi.map((kana) => Reading(kana: kana)).toList();
    return suggestion.copyWith(
      koreanMeaning: meaning.isNotEmpty ? meaning : suggestion.koreanMeaning,
      meaningsKo: meanings.isNotEmpty
          ? meanings
          : (meaning.isNotEmpty ? [meaning] : suggestion.meaningsKo),
      onYomi: dictOn.isNotEmpty ? dictOn : suggestion.onYomi,
      kunYomi: dictKun.isNotEmpty ? dictKun : suggestion.kunYomi,
      jlpt: jlpt.isNotEmpty ? jlpt : suggestion.jlpt,
      strokeCount: strokeCount > 0 ? strokeCount : suggestion.strokeCount,
      reading: isWord && reading.isNotEmpty ? reading : suggestion.reading,
    );
  }
}

/// 앱에 내장한 사전 DB. 읽기 전용으로 열어 검색만 한다.
class DictionaryDbService {
  DictionaryDbService._(this._db);

  final Database _db;
  bool _ftsUsable = true;

  static const _kanaKit = KanaKit();

  static Future<DictionaryDbService> open() async {
    if (kIsWeb) {
      return _openWeb();
    }
    final dir = await getDatabasesPath();
    final path = p.join(dir, _fileName);
    if (!await _isCurrent(databaseFactory, path)) {
      await Directory(dir).create(recursive: true);
      await File(path).writeAsBytes(await _assetBytes(), flush: true);
    }
    final db = await openDatabase(path, readOnly: true);
    return DictionaryDbService._(db);
  }

  /// 웹은 파일 시스템이 없어서 sqlite wasm이 IndexedDB에 DB를 둔다.
  /// `web/sqflite_sw.js`, `web/sqlite3.wasm`은 `dart run sqflite_common_ffi_web:setup`으로 만든다.
  static Future<DictionaryDbService> _openWeb() async {
    final factory = databaseFactoryFfiWeb;
    if (!await _isCurrent(factory, _fileName)) {
      await factory.writeDatabaseBytes(_fileName, await _assetBytes());
    }
    final db = await factory.openDatabase(
      _fileName,
      options: OpenDatabaseOptions(readOnly: true),
    );
    return DictionaryDbService._(db);
  }

  static Future<Uint8List> _assetBytes() async {
    final data = await rootBundle.load(_assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static Future<bool> _isCurrent(DatabaseFactory factory, String path) async {
    if (!await factory.databaseExists(path)) {
      return false;
    }
    try {
      final db = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      final version = await db.getVersion();
      await db.close();
      return version >= kDictionaryDbVersion;
    } on Object {
      return false;
    }
  }

  /// 표제어가 정확히 같은 항목. 시드 행을 외부 사전보다 먼저 고른다.
  Future<DictionaryEntry?> entryForLiteral(
    String literal,
    EntryKind kind,
  ) async {
    final text = literal.trim();
    if (text.isEmpty || kind == EntryKind.mixed) {
      return null;
    }
    final rows = await _db.query(
      'entries',
      where: 'literal = ? AND kind = ?',
      whereArgs: [text, kind.jsonName],
      orderBy: "source != 'seed', id",
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return DictionaryEntry.fromRow(rows.first);
  }

  /// 한자·히라가나·한국어 뜻 부분 일치. 로마자는 히라가나로 바꿔 함께 찾는다.
  Future<List<DictionaryEntry>> search(
    String query, {
    DictionaryFilter filter = DictionaryFilter.all,
    int limit = 100,
  }) async {
    final terms = _terms(query);
    if (terms.isEmpty) {
      return const [];
    }
    final kind = switch (filter) {
      DictionaryFilter.all => null,
      DictionaryFilter.kanji => 'kanji',
      DictionaryFilter.word => 'word',
    };

    // trigram은 3글자부터 잡는다. 더 짧으면 LIKE로 충분히 빠르다(1,500행).
    if (_ftsUsable && terms.every((term) => term.length >= 3)) {
      try {
        return await _searchFts(terms, kind, limit);
      } on DatabaseException {
        _ftsUsable = false;
      }
    }
    return _searchLike(terms, kind, limit);
  }

  List<String> _terms(String query) {
    final raw = query.trim().toLowerCase();
    if (raw.isEmpty) {
      return const [];
    }
    final terms = <String>{raw};
    // 로마자(taberu)와 가타카나(タベル)는 시드 읽기와 같은 히라가나로 바꾼다.
    if (_kanaKit.isRomaji(raw) || _kanaKit.isKatakana(raw)) {
      final kana = _kanaKit.toHiragana(raw);
      if (_kanaKit.isHiragana(kana)) {
        terms.add(kana);
      }
    }
    return terms.toList();
  }

  String get _rank => '''
    CASE
      WHEN e.literal IN (SELECT value FROM json_each(?)) THEN 0
      WHEN e.reading IN (SELECT value FROM json_each(?)) THEN 1
      ELSE 2
    END, e.source != 'seed', length(e.literal), e.id''';

  Future<List<DictionaryEntry>> _searchLike(
    List<String> terms,
    String? kind,
    int limit,
  ) async {
    final likes = terms.map((_) => 'e.search_text LIKE ?').join(' OR ');
    final rows = await _db.rawQuery(
      'SELECT e.* FROM entries e '
      'WHERE ($likes)${kind == null ? '' : ' AND e.kind = ?'} '
      'ORDER BY $_rank LIMIT ?',
      [
        ...terms.map((term) => '%$term%'),
        if (kind != null) kind,
        jsonEncode(terms),
        jsonEncode(terms),
        limit,
      ],
    );
    return rows.map(DictionaryEntry.fromRow).toList(growable: false);
  }

  Future<List<DictionaryEntry>> _searchFts(
    List<String> terms,
    String? kind,
    int limit,
  ) async {
    final match =
        terms.map((term) => '"${term.replaceAll('"', '""')}"').join(' OR ');
    final rows = await _db.rawQuery(
      'SELECT e.* FROM entries_fts f JOIN entries e ON e.id = f.rowid '
      'WHERE entries_fts MATCH ?${kind == null ? '' : ' AND e.kind = ?'} '
      'ORDER BY $_rank LIMIT ?',
      [
        match,
        if (kind != null) kind,
        jsonEncode(terms),
        jsonEncode(terms),
        limit,
      ],
    );
    return rows.map(DictionaryEntry.fromRow).toList(growable: false);
  }
}

final dictionaryDbProvider = FutureProvider<DictionaryDbService>((ref) {
  return DictionaryDbService.open();
});

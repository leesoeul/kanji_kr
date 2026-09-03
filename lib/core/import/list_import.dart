import 'dart:convert';

import '../../shared/models/kanji.dart';
import '../../shared/models/study_list.dart';

/// JSON 가져오기 결과. 목록 메타 + 카드.
class ParsedImport {
  const ParsedImport({required this.list, required this.items});

  final StudyList list;
  final List<Kanji> items;
}

/// 사용자가 붙여 넣은 JSON을 목록으로 만든다.
///
/// 두 형태를 받는다.
/// 1. 카드 배열만: `[{ "literal": "...", ... }]`
/// 2. 목록 객체: `{ "titleKo": "...", "items": [ ... ] }`
///
/// 카드는 모두 `isUserAdded`로 표시하고, 목록 id는 `import_<시각>`이 기본이다.
ParsedImport parseImportJson(
  String raw, {
  int? nowMs,
}) {
  final decoded = jsonDecode(raw);
  final stamp = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  if (decoded is List) {
    final items = _itemsFromList(decoded, fallbackListId: 'import_$stamp');
    final kind = items.any((item) => item.isWord)
        ? (items.every((item) => item.isWord) ? EntryKind.word : EntryKind.mixed)
        : EntryKind.kanji;
    return ParsedImport(
      list: StudyList(
        id: 'import_$stamp',
        kind: kind,
        titleKo: '가져온 목록',
        titleJa: 'インポート',
        isImported: true,
      ),
      items: [
        for (final item in items)
          item.copyWith(
            listId: 'import_$stamp',
            isUserAdded: true,
          ),
      ],
    );
  }
  if (decoded is Map<String, dynamic>) {
    return _fromMap(decoded, stamp);
  }
  if (decoded is Map) {
    return _fromMap(Map<String, dynamic>.from(decoded), stamp);
  }
  throw const FormatException('JSON must be an object or array');
}

ParsedImport _fromMap(Map<String, dynamic> json, int stamp) {
  final rawItems = json['items'] as List<dynamic>? ?? const [];
  final requestedId = json['id'] as String?;
  // 가상 목록 id와 겹치면 새 import id를 쓴다.
  final listId = (requestedId == null ||
          requestedId == ListIds.user ||
          requestedId == ListIds.favorites)
      ? 'import_$stamp'
      : requestedId;
  final items = _itemsFromList(rawItems, fallbackListId: listId);
  var kind = EntryKind.fromName(json['kind'] as String?);
  if (kind == EntryKind.kanji && items.any((item) => item.isWord)) {
    kind = items.every((item) => item.isWord) ? EntryKind.word : EntryKind.mixed;
  }
  return ParsedImport(
    list: StudyList(
      id: listId,
      kind: kind,
      titleKo: json['titleKo'] as String? ?? '가져온 목록',
      titleJa: json['titleJa'] as String? ?? json['titleKo'] as String? ?? 'インポート',
      isImported: true,
    ),
    items: [
      for (final item in items)
        item.copyWith(
          listId: listId,
          isUserAdded: true,
          kind: item.kind == EntryKind.kanji && kind == EntryKind.word
              ? EntryKind.word
              : item.kind,
        ),
    ],
  );
}

List<Kanji> _itemsFromList(List<dynamic> raw, {required String fallbackListId}) {
  final items = <Kanji>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final map = Map<String, dynamic>.from(item);
    final parsed = Kanji.fromJson(map);
    if (parsed.literal.trim().isEmpty) {
      continue;
    }
    items.add(
      parsed.copyWith(
        listId: parsed.listId.isEmpty ? fallbackListId : parsed.listId,
        isUserAdded: true,
      ),
    );
  }
  if (items.isEmpty) {
    throw const FormatException('no items');
  }
  return items;
}

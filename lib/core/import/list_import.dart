import 'dart:convert';

import '../../shared/models/kanji.dart';
import '../../shared/models/study_list.dart';

/// JSON 가져오기 결과. 목록 메타 + 카드.
/// JSONインポート結果。一覧メタ + カード。
class ParsedImport {
  const ParsedImport({required this.list, required this.items});

  final StudyList list;
  final List<Kanji> items;
}

/// 배열만 있거나 `{ titleKo, items }` 둘 다 받는다.
/// 配列だけ、または `{ titleKo, items }` の両方を受ける。
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
  final listId = (requestedId == null ||
          requestedId == ListIds.all ||
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

import 'dart:math';

import '../../shared/models/kanji.dart';
import '../../shared/models/study_list.dart';

/// 선택한 목록 id로 카드를 걸러 낸다.
/// 選んだ一覧 id でカードを絞り込む。
List<Kanji> itemsForList({
  required List<Kanji> all,
  required Set<String> favoriteIds,
  required String listId,
  EntryKind? kind,
}) {
  if (listId.isEmpty) {
    return const [];
  }
  List<Kanji> items;
  switch (listId) {
    case ListIds.all:
      items = all;
      break;
    case ListIds.favorites:
      items = [
        for (final item in all)
          if (favoriteIds.contains(item.id)) item,
      ];
      break;
    case ListIds.user:
      items = [
        for (final item in all)
          if (item.isUserAdded) item,
      ];
      break;
    default:
      items = [
        for (final item in all)
          if (item.listId == listId) item,
      ];
  }
  if (kind == EntryKind.kanji) {
    return [
      for (final item in items)
        if (!item.isWord) item,
    ];
  }
  if (kind == EntryKind.word) {
    return [
      for (final item in items)
        if (item.isWord) item,
    ];
  }
  return items;
}

/// 저장된 목록이 없거나 지워졌으면 빈 값. 홈에서는 카드 대신 선택 화면을 연다.
/// 保存した一覧が無い、または消えていたら空。ホームではカードの代わりに選択画面を開く。
String resolveListId(String selected, List<StudyList> lists) {
  if (selected.isEmpty || selected == ListIds.all) {
    return '';
  }
  for (final list in lists) {
    if (list.id == selected) {
      return selected;
    }
  }
  return '';
}

EntryKind? parseEntryKind(String? raw) {
  if (raw == null || raw.isEmpty || raw == 'mixed') {
    return null;
  }
  return EntryKind.fromName(raw);
}

EntryKind? inferKindFromListId(String listId) {
  if (listId.contains('verb') || listId.contains('word')) {
    return EntryKind.word;
  }
  if (listId.contains('kanji')) {
    return EntryKind.kanji;
  }
  return null;
}

/// nonce가 0이면 원래 순서. 아니면 같은 시드로 섞어서 화면이 다시 그려져도 유지한다.
/// nonce が 0 なら元の順。でなければ同じシードで混ぜ、再描画しても維持する。
List<Kanji> withShuffle(List<Kanji> items, int nonce) {
  if (nonce == 0 || items.length < 2) {
    return items;
  }
  return [...items]..shuffle(Random(nonce));
}

/// 홈·목록·퀴즈 풀다운에 넣을 목록. 가상 필터를 앞에 둔다.
/// ホーム・一覧・クイズのプルダウン用。仮想フィルタを前に置く。
List<StudyList> composeStudyLists({
  required String allTitle,
  required String userTitle,
  required String favoritesTitle,
  required List<StudyList> builtin,
  required List<StudyList> imported,
}) {
  return [
    StudyList(
      id: ListIds.all,
      kind: EntryKind.mixed,
      titleKo: allTitle,
      titleJa: allTitle,
      isVirtual: true,
    ),
    ...builtin,
    StudyList(
      id: ListIds.user,
      kind: EntryKind.mixed,
      titleKo: userTitle,
      titleJa: userTitle,
      isVirtual: true,
    ),
    StudyList(
      id: ListIds.favorites,
      kind: EntryKind.mixed,
      titleKo: favoritesTitle,
      titleJa: favoritesTitle,
      isVirtual: true,
    ),
    ...imported,
  ];
}

/// 한자 또는 동사만. `전체`는 넣지 않는다.
/// 漢字または動詞だけ。`すべて`は入れない。
List<StudyList> composeListsForKind({
  required EntryKind kind,
  required String userTitle,
  required String favoritesTitle,
  required List<StudyList> builtin,
  required List<StudyList> imported,
}) {
  return [
    for (final list in builtin)
      if (list.kind == kind) list,
    StudyList(
      id: ListIds.user,
      kind: kind,
      titleKo: userTitle,
      titleJa: userTitle,
      isVirtual: true,
    ),
    StudyList(
      id: ListIds.favorites,
      kind: kind,
      titleKo: favoritesTitle,
      titleJa: favoritesTitle,
      isVirtual: true,
    ),
    for (final list in imported)
      if (list.kind == kind || list.kind == EntryKind.mixed) list,
  ];
}

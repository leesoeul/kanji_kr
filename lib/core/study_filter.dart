import 'dart:math';

import '../../shared/models/kanji.dart';
import '../../shared/models/study_list.dart';
import 'l10n/generated/app_localizations.dart';

/// 선택한 목록 id로 카드를 걸러 낸다.
///
/// - [ListIds.favorites]: 하트 친 카드
/// - [ListIds.user]: `listId`가 내가 추가인 카드
/// - 그 외: `item.listId == listId` (시드 목록)
///
/// [kind]가 있으면 한자/단어로 한 번 더 거른다. 홈 2단 선택에서 쓴다.
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
    case ListIds.favorites:
      items = [
        for (final item in all)
          if (favoriteIds.contains(item.id)) item,
      ];
      break;
    case ListIds.user:
      items = [
        for (final item in all)
          if (item.listId == ListIds.user) item,
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

/// 저장된 목록이 없거나 지워졌으면 빈 값.
/// 홈에서는 카드 대신 목록 선택 화면을 연다.
String resolveListId(String selected, List<StudyList> lists) {
  if (selected.isEmpty) {
    return '';
  }
  for (final list in lists) {
    if (list.id == selected) {
      return selected;
    }
  }
  return '';
}

/// UserStore의 `selectedKind` 문자열을 enum으로.
/// `mixed`나 빈 값은 "아직 고르지 않음"으로 본다.
EntryKind? parseEntryKind(String? raw) {
  if (raw == null || raw.isEmpty || raw == 'mixed') {
    return null;
  }
  return EntryKind.fromName(raw);
}

/// 예전 데이터에 kind가 없을 때 listId로 추측한다.
EntryKind? inferKindFromListId(String listId) {
  if (listId.contains('verb') || listId.contains('word')) {
    return EntryKind.word;
  }
  if (listId.contains('kanji')) {
    return EntryKind.kanji;
  }
  return null;
}

/// [nonce]가 0이면 원래 순서.
/// 아니면 같은 시드로 섞어서, 화면이 다시 그려져도 순서가 유지된다.
List<Kanji> withShuffle(List<Kanji> items, int nonce) {
  if (nonce == 0 || items.length < 2) {
    return items;
  }
  return [...items]..shuffle(Random(nonce));
}

/// 빈 목록 안내. 즐겨찾기는 "즐겨찾은 한자/단어가 없습니다".
String emptyListMessage(
  AppLocalizations l10n, {
  required String listId,
  required EntryKind? kind,
}) {
  if (listId == ListIds.favorites) {
    return l10n.emptyFavorites(
      kind == EntryKind.word ? l10n.kindWord : l10n.kindKanji,
    );
  }
  return l10n.emptyList;
}

/// 직접 추가 목록의 기본 이름. 한자면 "추가한 한자", 단어면 "추가한 단어".
String defaultUserListTitle(AppLocalizations l10n, EntryKind? kind) {
  return l10n.listUser(
    kind == EntryKind.word ? l10n.kindWord : l10n.kindKanji,
  );
}

/// 한자 또는 동사만. 2단 선택에서 종류를 이미 골랐기 때문.
List<StudyList> composeListsForKind({
  required EntryKind kind,
  required String userTitle,
  required String favoritesTitle,
  required List<StudyList> builtin,
  List<UserDeck> userDecks = const [],
  String userListTitle = '',
  bool showUserList = true,
}) {
  final mineTitle = userListTitle.isEmpty ? userTitle : userListTitle;
  return [
    for (final list in builtin)
      if (list.kind == kind) list,
    for (final deck in userDecks)
      if (deck.kind == kind)
        StudyList(
          id: deck.id,
          kind: deck.kind,
          titleKo: deck.title,
          titleJa: deck.title,
          isVirtual: true,
        ),
    if (showUserList)
      StudyList(
        id: ListIds.user,
        kind: kind,
        titleKo: mineTitle,
        titleJa: mineTitle,
        isVirtual: true,
      ),
    StudyList(
      id: ListIds.favorites,
      kind: kind,
      titleKo: favoritesTitle,
      titleJa: favoritesTitle,
      isVirtual: true,
    ),
  ];
}

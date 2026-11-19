import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/kanji_detail/kanji_detail_repository.dart';
import '../../shared/models/kanji.dart';
import '../../shared/models/study_list.dart';
import 'database/app_database.dart';
import 'storage/user_store.dart';
import 'study_filter.dart';

/// 앱 전역 상태.
///
/// - [appDatabaseProvider]: 세션용 인메모리 DB
/// - [userStoreProvider]: persist. [main.dart]에서 override
/// - [catalogControllerProvider]: 화면에 주는 카드·목록
/// - [studyPrefsProvider]: 다크모드·정답 항상 표시
/// - [studySessionProvider]: 홈에서 고른 한자/동사·목록
/// - [quizSessionProvider]: 퀴즈 탭 전용. 홈과 목록을 섞지 않음

/// SQLite가 아니라 세션용 인메모리 DB.
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// [main.dart]에서 실제 [UserStore]로 override한다.
/// override 없이 읽으면 앱이 잘못된 순서로 뜬 것이므로 바로 실패시킨다.
final userStoreProvider = Provider<UserStore>((ref) {
  throw StateError('userStoreProvider must be overridden in main');
});

final kanjiRepositoryProvider = Provider<KanjiRepository>((ref) {
  return KanjiRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(userStoreProvider),
  );
});

/// 화면에 쓰는 스냅샷: 카드 전체 + 즐겨찾기 id + 목록 메타.
///
/// Repository를 직접 구독하지 않고, 이 객체를 통해 필터·드롭다운을 만든다.
class CatalogState {
  const CatalogState({
    required this.kanjis,
    required this.favoriteIds,
    required this.builtinLists,
    this.userDecks = const [],
    this.userListTitle = '',
    this.userListHidden = false,
  });

  final List<Kanji> kanjis;
  final Set<String> favoriteIds;
  final List<StudyList> builtinLists;
  final List<UserDeck> userDecks;
  final String userListTitle;
  final bool userListHidden;

  Kanji? byId(String id) {
    for (final kanji in kanjis) {
      if (kanji.id == id) {
        return kanji;
      }
    }
    return null;
  }

  bool isFavorite(String id) => favoriteIds.contains(id);

  List<Kanji> get favorites => [
        for (final kanji in kanjis)
          if (favoriteIds.contains(kanji.id)) kanji,
      ];

  /// [itemsForList] 래퍼. [kind]를 넘기면 한자/단어만 남긴다.
  List<Kanji> itemsFor(String listId, {EntryKind? kind}) {
    return itemsForList(
      all: kanjis,
      favoriteIds: favoriteIds,
      listId: listId,
      kind: kind,
    );
  }

  /// 홈·목록·퀴즈에 보여 줄 목록 줄. 한자/동사를 고른 뒤 [composeListsForKind].
  List<StudyList> dropdownLists({
    required String userTitle,
    required String favoritesTitle,
    EntryKind? kind,
  }) {
    if (kind == EntryKind.kanji || kind == EntryKind.word) {
      return composeListsForKind(
        kind: kind!,
        userTitle: userTitle,
        favoritesTitle: favoritesTitle,
        builtin: builtinLists,
        userDecks: userDecks,
        userListTitle: userListTitle,
        showUserList: !userListHidden,
      );
    }
    return const [];
  }

  StudyList? listById(String id, {required List<StudyList> dropdown}) {
    for (final list in dropdown) {
      if (list.id == id) {
        return list;
      }
    }
    return null;
  }
}

/// 시드·사용자 카드·즐겨찾기를 한곳에서 읽고 쓴다.
///
/// 쓰기 뒤에는 항상 [_reload]로 스냅샷을 다시 만든다.
class CatalogController extends AsyncNotifier<CatalogState> {
  @override
  FutureOr<CatalogState> build() {
    final repo = ref.read(kanjiRepositoryProvider);
    // 시드를 runApp 전에 읽어 두면 Future를 만들지 않아 로딩 프레임이 없다.
    if (repo.isReady) {
      return _snapshot(repo.loadedKanjis());
    }
    return _load();
  }

  Future<CatalogState> _load() async {
    final repo = ref.read(kanjiRepositoryProvider);
    return _snapshot(await repo.all());
  }

  CatalogState _snapshot(List<Kanji> kanjis) {
    final repo = ref.read(kanjiRepositoryProvider);
    final data = ref.read(userStoreProvider).load();
    return CatalogState(
      kanjis: kanjis,
      favoriteIds: repo.favoriteIds,
      builtinLists: repo.builtinLists,
      userDecks: data.userDecks,
      userListTitle: data.userListTitle,
      userListHidden: data.userListHidden,
    );
  }

  Future<void> _reload() async {
    final repo = ref.read(kanjiRepositoryProvider);
    state = AsyncData(_snapshot(await repo.all()));
  }

  /// 새 목록 id. 이름이 비면 null.
  Future<String?> createUserDeck(EntryKind kind, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final store = ref.read(userStoreProvider);
    final decks = store.load().userDecks;
    final id = 'user_${DateTime.now().millisecondsSinceEpoch}';
    await store.patch(
      userDecks: [
        ...decks,
        UserDeck(id: id, kind: kind, title: trimmed),
      ],
    );
    await _reload();
    return id;
  }

  Future<void> renameUserList(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || !canEditList(id)) {
      return;
    }
    final store = ref.read(userStoreProvider);
    if (id == ListIds.user) {
      await store.patch(userListTitle: trimmed);
    } else {
      final decks = [
        for (final deck in store.load().userDecks)
          if (deck.id == id)
            UserDeck(id: deck.id, kind: deck.kind, title: trimmed)
          else
            deck,
      ];
      await store.patch(userDecks: decks);
    }
    await _reload();
  }

  /// 목록 안 사용자 카드 수. 내가 추가는 한자·단어를 같이 담아 종류를 가리지 않는다.
  int userCardCount(String id) {
    final current = state.valueOrNull;
    if (current == null) {
      return 0;
    }
    return current.kanjis
        .where((kanji) => kanji.listId == id && kanji.isUserAdded)
        .length;
  }

  /// 목록과 안의 사용자 카드를 함께 지운다.
  /// 내가 추가는 숨기고 바꿔 둔 이름도 처음으로 돌린다. 다시 켜지지 않는다.
  Future<void> deleteUserList(String id) async {
    if (!canEditList(id)) {
      return;
    }
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final repo = ref.read(kanjiRepositoryProvider);
    final store = ref.read(userStoreProvider);
    await repo.deleteUserKanjis([
      for (final kanji in current.kanjis)
        if (kanji.listId == id && kanji.isUserAdded) kanji.id,
    ]);
    final data = store.load();
    final isMine = id == ListIds.user;
    await store.patch(
      userDecks: [
        for (final deck in data.userDecks)
          if (deck.id != id) deck,
      ],
      userListHidden: isMine ? true : null,
      userListTitle: isMine ? '' : null,
    );
    await _reload();
  }

  Future<void> toggleFavorite(String id) async {
    await ref.read(kanjiRepositoryProvider).toggleFavorite(id);
    await _reload();
  }

  Future<String?> addUserKanji(Kanji kanji) async {
    final error = await ref.read(kanjiRepositoryProvider).addUserKanji(kanji);
    if (error == null) {
      await _reload();
    }
    return error;
  }

  Future<String?> updateKanji(Kanji kanji) async {
    final error = await ref.read(kanjiRepositoryProvider).updateKanji(kanji);
    if (error == null) {
      await _reload();
    }
    return error;
  }

  Future<void> deleteUserKanji(String id) async {
    await ref.read(kanjiRepositoryProvider).deleteUserKanji(id);
    await _reload();
  }
}

final catalogControllerProvider =
    AsyncNotifierProvider<CatalogController, CatalogState>(
  CatalogController.new,
);

/// 정답 항상 표시 / 다크 모드. 둘 다 로컬 JSON에 남긴다.
class StudyPrefs {
  const StudyPrefs({
    required this.alwaysShowAnswer,
    required this.isDark,
  });

  final bool alwaysShowAnswer;
  final bool isDark;
}

/// 학습 표시 설정을 [UserStore]와 동기화한다.
class StudyPrefsNotifier extends Notifier<StudyPrefs> {
  @override
  StudyPrefs build() {
    final data = ref.read(userStoreProvider).load();
    return StudyPrefs(
      alwaysShowAnswer: data.alwaysShowAnswer,
      isDark: data.isDark,
    );
  }

  Future<void> toggleAlwaysShowAnswer() async {
    final next = !state.alwaysShowAnswer;
    await ref.read(userStoreProvider).patch(alwaysShowAnswer: next);
    state = StudyPrefs(alwaysShowAnswer: next, isDark: state.isDark);
  }

  Future<void> toggleDark() async {
    final next = !state.isDark;
    await ref.read(userStoreProvider).patch(isDark: next);
    state = StudyPrefs(
      alwaysShowAnswer: state.alwaysShowAnswer,
      isDark: next,
    );
  }
}

final studyPrefsProvider =
    NotifierProvider<StudyPrefsNotifier, StudyPrefs>(StudyPrefsNotifier.new);

/// 홈에서 고른 종류·목록·셔플 시드.

class StudySession {
  const StudySession({
    this.kind,
    this.listId = '',
    this.shuffleNonce = 0,
  });

  final EntryKind? kind;
  final String listId;

  /// 0이면 원래 순서. 셔플 버튼을 누르면 시각(ms)으로 바뀌고 같은 시드로 섞는다.
  final int shuffleNonce;

  bool get hasKind => kind != null;

  bool get hasDeck => kind != null && listId.isNotEmpty;
}

class StudySessionNotifier extends Notifier<StudySession> {
  @override
  StudySession build() {
    final data = ref.read(userStoreProvider).load();
    // 목록은 라우트로 연다. 다시 켜면 종류만 복원하고 카드는 열지 않는다.
    return StudySession(kind: parseEntryKind(data.selectedKind));
  }

  /// 1단계 화면
  Future<void> selectKind(EntryKind kind) async {
    await ref.read(userStoreProvider).patch(
          selectedKind: kind.jsonName,
          selectedListId: '',
        );
    state = StudySession(kind: kind);
    ref.read(quizSessionProvider.notifier).selectKind(kind);
  }

  Future<void> selectList(String id) async {
    await ref.read(userStoreProvider).patch(selectedListId: id);
    state = StudySession(kind: state.kind, listId: id);
  }

  Future<void> clearList() async {
    await ref.read(userStoreProvider).patch(selectedListId: '');
    state = StudySession(kind: state.kind);
  }

  Future<void> clearKind() async {
    await ref.read(userStoreProvider).patch(
          selectedKind: '',
          selectedListId: '',
        );
    state = const StudySession();
    ref.read(quizSessionProvider.notifier).clearKind();
  }

  void shuffle() {
    state = StudySession(
      kind: state.kind,
      listId: state.listId,
      shuffleNonce: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

final studySessionProvider =
    NotifierProvider<StudySessionNotifier, StudySession>(
  StudySessionNotifier.new,
);

/// 퀴즈 탭 전용 세션. persist하지 않고, 홈 카드 선택과 목록을 섞지 않는다.
/// 처음 열 때는 홈의 kind만 빌려 온다 ([AppShell]에서 복사).
class QuizSessionNotifier extends Notifier<StudySession> {
  @override
  StudySession build() {
    final study = ref.read(studySessionProvider);
    return StudySession(kind: study.kind);
  }

  void selectKind(EntryKind kind) {
    state = StudySession(kind: kind);
  }

  void selectList(String id) {
    state = StudySession(kind: state.kind, listId: id);
  }

  void clearList() {
    state = StudySession(kind: state.kind);
  }

  void clearKind() {
    state = const StudySession();
  }
}

final quizSessionProvider = NotifierProvider<QuizSessionNotifier, StudySession>(
  QuizSessionNotifier.new,
);

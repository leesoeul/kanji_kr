import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/kanji_detail/kanji_detail_repository.dart';
import '../../shared/models/kanji.dart';
import '../../shared/models/study_list.dart';
import 'database/app_database.dart';
import 'storage/user_store.dart';
import 'study_filter.dart';

/// SQLite가 아니라 세션용 인메모리 DB.
/// SQLite ではなくセッション用インメモリ DB。
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// `main.dart`에서 실제 UserStore로 override한다.
/// `main.dart` で実 UserStore に override する。
final userStoreProvider = Provider<UserStore>((ref) {
  throw StateError('userStoreProvider must be overridden in main');
});

final kanjiRepositoryProvider = Provider<KanjiRepository>((ref) {
  return KanjiRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(userStoreProvider),
  );
});

/// 화면에 쓰는 한자 목록 + 즐겨찾기 id + 리스트 메타.
/// 画面で使う漢字一覧 + お気に入り id + リストメタ。
class CatalogState {
  const CatalogState({
    required this.kanjis,
    required this.favoriteIds,
    required this.builtinLists,
    required this.importedLists,
  });

  final List<Kanji> kanjis;
  final Set<String> favoriteIds;
  final List<StudyList> builtinLists;
  final List<StudyList> importedLists;

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

  List<Kanji> itemsFor(String listId, {EntryKind? kind}) {
    return itemsForList(
      all: kanjis,
      favoriteIds: favoriteIds,
      listId: listId,
      kind: kind,
    );
  }

  List<StudyList> dropdownLists({
    required String allTitle,
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
        imported: importedLists,
      );
    }
    return composeStudyLists(
      allTitle: allTitle,
      userTitle: userTitle,
      favoritesTitle: favoritesTitle,
      builtin: builtinLists,
      imported: importedLists,
    );
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

/// 시드·사용자 한자·즐겨찾기를 한곳에서 읽고 쓴다.
/// シード・ユーザー漢字・お気に入りを一箇所で読み書きする。
class CatalogController extends AsyncNotifier<CatalogState> {
  @override
  Future<CatalogState> build() async {
    final repo = ref.read(kanjiRepositoryProvider);
    final kanjis = await repo.all();
    return CatalogState(
      kanjis: kanjis,
      favoriteIds: repo.favoriteIds,
      builtinLists: repo.builtinLists,
      importedLists: repo.importedLists,
    );
  }

  Future<void> _reload() async {
    final repo = ref.read(kanjiRepositoryProvider);
    state = AsyncData(
      CatalogState(
        kanjis: await repo.all(),
        favoriteIds: repo.favoriteIds,
        builtinLists: repo.builtinLists,
        importedLists: repo.importedLists,
      ),
    );
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

  Future<int> importJson(String raw) async {
    final count = await ref.read(kanjiRepositoryProvider).importJson(raw);
    await _reload();
    final imported = state.value?.importedLists;
    if (imported != null && imported.isNotEmpty) {
      final last = imported.last;
      final kind =
          last.kind == EntryKind.word ? EntryKind.word : EntryKind.kanji;
      await ref.read(studySessionProvider.notifier).selectKind(kind);
      await ref.read(studySessionProvider.notifier).selectList(last.id);
    }
    return count;
  }
}

final catalogControllerProvider =
    AsyncNotifierProvider<CatalogController, CatalogState>(
  CatalogController.new,
);

/// 정답 항상 표시 / 다크 모드. 둘 다 로컬 JSON에 남긴다.
/// 答え常時表示 / ダークモード。どちらもローカルJSONに残す。
class StudyPrefs {
  const StudyPrefs({
    required this.alwaysShowAnswer,
    required this.isDark,
  });

  final bool alwaysShowAnswer;
  final bool isDark;
}

/// 학습 표시 설정을 UserStore와 동기화한다.
/// 学習表示設定を UserStore と同期する。
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

/// 홈·목록·퀴즈가 같이 보는 선택 목록과 셔플 시드.
/// ホーム・一覧・クイズが共有する選択一覧とシャッフルシード。
class StudySession {
  const StudySession({
    this.kind,
    this.listId = '',
    this.shuffleNonce = 0,
  });

  final EntryKind? kind;
  final String listId;
  final int shuffleNonce;

  bool get hasKind => kind != null;

  bool get hasDeck => kind != null && listId.isNotEmpty;
}

class StudySessionNotifier extends Notifier<StudySession> {
  @override
  StudySession build() {
    final data = ref.read(userStoreProvider).load();
    final listId = data.selectedListId;
    var kind = parseEntryKind(data.selectedKind);
    kind ??= inferKindFromListId(listId);
    return StudySession(kind: kind, listId: listId);
  }

  Future<void> selectKind(EntryKind kind) async {
    await ref.read(userStoreProvider).patch(
          selectedKind: kind.jsonName,
          selectedListId: '',
        );
    state = StudySession(kind: kind);
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

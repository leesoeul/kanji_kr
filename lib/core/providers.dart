import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/kanji_detail/kanji_detail_repository.dart';
import '../../shared/models/kanji.dart';
import 'database/app_database.dart';
import 'storage/user_store.dart';

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

/// 화면에 쓰는 한자 목록 + 즐겨찾기 id.
/// 画面で使う漢字一覧 + お気に入り id。
class CatalogState {
  const CatalogState({
    required this.kanjis,
    required this.favoriteIds,
  });

  final List<Kanji> kanjis;
  final Set<String> favoriteIds;

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
    );
  }

  Future<void> _reload() async {
    final repo = ref.read(kanjiRepositoryProvider);
    state = AsyncData(
      CatalogState(
        kanjis: await repo.all(),
        favoriteIds: repo.favoriteIds,
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


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/providers.dart';
import 'core/storage/user_store.dart';
import 'features/kanji_detail/kanji_detail_repository.dart';

/// 앱 진입점.
///
/// [UserStore]와 시드 카탈로그는 첫 화면보다 먼저 연다.
/// 이 동안은 스플래시가 남아 있고, 홈은 로딩 인디케이터 없이 고르기 화면으로 시작한다.
/// 기본 Provider는 override 없이 쓰면 예외를 던지도록 막아 두었다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await UserStore.create();
  final database = AppDatabase();
  final repository = KanjiRepository(database, store);
  await repository.ensureReady();
  runApp(
    ProviderScope(
      overrides: [
        userStoreProvider.overrideWithValue(store),
        appDatabaseProvider.overrideWithValue(database),
        kanjiRepositoryProvider.overrideWithValue(repository),
      ],
      child: const KanjiKrApp(),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/storage/user_store.dart';

/// 앱 진입점.
///
/// [UserStore]는 비동기로 열어야 해서, [ProviderScope]를 만들기 전에
/// 먼저 연 다음 [userStoreProvider]에 주입한다.
/// 기본 Provider는 override 없이 쓰면 예외를 던지도록 막아 두었다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await UserStore.create();
  runApp(
    ProviderScope(
      overrides: [
        userStoreProvider.overrideWithValue(store),
      ],
      child: const KanjiKrApp(),
    ),
  );
}

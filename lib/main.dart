import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/storage/user_store.dart';

/// 로컬 저장소를 연 뒤에야 Provider를 주입할 수 있다.
/// 로컬ストアを開いてから Provider を注入する。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await UserStore.create();
  runApp(
    ProviderScope(
      overrides: [
        // 기본 Provider는 예외를 던지므로, 여기서 실제 UserStore를 넣는다.
        // 既定 Provider は例外を投げるので、ここで実 UserStore を入れる。
        userStoreProvider.overrideWithValue(store),
      ],
      child: const KanjiKrApp(),
    ),
  );
}

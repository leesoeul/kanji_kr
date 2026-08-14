import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// 루트 앱. 테마는 학습 화면의 다크 토글과 연동한다.
/// ルートアプリ。テーマは学習画面のダーク切替と連動する。
class KanjiKrApp extends ConsumerWidget {
  const KanjiKrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final prefs = ref.watch(studyPrefsProvider);

    return MaterialApp.router(
      title: '한자 학습',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: prefs.isDark ? ThemeMode.dark : ThemeMode.light,
      // ja ARB는 있지만, 현재 UI 언어는 한국어로 고정.
      // ja ARB はあるが、現在の UI 言語は韓国語固定。
      locale: const Locale('ko'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }
}

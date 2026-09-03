import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// 루트 위젯. 라우터·테마·로케일을 여기서 묶는다.
///
/// 다크 모드는 [studyPrefsProvider]와 연동한다 (학습 화면 해 아이콘).
/// ja ARB는 있지만 UI locale은 한국어로 고정한다.
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
      locale: const Locale('ko'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }
}

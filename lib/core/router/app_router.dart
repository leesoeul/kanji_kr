import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/favorites/favorites_page.dart';
import '../../features/kanji_add/kanji_add_page.dart';
import '../../features/kanji_list/kanji_list_page.dart';
import '../../features/quiz/quiz_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/study/study_page.dart';
import '../l10n/generated/app_localizations.dart';

/// 하단 4탭은 Shell로 상태를 유지하고, 추가/수정/설정은 탭 위에 올린다.
/// 下部4タブは Shell で状態を保持し、追加/修正/設定はタブの上に載せる。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const StudyPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/list',
                builder: (context, state) => const KanjiListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/quiz',
                builder: (context, state) => const QuizPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesPage(),
              ),
            ],
          ),
        ],
      ),
      // 목록·즐겨찾기에서 특정 카드로 바로 들어갈 때.
      // 一覧・お気に入りから特定カードへ直接入るとき。
      GoRoute(
        path: '/kanji/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return StudyPage(
            initialId: id,
            showBack: true,
          );
        },
      ),
      GoRoute(
        path: '/add',
        builder: (context, state) => const KanjiAddPage(),
      ),
      GoRoute(
        path: '/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return KanjiAddPage(kanjiId: id);
        },
      ),
      // 하단 탭에는 아직 없음. 직접 경로로만 진입.
      // 下部タブにはまだない。直接パスだけで入る。
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

/// 홈 / 목록 / 퀴즈 / 즐겨찾기 탭 셸.
/// ホーム / 一覧 / クイズ / お気に入りタブシェル。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.homeTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l10n.kanjiList,
          ),
          NavigationDestination(
            icon: const Icon(Icons.quiz_outlined),
            selectedIcon: const Icon(Icons.quiz),
            label: l10n.quizTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            label: l10n.favorites,
          ),
        ],
      ),
    );
  }
}

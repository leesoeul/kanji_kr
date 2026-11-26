import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/kanji_add/kanji_add_page.dart';
import '../../features/kanji_list/kanji_list_page.dart';
import '../../features/quiz/quiz_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/study/study_page.dart';
import '../../shared/models/study_list.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers.dart';

/// 하단 4탭은 [StatefulShellRoute]로 상태를 유지하고,
/// 추가/수정/설정·특정 카드는 탭 위에 올린다 (셸 밖 라우트).
///
/// 탭 인덱스: 0 홈, 1 목록, 2 퀴즈, 3 검색. 즐겨찾기는 목록 탭 안의 목록이다.
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
                path: '/search',
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/study/:listId',
        builder: (context, state) {
          return StudyPage(
            listId: state.pathParameters['listId']!,
            showBack: true,
          );
        },
      ),
      GoRoute(
        path: '/deck/:listId',
        builder: (context, state) {
          return KanjiListPage(listId: state.pathParameters['listId']!);
        },
      ),
      GoRoute(
        path: '/quiz/:listId',
        builder: (context, state) {
          return QuizPage(listId: state.pathParameters['listId']!);
        },
      ),
      // 목록·즐겨찾기에서 특정 카드로 바로 들어갈 때.
      GoRoute(
        path: '/kanji/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return StudyPage(
            initialId: id,
            listId: state.uri.queryParameters['list'],
            showBack: true,
            revealAnswer: state.uri.queryParameters['reveal'] == '1',
          );
        },
      ),
      GoRoute(
        path: '/add',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          final kind = query['kind'];
          return KanjiAddPage(
            listId: query['list'],
            initialQuery: query['q'],
            initialKind: kind == null ? null : EntryKind.fromName(kind),
          );
        },
      ),
      GoRoute(
        path: '/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return KanjiAddPage(kanjiId: id);
        },
      ),
      // 하단 탭에는 아직 없음. 직접 경로로만 진입.
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

/// 홈 / 목록 / 퀴즈 / 검색 탭 셸.
///
/// 한자/동사를 고르기 전에는 하단 바를 숨긴다. 탭으로 종류를 우회하지 못하게.
/// 카드·리스트·퀴즈는 셸 밖 페이지라 하단 바를 덮는다.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final study = ref.watch(studySessionProvider);
    final index = navigationShell.currentIndex;
    // 종류를 아직 안 골랐으면 어느 탭이든 하단 바를 숨긴다.
    final hideNav = !study.hasKind;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: hideNav
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: navigationShell.goBranch,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.style_outlined),
                  selectedIcon: const Icon(Icons.style),
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
                  icon: const Icon(Icons.search),
                  selectedIcon: const Icon(Icons.manage_search),
                  label: l10n.searchTab,
                ),
              ],
            ),
    );
  }
}

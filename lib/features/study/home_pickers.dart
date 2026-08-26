import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/study_list.dart';

/// 홈에서 한자/동사 → 목록 순으로 고른다. 고르기 전에는 카드를 열지 않는다.
/// ホームで漢字/動詞 → 一覧の順に選ぶ。選ぶ前はカードを開かない。
class HomeBrowseBody extends ConsumerWidget {
  const HomeBrowseBody({
    super.key,
    required this.catalog,
    required this.session,
    required this.isDark,
  });

  final CatalogState catalog;
  final StudySession session;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!session.hasKind) {
      return SafeArea(child: _KindStep(isDark: isDark));
    }
    return SafeArea(
      child: _ListStep(
        catalog: catalog,
        kind: session.kind!,
        isDark: isDark,
      ),
    );
  }
}

class _KindStep extends ConsumerWidget {
  const _KindStep({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _BrowseHeader(
          title: l10n.pickKindTitle,
          isDark: isDark,
          onBack: null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _KindCard(
                  title: l10n.kindKanji,
                  icon: Icons.font_download_outlined,
                  onTap: () => ref
                      .read(studySessionProvider.notifier)
                      .selectKind(EntryKind.kanji),
                ),
                const SizedBox(height: 16),
                _KindCard(
                  title: l10n.kindVerb,
                  icon: Icons.menu_book_outlined,
                  onTap: () => ref
                      .read(studySessionProvider.notifier)
                      .selectKind(EntryKind.word),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ListStep extends ConsumerWidget {
  const _ListStep({
    required this.catalog,
    required this.kind,
    required this.isDark,
  });

  final CatalogState catalog;
  final EntryKind kind;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final lists = catalog.dropdownLists(
      allTitle: l10n.listAll,
      userTitle: l10n.listUser,
      favoritesTitle: l10n.favorites,
      kind: kind,
    );

    return Column(
      children: [
        _BrowseHeader(
          title: kind == EntryKind.word ? l10n.kindVerb : l10n.kindKanji,
          isDark: isDark,
          onBack: () => ref.read(studySessionProvider.notifier).clearKind(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.pickListTitle,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: lists.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final list = lists[index];
              final count = catalog
                  .itemsFor(list.id, kind: kind)
                  .length;
              return _ListCard(
                title: list.titleFor(language),
                count: count,
                onTap: () =>
                    ref.read(studySessionProvider.notifier).selectList(list.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BrowseHeader extends ConsumerWidget {
  const _BrowseHeader({
    required this.title,
    required this.isDark,
    required this.onBack,
  });

  final String title;
  final bool isDark;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFE85A7B),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            onPressed: () =>
                ref.read(studyPrefsProvider.notifier).toggleDark(),
            icon: Icon(
              isDark ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
              color: AppTheme.sakura,
            ),
          ),
        ],
      ),
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : AppTheme.creamCard,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.cardBorder, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, size: 40, color: AppTheme.meaningPink),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF5C3A45),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.count,
    required this.onTap,
  });

  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : AppTheme.creamCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                l10n.reviewCount(count),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.meaningPink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppTheme.sakura),
            ],
          ),
        ),
      ),
    );
  }
}

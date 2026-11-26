import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/study_filter.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/study_list.dart';
import '../../shared/widgets/list_name_dialog.dart';
import 'kanji_search_sheet.dart';

/// 목록을 고른 뒤 여는 페이지. 탭 안에 쌓지 않고 push한다.
enum ListOpenTarget { study, deck, quiz }

/// 홈·목록·퀴즈에서 한자/동사 → 목록 순으로 고른다. 고르기 전에는 카드를 열지 않는다.
///
/// 한자/동사는 앱 전역 ([studySessionProvider]).
/// 목록을 고르면 [openAs]에 따라 카드·리스트·퀴즈 페이지를 push한다.
/// [titleOverride]가 있으면 상단에 간단한 타이틀 헤더를 표시한다.
class HomeBrowseBody extends ConsumerWidget {
  const HomeBrowseBody({
    super.key,
    required this.catalog,
    required this.session,
    required this.isDark,
    this.openAs = ListOpenTarget.study,
    this.titleOverride,
  });

  final CatalogState catalog;
  final StudySession session;
  final bool isDark;

  /// 목록 선택 시 열 페이지.
  final ListOpenTarget openAs;

  /// 상단에 표시할 타이틀 (예: "홈", "목록", "퀴즈")
  final String? titleOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!session.hasKind) {
      return const SafeArea(child: _KindStep());
    }
    return SafeArea(
      child: _ListStep(
        catalog: catalog,
        kind: session.kind!,
        isDark: isDark,
        openAs: openAs,
        titleOverride: titleOverride,
      ),
    );
  }
}

/// 한자 / 동사 두 장. 고르면 kind만 저장하고 목록 단계로 간다.
class _KindStep extends ConsumerWidget {
  const _KindStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _KindCard(
            title: l10n.kindKanji,
            icon: Icons.font_download_outlined,
            onTap: () => _selectKind(ref, EntryKind.kanji),
          ),
          const SizedBox(height: 16),
          _KindCard(
            title: l10n.kindWord,
            icon: Icons.menu_book_outlined,
            onTap: () => _selectKind(ref, EntryKind.word),
          ),
        ],
      ),
    );
  }

  void _selectKind(WidgetRef ref, EntryKind kind) {
    // 한자/동사는 앱 전역. 퀴즈만 따로 고르지 않는다.
    ref.read(studySessionProvider.notifier).selectKind(kind);
  }
}

/// 선택한 kind의 시드·내가 추가·즐겨찾기 목록. 장 수를 같이 보여 준다.
class _ListStep extends ConsumerWidget {
  const _ListStep({
    required this.catalog,
    required this.kind,
    required this.isDark,
    required this.openAs,
    this.titleOverride,
  });

  final CatalogState catalog;
  final EntryKind kind;
  final bool isDark;
  final ListOpenTarget openAs;
  final String? titleOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final subtitle = switch (openAs) {
      ListOpenTarget.study => l10n.pickPracticeList,
      ListOpenTarget.deck => l10n.pickManageList,
      ListOpenTarget.quiz => l10n.pickListTitle,
    };
    final practice = openAs == ListOpenTarget.study;
    final lists = catalog.dropdownLists(
      userTitle: defaultUserListTitle(l10n, kind),
      favoritesTitle: l10n.favorites,
      kind: kind,
    );

    return Column(
      children: [
        _BrowseHeader(
          title: titleOverride ??
              (kind == EntryKind.word ? l10n.kindWord : l10n.kindKanji),
          isDark: isDark,
          onBack: () {
            // 목록·퀴즈에서 뒤로가면 홈과 같이 종류 고르기로. 하단 바는 숨긴다.
            ref.read(studySessionProvider.notifier).clearKind();
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                        ),
                  ),
                ),
              ),
              if (openAs == ListOpenTarget.deck)
                TextButton.icon(
                    onPressed: () => _createList(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.meaningPink,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      l10n.addList,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              openAs == ListOpenTarget.deck ? 96 : 24,
            ),
            itemCount: lists.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final list = lists[index];
              final count = catalog.itemsFor(list.id, kind: kind).length;
              final editable =
                  openAs == ListOpenTarget.deck && canEditList(list.id);
              return _ListCard(
                title: list.titleFor(language),
                count: count,
                onTap: () {
                  if (practice && count == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.emptyPracticeList)),
                    );
                    return;
                  }
                  final id = Uri.encodeComponent(list.id);
                  final path = switch (openAs) {
                    ListOpenTarget.study => '/study/$id',
                    ListOpenTarget.deck => '/deck/$id',
                    ListOpenTarget.quiz => '/quiz/$id',
                  };
                  context.push(path);
                },
                onRename: editable
                    ? () => _renameList(context, ref, list)
                    : null,
                onDelete: editable ? () => _deleteList(context, ref, list) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 뒤로가기(있으면) + 제목 + 다크 토글.
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
          const KanjiSearchButton(),
          IconButton(
            onPressed: () => ref.read(studyPrefsProvider.notifier).toggleDark(),
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
      color: AppTheme.cardColor(context),
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
    this.onRename,
    this.onDelete,
  });

  final String title;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppTheme.cardColor(context),
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
              SizedBox(
                width: 32,
                height: 32,
                child: onRename != null && onDelete != null
                    ? IconButton(
                        tooltip: l10n.renameList,
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(32, 32),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _showListActions(
                          context,
                          title: title,
                          onRename: onRename!,
                          onDelete: onDelete!,
                        ),
                        icon: const Icon(Icons.more_horiz, color: AppTheme.sakura),
                      )
                    : const Center(
                        child: Icon(Icons.chevron_right, color: AppTheme.sakura),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _createList(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final kind = ref.read(studySessionProvider).kind;
  if (kind == null) {
    return;
  }
  final name = await askListName(context, title: l10n.newList);
  if (name == null) {
    return;
  }
  await ref.read(catalogControllerProvider.notifier).createUserDeck(kind, name);
}

Future<void> _renameList(
  BuildContext context,
  WidgetRef ref,
  StudyList list,
) async {
  final l10n = AppLocalizations.of(context);
  final name = await askListName(
    context,
    title: l10n.renameList,
    initial: list.titleFor(Localizations.localeOf(context).languageCode),
  );
  if (name == null) {
    return;
  }
  await ref.read(catalogControllerProvider.notifier).renameUserList(list.id, name);
}

Future<void> _showListActions(
  BuildContext context, {
  required String title,
  required VoidCallback onRename,
  required VoidCallback onDelete,
}) {
  final l10n = AppLocalizations.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: isDark
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.sakura.withValues(alpha: 0.22)
                      : AppTheme.progressPill,
                  foregroundColor:
                      isDark ? AppTheme.sakura : AppTheme.meaningPink,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onRename();
                },
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.renameList),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.meaningPink,
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onDelete();
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.deleteList),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _deleteList(
  BuildContext context,
  WidgetRef ref,
  StudyList list,
) async {
  final controller = ref.read(catalogControllerProvider.notifier);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _DeleteListDialog(
      name: list.titleFor(Localizations.localeOf(context).languageCode),
      count: controller.userCardCount(list.id),
    ),
  );
  if (confirmed != true) {
    return;
  }
  await controller.deleteUserList(list.id);
}

/// 한 줄을 넘치면 글자를 줄여 칸 안에 맞춘다.
class _ShrinkText extends StatelessWidget {
  const _ShrinkText(this.text, {required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, style: style),
    );
  }
}

/// 목록과 안의 단어를 함께 지울지 묻는다. 삭제면 true.
class _DeleteListDialog extends StatelessWidget {
  const _DeleteListDialog({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quiet = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: _ShrinkText(
        l10n.deleteListTitle(name),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (count > 0) ...[
            _ShrinkText(
              l10n.deleteListBody(count),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 4),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.meaningPink,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: quiet),
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}


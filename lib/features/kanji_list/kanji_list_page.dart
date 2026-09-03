import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/study_filter.dart';
import '../../features/study/home_pickers.dart';

/// 시드+사용자 카드 목록 탭.
///
/// 덱이 없으면 홈과 같은 2단 피커. 있으면 타일 리스트.
/// 뒤로가기는 목록 고르기로 돌아간다. 타일을 누르면 `/kanji/:id`.
/// FAB는 `/add`, 업로드 아이콘은 JSON import.
class KanjiListPage extends ConsumerWidget {
  const KanjiListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(studySessionProvider);
    final asyncCatalog = ref.watch(catalogControllerProvider);

    return asyncCatalog.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('$error')),
      ),
      data: (catalog) {
        if (!session.hasDeck) {
          return Scaffold(
            body: HomeBrowseBody(
              catalog: catalog,
              session: session,
              isDark: ref.watch(studyPrefsProvider).isDark,
            ),
          );
        }
        final lists = catalog.dropdownLists(
          userTitle: l10n.listUser,
          favoritesTitle: l10n.favorites,
          kind: session.kind,
        );
        final listId = resolveListId(session.listId, lists);
        final currentList = catalog.listById(listId, dropdown: lists);
        final language = Localizations.localeOf(context).languageCode;
        final listTitle = currentList?.titleFor(language) ?? l10n.kanjiList;
        final items = catalog.itemsFor(listId, kind: session.kind);

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (didPop) {
              return;
            }
            ref.read(studySessionProvider.notifier).clearList();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    ref.read(studySessionProvider.notifier).clearList(),
              ),
              title: Text(listTitle),
              actions: [
                IconButton(
                  tooltip: l10n.importList,
                  onPressed: () => _openImport(context, ref, l10n),
                  icon: const Icon(Icons.file_upload_outlined),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => context.push('/add'),
              icon: const Icon(Icons.add),
              label: Text(l10n.addItem),
            ),
            body: items.isEmpty
                ? Center(child: Text(l10n.emptyList))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final kanji = items[index];
                      return ListTile(
                        leading: Text(
                          kanji.literal,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        title: Text(kanji.displayMeaning),
                        subtitle: Text(
                          kanji.isWord
                              ? kanji.displayReading
                              : (kanji.displayKunOn.isEmpty
                                  ? kanji.koreanMeaning
                                  : kanji.displayKunOn),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.editKanji,
                              onPressed: () =>
                                  context.push('/edit/${kanji.id}'),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () => ref
                                  .read(catalogControllerProvider.notifier)
                                  .toggleFavorite(kanji.id),
                              icon: Icon(
                                catalog.isFavorite(kanji.id)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => context.push('/kanji/${kanji.id}'),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  /// JSON 텍스트를 붙여 넣어 새 목록을 만든다. 성공하면 홈 세션이 그 목록으로 바뀐다.
  Future<void> _openImport(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => _ImportDialog(l10n: l10n),
    );
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    try {
      final count =
          await ref.read(catalogControllerProvider.notifier).importJson(raw);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importSuccess(count))),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importFailed)),
      );
    }
  }
}

/// JSON 텍스트를 붙여 넣는 대화상자. 확인하면 raw 문자열을 돌려준다.
class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.importList),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: widget.l10n.importHint,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.l10n.importAction),
        ),
      ],
    );
  }
}

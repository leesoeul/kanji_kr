import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/study_filter.dart';
import '../../features/study/home_pickers.dart';
import '../../shared/models/kanji.dart';

/// 시드+사용자 카드 목록 탭.
///
/// 덱이 없으면 홈과 같은 2단 피커. 있으면 타일 리스트.
/// 뒤로가기는 목록 고르기로 돌아간다. 타일을 누르면 `/kanji/:id`.
/// FAB는 `/add`.
class KanjiListPage extends ConsumerWidget {
  const KanjiListPage({super.key, this.listId});

  /// `/deck/:listId`. 없으면 탭의 목록 고르기 화면이다.
  final String? listId;

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
        if (listId == null) {
          return Scaffold(
            body: HomeBrowseBody(
              catalog: catalog,
              session: session,
              isDark: ref.watch(studyPrefsProvider).isDark,
              openAs: ListOpenTarget.deck,
              titleOverride: l10n.kanjiList,
            ),
            // 한자/단어를 고르는 첫 화면에서는 숨긴다. 목록 단계부터 보인다.
            floatingActionButton: session.kind == null
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => context.push('/add'),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addWord),
                  ),
          );
        }
        final lists = catalog.dropdownLists(
          userTitle: l10n.listUser,
          favoritesTitle: l10n.favorites,
          kind: session.kind,
        );
        final resolvedId = resolveListId(listId!, lists);
        final currentList = catalog.listById(resolvedId, dropdown: lists);
        final language = Localizations.localeOf(context).languageCode;
        final listTitle = currentList?.titleFor(language) ?? l10n.kanjiList;
        final items = catalog.itemsFor(resolvedId, kind: session.kind);

        return Scaffold(
            appBar: AppBar(
              title: Text(listTitle),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => context.push(
                '/add?list=${Uri.encodeComponent(resolvedId)}',
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.addWord),
            ),
            body: _DeckListBody(
              listId: resolvedId,
              items: items,
              isFavorite: catalog.isFavorite,
              onToggleFavorite: (id) => ref
                  .read(catalogControllerProvider.notifier)
                  .toggleFavorite(id),
            ),
        );
      },
    );
  }
}

/// 덱 헤더 아래 검색창. 이 덱 카드만 [Kanji.matchesQuery]로 거른다.
class _DeckListBody extends StatefulWidget {
  const _DeckListBody({
    required this.listId,
    required this.items,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final String listId;
  final List<Kanji> items;
  final bool Function(String id) isFavorite;
  final ValueChanged<String> onToggleFavorite;

  @override
  State<_DeckListBody> createState() => _DeckListBodyState();
}

class _DeckListBodyState extends State<_DeckListBody> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = widget.items
        .where((kanji) => kanji.matchesQuery(_query.text))
        .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _query,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.searchHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    widget.items.isEmpty ? l10n.emptyList : l10n.noSearchResults,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: shown.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final kanji = shown[index];
                    final reading = kanji.isWord
                        ? kanji.displayReading
                        : kanji.displayKunOn;
                    return _DeckRow(
                      kanji: kanji,
                      reading: reading,
                      meaning: kanji.displayMeaning,
                      isFavorite: widget.isFavorite(kanji.id),
                      onTap: () => context.push(
                        '/kanji/${kanji.id}?list=${Uri.encodeComponent(widget.listId)}',
                      ),
                      onEdit: () => context.push('/edit/${kanji.id}'),
                      onToggleFavorite: () =>
                          widget.onToggleFavorite(kanji.id),
                      editTooltip: l10n.editKanji,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 첫 줄은 일본어와 히라가나, 둘째 줄은 한국어 뜻.
class _DeckRow extends StatelessWidget {
  const _DeckRow({
    required this.kanji,
    required this.reading,
    required this.meaning,
    required this.isFavorite,
    required this.onTap,
    required this.onEdit,
    required this.onToggleFavorite,
    required this.editTooltip,
  });

  final Kanji kanji;
  final String reading;
  final String meaning;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleFavorite;
  final String editTooltip;

  @override
  Widget build(BuildContext context) {
    final quiet = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    final showReading = reading.isNotEmpty && reading != kanji.literal;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(
                          kanji.literal,
                          style: const TextStyle(
                            fontSize: 22,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (showReading) ...[
                          const SizedBox(width: 8),
                          Text(
                            reading,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w400,
                              color: quiet,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meaning,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: editTooltip,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: onToggleFavorite,
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

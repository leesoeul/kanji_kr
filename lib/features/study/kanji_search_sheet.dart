import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../shared/models/kanji.dart';

/// 카탈로그 전체에서 찾아 `/kanji/:id`로 연다. 정답은 펼친 채로 보여 준다.
Future<void> openGlobalKanjiSearch(BuildContext context, WidgetRef ref) async {
  final catalog = ref.read(catalogControllerProvider).valueOrNull;
  if (catalog == null || !context.mounted) {
    return;
  }
  final selected = await showKanjiSearchSheet(
    context: context,
    kanjis: catalog.kanjis,
    l10n: AppLocalizations.of(context),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  context.push('/kanji/${Uri.encodeComponent(selected.id)}?reveal=1');
}

/// 헤더 오른쪽에 고정하는 글로벌 검색 버튼.
class KanjiSearchButton extends ConsumerWidget {
  const KanjiSearchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(catalogControllerProvider).hasValue;
    return IconButton(
      tooltip: AppLocalizations.of(context).searchKanji,
      onPressed: ready ? () => openGlobalKanjiSearch(context, ref) : null,
      icon: const Icon(Icons.search, color: Color(0xFFE85A7B)),
    );
  }
}

/// 한자·뜻·읽기로 카드를 찾는다. 고른 카드를 시트가 닫히며 돌려준다.
Future<Kanji?> showKanjiSearchSheet({
  required BuildContext context,
  required List<Kanji> kanjis,
  required AppLocalizations l10n,
}) {
  return showModalBottomSheet<Kanji>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _KanjiSearchSheet(kanjis: kanjis, l10n: l10n);
    },
  );
}

/// 현재 덱을 쿼리로 거른다. 빈 검색은 전체. 탭하면 시트를 pop하며 그 카드를 돌려준다.
class _KanjiSearchSheet extends StatefulWidget {
  const _KanjiSearchSheet({
    required this.kanjis,
    required this.l10n,
  });

  final List<Kanji> kanjis;
  final AppLocalizations l10n;

  @override
  State<_KanjiSearchSheet> createState() => _KanjiSearchSheetState();
}

class _KanjiSearchSheetState extends State<_KanjiSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.kanjis
        .where((kanji) => kanji.matchesQuery(_query))
        .toList(growable: false);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: widget.l10n.searchHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(child: Text(widget.l10n.noSearchResults))
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final kanji = results[index];
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
                          onTap: () => Navigator.pop(context, kanji),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

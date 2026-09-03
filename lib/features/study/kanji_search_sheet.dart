import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../shared/models/kanji.dart';

/// 한자·뜻·읽기로 현재 덱 안 카드를 찾아, 학습 인덱스로 점프한다.
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

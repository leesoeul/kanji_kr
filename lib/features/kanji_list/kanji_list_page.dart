import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';

/// 시드+사용자 한자 전체. 탭하면 학습, 연필은 수정, 하트는 즐겨찾기.
/// シード+ユーザー漢字の全体。タップで学習、鉛筆は修正、ハートはお気に入り。
class KanjiListPage extends ConsumerWidget {
  const KanjiListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncCatalog = ref.watch(catalogControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.kanjiList)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addKanji),
      ),
      body: asyncCatalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (catalog) {
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: catalog.kanjis.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final kanji = catalog.kanjis[index];
              return ListTile(
                leading: Text(
                  kanji.literal,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                title: Text(
                  kanji.meaningsKo.isEmpty
                      ? kanji.koreanMeaning
                      : kanji.meaningsKo.join(', '),
                ),
                subtitle: Text(kanji.koreanMeaning),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.editKanji,
                      onPressed: () => context.push('/edit/${kanji.id}'),
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
          );
        },
      ),
    );
  }
}

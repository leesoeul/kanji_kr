import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';

/// 하트를 단 한자만. 데이터는 목록·학습 카드와 같은 favoriteIds.
/// ハートを付けた漢字だけ。データは一覧・学習カードと同じ favoriteIds。
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncCatalog = ref.watch(catalogControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favorites)),
      body: asyncCatalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (catalog) {
          final items = catalog.favorites;
          if (items.isEmpty) {
            return Center(child: Text(l10n.noFavorites));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final kanji = items[index];
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
                trailing: IconButton(
                  tooltip: l10n.bookmarkRemove,
                  onPressed: () => ref
                      .read(catalogControllerProvider.notifier)
                      .toggleFavorite(kanji.id),
                  icon: const Icon(Icons.favorite),
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

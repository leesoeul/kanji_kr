import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/study_filter.dart';

/// 한자/동사를 고른 뒤, 같은 종류의 목록만 보여 주는 풀다운.
/// 漢字/動詞を選んだあと、同じ種類の一覧だけ見せるプルダウン。
class ListPicker extends ConsumerWidget {
  const ListPicker({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(studySessionProvider);
    final catalog = ref.watch(catalogControllerProvider).valueOrNull;
    if (catalog == null || session.kind == null) {
      return const SizedBox.shrink();
    }
    final lists = catalog.dropdownLists(
      allTitle: l10n.listAll,
      userTitle: l10n.listUser,
      favoritesTitle: l10n.favorites,
      kind: session.kind,
    );
    final selected = resolveListId(session.listId, lists);
    if (selected.isEmpty) {
      return const SizedBox.shrink();
    }
    final language = Localizations.localeOf(context).languageCode;

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selected,
        isExpanded: !compact,
        isDense: compact,
        borderRadius: BorderRadius.circular(16),
        items: [
          for (final list in lists)
            DropdownMenuItem(
              value: list.id,
              child: Text(
                list.titleFor(language),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (id) {
          if (id == null) {
            return;
          }
          ref.read(studySessionProvider.notifier).selectList(id);
        },
      ),
    );
  }
}

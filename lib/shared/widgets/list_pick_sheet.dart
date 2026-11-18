import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../models/study_list.dart';
import 'list_name_dialog.dart';

/// 시트에서 "새 목록 만들기"를 눌렀다는 표시. 실제 목록 id와 겹치지 않는다.
const _createTarget = ('', '');

/// 카드를 넣을 목록을 바텀시트로 고른다. 검색 탭과 단어 추가 화면이 같이 쓴다.
///
/// [kind]와 같은 종류의 내 목록, 그리고 숨기지 않았으면 내가 추가를 보여 준다.
/// 맨 아래 "새 목록 만들기"로 만든 목록은 바로 고른 것으로 돌려준다.
/// [preferredId]가 있으면 그 목록을 맨 위에 둔다. 고르면 (id, 이름), 닫으면 null.
Future<(String, String)?> showListPickSheet(
  BuildContext context,
  WidgetRef ref, {
  required EntryKind kind,
  required String literal,
  String? preferredId,
}) async {
  final catalog = ref.read(catalogControllerProvider).valueOrNull;
  if (catalog == null) {
    return null;
  }
  final l10n = AppLocalizations.of(context);
  final userTitle =
      catalog.userListTitle.isEmpty ? l10n.listUser : catalog.userListTitle;
  final targets = <(String, String)>[
    for (final deck in catalog.userDecks)
      if (deck.kind == kind) (deck.id, deck.title),
    if (!catalog.userListHidden) (ListIds.user, userTitle),
  ];
  final preferred = targets.indexWhere((target) => target.$1 == preferredId);
  if (preferred > 0) {
    targets.insert(0, targets.removeAt(preferred));
  }

  final picked = await _showSheet(
    context,
    literal: literal,
    title: l10n.pickTargetList,
    targets: targets,
  );
  if (picked != _createTarget || !context.mounted) {
    return picked;
  }
  final name = await askListName(context, title: l10n.newList);
  if (name == null) {
    return null;
  }
  final id = await ref
      .read(catalogControllerProvider.notifier)
      .createUserDeck(kind, name);
  return id == null ? null : (id, name);
}

Future<(String, String)?> _showSheet(
  BuildContext context, {
  required String literal,
  required String title,
  required List<(String, String)> targets,
}) {
  return showModalBottomSheet<(String, String)>(
    context: context,
    // 탭 안에서 열면 하단 바가 시트를 가린다.
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _ListPickSheet(
      literal: literal,
      title: title,
      targets: targets,
    ),
  );
}

class _ListPickSheet extends StatelessWidget {
  const _ListPickSheet({
    required this.literal,
    required this.title,
    required this.targets,
  });

  final String literal;
  final String title;
  final List<(String, String)> targets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              literal,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: targets.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final target = targets[index];
                  return FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.progressPill,
                      foregroundColor: AppTheme.meaningPink,
                      minimumSize: const Size.fromHeight(50),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, target),
                    icon: const Icon(Icons.folder_outlined),
                    label: Text(target.$2),
                  );
                },
              ),
            ),
            if (targets.isNotEmpty) const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.meaningPink,
                side: const BorderSide(color: AppTheme.cardBorder, width: 1.5),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.pop(context, _createTarget),
              icon: const Icon(Icons.add),
              label: Text(l10n.newList),
            ),
          ],
        ),
      ),
    );
  }
}

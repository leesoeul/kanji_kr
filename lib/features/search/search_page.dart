import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/services/dictionary_db_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/study_list.dart';
import '../../shared/widgets/list_pick_sheet.dart';

/// 하단 네 번째 탭. 내장 사전 DB를 검색하고, 결과를 내 목록에 복사해 넣는다.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _query = TextEditingController();
  Timer? _debounce;
  DictionaryFilter _filter = DictionaryFilter.all;
  List<DictionaryEntry> _results = const [];
  int _searchSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), _runSearch);
  }

  Future<void> _runSearch() async {
    final seq = ++_searchSeq;
    final text = _query.text;
    if (text.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    final service = await ref.read(dictionaryDbProvider.future);
    final found = await service.search(text, filter: _filter);
    // 늦게 끝난 이전 검색이 최신 결과를 덮지 않게 한다.
    if (!mounted || seq != _searchSeq) {
      return;
    }
    setState(() => _results = found);
  }

  void _clear() {
    _debounce?.cancel();
    _query.clear();
    _searchSeq++;
    setState(() => _results = const []);
  }

  void _setFilter(DictionaryFilter filter) {
    setState(() => _filter = filter);
    _runSearch();
  }

  void _openAiAdd() {
    final kind = switch (_filter) {
      DictionaryFilter.kanji => EntryKind.kanji,
      DictionaryFilter.word => EntryKind.word,
      DictionaryFilter.all =>
        ref.read(studySessionProvider).kind ?? EntryKind.word,
    };
    final q = Uri.encodeComponent(_query.text.trim());
    context.push('/add?q=$q&kind=${kind.jsonName}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dbState = ref.watch(dictionaryDbProvider);
    final hasQuery = _query.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTab)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: l10n.dictionaryHint,
                prefixIcon: const Icon(Icons.search, color: AppTheme.sakura),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clear,
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.cardColor(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppTheme.cardBorder,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppTheme.sakura,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final (filter, label) in [
                  (DictionaryFilter.all, l10n.filterAll),
                  (DictionaryFilter.kanji, l10n.filterKanji),
                  (DictionaryFilter.word, l10n.filterWord),
                ]) ...[
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter == filter,
                    onSelected: (_) => _setFilter(filter),
                    showCheckmark: false,
                    selectedColor: AppTheme.progressPill,
                    side: const BorderSide(color: AppTheme.cardBorder),
                    labelStyle: TextStyle(
                      color: _filter == filter ? AppTheme.meaningPink : null,
                      fontWeight: _filter == filter
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: dbState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (_) {
                if (!hasQuery) {
                  return Center(
                    child: Text(
                      l10n.dictionaryEmptyQuery,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _results.length + 1,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    if (index == _results.length) {
                      return _AiFooter(
                        showEmpty: _results.isEmpty,
                        onTap: _openAiAdd,
                      );
                    }
                    final entry = _results[index];
                    return _ResultRow(
                      entry: entry,
                      onTap: () => entry.isSeed
                          ? context.push('/kanji/${entry.sourceId}?reveal=1')
                          : _showEntryDetail(entry),
                      onAdd: () => _pickListAndAdd(entry),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 외부 사전 항목은 카탈로그에 카드가 없어서 시트로 보여 준다.
  Future<void> _showEntryDetail(DictionaryEntry entry) async {
    final add = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surfaceContainerHigh
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _EntryDetailSheet(entry: entry),
    );
    if (add == true && mounted) {
      await _pickListAndAdd(entry);
    }
  }

  Future<void> _pickListAndAdd(DictionaryEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showListPickSheet(
      context,
      ref,
      kind: entry.kind,
      literal: entry.literal,
    );
    if (picked == null || !mounted) {
      return;
    }
    final (listId, listTitle) = picked;
    final error = await ref
        .read(catalogControllerProvider.notifier)
        .addUserKanji(entry.toKanji(listId));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error == null ? l10n.addedToList(listTitle) : l10n.alreadyExists,
          ),
        ),
      );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.entry,
    required this.onTap,
    required this.onAdd,
  });

  final DictionaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quiet =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      entry.literal,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (entry.reading.isNotEmpty &&
                      entry.reading != entry.literal)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        entry.reading,
                        maxLines: 1,
                        style: TextStyle(fontSize: 13, color: quiet),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.meaningKo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.progressPill,
                foregroundColor: AppTheme.meaningPink,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addToMyList),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryDetailSheet extends StatelessWidget {
  const _EntryDetailSheet({required this.entry});

  final DictionaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final quiet = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final showReading =
        entry.reading.isNotEmpty && entry.reading != entry.literal;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Text(label, style: TextStyle(color: quiet)),
              ),
              Expanded(child: Text(value)),
            ],
          ),
        );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    entry.literal,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: entry.isWord ? 40 : 64,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (showReading && entry.isWord)
                Center(
                  child: Text(
                    entry.reading,
                    style: TextStyle(fontSize: 16, color: quiet),
                  ),
                ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  entry.meaningKo,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.meaningPink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!entry.isWord) ...[
                if (entry.kunYomi.isNotEmpty)
                  row(l10n.kunYomi, entry.kunYomi.join('・')),
                if (entry.onYomi.isNotEmpty)
                  row(l10n.onYomi, entry.onYomi.join('・')),
                if (entry.strokeCount > 0)
                  row('', l10n.strokeCountLabel(entry.strokeCount)),
              ],
              if (entry.jlpt.isNotEmpty) row('', l10n.jlptLevel(entry.jlpt)),
              if (entry.examples.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(entry.examples.first.jp, style: theme.textTheme.bodyLarge),
                Text(
                  entry.examples.first.ko,
                  style: TextStyle(color: quiet),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.meaningPink,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.add),
                label: Text(l10n.addToMyList),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiFooter extends StatelessWidget {
  const _AiFooter({required this.showEmpty, required this.onTap});

  final bool showEmpty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        children: [
          if (showEmpty) ...[
            Text(
              l10n.noSearchResults,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.meaningPink,
              side: const BorderSide(color: AppTheme.cardBorder, width: 1.5),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.auto_awesome),
            label: Text(l10n.aiFindAndAdd),
          ),
        ],
      ),
    );
  }
}

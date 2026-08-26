import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/kana.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../shared/models/kanji.dart';
import '../../shared/models/reading.dart';
import '../../shared/models/study_list.dart';

/// `/add`와 `/edit/:id`를 같은 폼으로 처리한다.
/// `/add` と `/edit/:id` を同じフォームで扱う。
class KanjiAddPage extends ConsumerStatefulWidget {
  const KanjiAddPage({super.key, this.kanjiId});

  final String? kanjiId;

  @override
  ConsumerState<KanjiAddPage> createState() => _KanjiAddPageState();
}

class _KanjiAddPageState extends ConsumerState<KanjiAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _literal = TextEditingController();
  final _meaning = TextEditingController();
  final _onYomi = TextEditingController();
  final _kunYomi = TextEditingController();
  final _reading = TextEditingController();
  final _koreanHanja = TextEditingController();
  final _exampleJp = TextEditingController();
  final _exampleKo = TextEditingController();
  bool _saving = false;
  bool _prefilled = false;
  bool _kindInited = false;
  EntryKind _kind = EntryKind.kanji;
  Kanji? _original;

  bool get _isEditing => widget.kanjiId != null;

  bool get _isWord => _kind == EntryKind.word;

  @override
  void dispose() {
    _literal.dispose();
    _meaning.dispose();
    _onYomi.dispose();
    _kunYomi.dispose();
    _reading.dispose();
    _koreanHanja.dispose();
    _exampleJp.dispose();
    _exampleKo.dispose();
    super.dispose();
  }

  void _prefill(Kanji kanji) {
    _original = kanji;
    _kind = kanji.kind == EntryKind.word ? EntryKind.word : EntryKind.kanji;
    _literal.text = kanji.literal;
    _meaning.text = kanji.koreanMeaning.isNotEmpty
        ? kanji.koreanMeaning
        : kanji.meaningsKo.join(', ');
    _onYomi.text = kanji.onYomi
        .map((item) => katakanaToHiragana(item.kana))
        .join('、');
    _kunYomi.text = kanji.kunYomi.map((item) => item.kana).join('、');
    _reading.text = kanji.reading;
    _koreanHanja.text = kanji.koreanHanja;
    if (kanji.examples.isNotEmpty) {
      _exampleJp.text = kanji.examples.first.jp;
      _exampleKo.text = kanji.examples.first.ko;
    }
    _prefilled = true;
    _kindInited = true;
  }

  void _initKind() {
    if (_kindInited || _isEditing) {
      return;
    }
    final session = ref.read(studySessionProvider);
    if (session.kind == EntryKind.word) {
      _kind = EntryKind.word;
    }
    _kindInited = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogControllerProvider).valueOrNull;
    if (_isEditing && !_prefilled && catalog != null) {
      final existing = catalog.byId(widget.kanjiId!);
      if (existing != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _prefilled) {
            return;
          }
          setState(() => _prefill(existing));
        });
      }
    }
    if (!_isEditing && !_kindInited && catalog != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _kindInited) {
          return;
        }
        setState(_initKind);
      });
    }

    if (_isEditing && catalog == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isEditing && _original == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.editKanji)),
        body: const Center(child: Text('—')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? l10n.editKanji
              : (_isWord ? l10n.addWord : l10n.addKanji),
        ),
        actions: [
          // 시드 한자는 삭제 불가. 사용자 추가분만 휴지통.
          // シード漢字は削除不可。ユーザー追加分だけゴミ箱。
          if (_isEditing && _original?.isUserAdded == true)
            IconButton(
              tooltip: l10n.delete,
              onPressed: () => _delete(l10n),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!_isEditing) ...[
              SegmentedButton<EntryKind>(
                segments: [
                  ButtonSegment(
                    value: EntryKind.kanji,
                    label: Text(l10n.kindKanji),
                  ),
                  ButtonSegment(
                    value: EntryKind.word,
                    label: Text(l10n.kindWord),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (next) {
                  setState(() => _kind = next.first);
                },
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _literal,
              decoration: InputDecoration(
                labelText: _isWord ? l10n.surfaceLabel : l10n.literalLabel,
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: _isWord ? 40 : 56,
                  ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.requiredField;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _meaning,
              decoration: InputDecoration(
                labelText: l10n.koreanMeaning,
                hintText: l10n.meaningHint,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.requiredField;
                }
                return null;
              },
            ),
            if (_isWord) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _reading,
                decoration: InputDecoration(
                  labelText: l10n.readingLabel,
                  hintText: l10n.readingHint,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.requiredField;
                  }
                  return null;
                },
              ),
            ] else ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _onYomi,
                decoration: InputDecoration(
                  labelText: l10n.onYomi,
                  hintText: l10n.onYomiHint,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _kunYomi,
                decoration: InputDecoration(
                  labelText: l10n.kunYomi,
                  hintText: l10n.kunYomiHint,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _koreanHanja,
                decoration: InputDecoration(
                  labelText: l10n.koreanHanja,
                  hintText: l10n.koreanHanjaHint,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _exampleJp,
              decoration: InputDecoration(labelText: l10n.exampleJp),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _exampleKo,
              decoration: InputDecoration(labelText: l10n.exampleKo),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : () => _save(l10n),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final literal = _literal.text.trim();
    final meaning = _meaning.text.trim();
    // 한국 한자를 비우면 일본 한자와 같다고 본다.
    // 韓国漢字を空にすると日本漢字と同じとみなす。
    final hanja = _koreanHanja.text.trim().isEmpty
        ? literal
        : _koreanHanja.text.trim();
    final exampleJp = _exampleJp.text.trim();
    final exampleKo = _exampleKo.text.trim();
    final examples = exampleJp.isEmpty && exampleKo.isEmpty
        ? const <KanjiExample>[]
        : [
            KanjiExample(
              jp: exampleJp,
              // 폼에 kana 칸이 없어서, 수정 시 기존 값을 유지한다.
              // フォームに kana 欄がないので、修正時は既存値を維持する。
              kana: _original?.examples.isNotEmpty == true
                  ? _original!.examples.first.kana
                  : '',
              ko: exampleKo,
            ),
          ];
    final readingsOn = _isWord ? const <Reading>[] : _parseReadings(_onYomi.text);
    final readingsKun =
        _isWord ? const <Reading>[] : _parseReadings(_kunYomi.text);
    final reading = _isWord ? _reading.text.trim() : '';
    final Kanji kanji;
    if (_isEditing && _original != null) {
      kanji = _original!.copyWith(
        literal: literal,
        koreanHanja: hanja,
        koreanMeaning: meaning,
        meaningsKo: [meaning],
        onYomi: readingsOn,
        kunYomi: readingsKun,
        examples: examples,
        kind: _kind,
        reading: reading,
      );
    } else {
      kanji = Kanji(
        id: Kanji.userIdFor(literal, kind: _kind),
        literal: literal,
        jlpt: 'USER',
        strokeCount: 0,
        koreanHanja: hanja,
        koreanMeaning: meaning,
        meaningsKo: [meaning],
        onYomi: readingsOn,
        kunYomi: readingsKun,
        examples: examples,
        kind: _kind,
        listId: ListIds.user,
        reading: reading,
        isUserAdded: true,
      );
    }
    final notifier = ref.read(catalogControllerProvider.notifier);
    final error = _isEditing
        ? await notifier.updateKanji(kanji)
        : await notifier.addUserKanji(kanji);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.alreadyExists)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? l10n.saved : l10n.added)),
    );
    context.pop();
  }

  Future<void> _delete(AppLocalizations l10n) async {
    final original = _original;
    if (original == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.delete),
          content: Text(l10n.deleteKanjiConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(catalogControllerProvider.notifier).deleteUserKanji(original.id);
    if (mounted) {
      context.pop();
    }
  }

  /// `,` `、` `/` 공백으로 여러 읽기를 받는다.
  /// `,` `、` `/` 空白で複数の読みを受ける。
  List<Reading> _parseReadings(String raw) {
    return raw
        .split(RegExp(r'[,、/\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((kana) => Reading(kana: kana))
        .toList();
  }
}

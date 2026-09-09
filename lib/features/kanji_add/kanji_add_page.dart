import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/kana.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/services/ai_service.dart';
import '../../shared/models/kanji.dart';
import '../../shared/models/reading.dart';
import '../../shared/models/study_list.dart';

/// `/add`와 `/edit/:id`를 같은 폼으로 처리한다.
///
/// 추가는 한자/단어 세그먼트를 고를 수 있고, 홈에서 동사를 보고 있었으면 단어로 시작한다.
/// 시드 카드는 수정만 되고 삭제(휴지통)는 사용자 추가분만.
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
  void initState() {
    super.initState();
    // 텍스트 변경 시 AI 아이콘 표시를 위한 리스너
    _literal.addListener(_updateUi);
    _meaning.addListener(_updateUi);
    _reading.addListener(_updateUi);
  }

  void _updateUi() {
    setState(() {});
  }

  @override
  void dispose() {
    _literal.removeListener(_updateUi);
    _meaning.removeListener(_updateUi);
    _reading.removeListener(_updateUi);
    _literal.dispose();
    _meaning.dispose();
    _onYomi.dispose();
    _kunYomi.dispose();
    _reading.dispose();
    _exampleJp.dispose();
    _exampleKo.dispose();
    super.dispose();
  }

  /// 수정 진입 시 기존 카드를 폼에 채운다. 음독은 히라가나로 보여 준다.
  void _prefill(Kanji kanji) {
    _original = kanji;
    _kind = kanji.kind == EntryKind.word ? EntryKind.word : EntryKind.kanji;
    _literal.text = kanji.literal;
    _meaning.text = kanji.koreanMeaning.isNotEmpty
        ? kanji.koreanMeaning
        : kanji.meaningsKo.join(', ');
    _onYomi.text =
        kanji.onYomi.map((item) => katakanaToHiragana(item.kana)).join('、');
    _kunYomi.text = kanji.kunYomi.map((item) => item.kana).join('、');
    _reading.text = kanji.reading;
    if (kanji.examples.isNotEmpty) {
      _exampleJp.text = kanji.examples.first.jp;
      _exampleKo.text = kanji.examples.first.ko;
    }
    _prefilled = true;
    _kindInited = true;
  }

  /// 추가 화면에서 홈이 동사면 단어 폼으로 시작한다.
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
          // 초기화 버튼 (추가 모드에서만 표시)
          if (!_isEditing)
            IconButton(
              tooltip: l10n.resetForm,
              onPressed: () => _resetForm(l10n),
              icon: const Icon(Icons.refresh),
            ),
          // 시드 한자는 삭제 불가. 사용자 추가분만 휴지통.
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
                labelText:
                    '${_isWord ? l10n.surfaceLabel : l10n.literalLabel} ${l10n.requiredFieldMark}',
                suffixIcon: _literal.text.trim().isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.auto_awesome),
                        tooltip: l10n.aiAutocomplete,
                        onPressed: () => _openAiSuggestions(l10n),
                      )
                    : null,
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
                labelText: '${l10n.koreanMeaning} ${l10n.requiredFieldMark}',
                hintText: l10n.meaningHint,
                suffixIcon: _meaning.text.trim().isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.auto_awesome),
                        tooltip: l10n.aiAutocomplete,
                        onPressed: () => _openAiSuggestions(l10n),
                      )
                    : null,
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
                  labelText: '${l10n.readingLabel} ${l10n.requiredFieldMark}',
                  hintText: l10n.readingHint,
                  suffixIcon: _reading.text.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.auto_awesome),
                          tooltip: l10n.aiAutocomplete,
                          onPressed: () => _openAiSuggestions(l10n),
                        )
                      : null,
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
    final exampleJp = _exampleJp.text.trim();
    final exampleKo = _exampleKo.text.trim();
    final examples = exampleJp.isEmpty && exampleKo.isEmpty
        ? const <KanjiExample>[]
        : [
            KanjiExample(
              jp: exampleJp,
              // 폼에 kana 칸이 없어서, 수정 시 기존 값을 유지한다.
              kana: _original?.examples.isNotEmpty == true
                  ? _original!.examples.first.kana
                  : '',
              ko: exampleKo,
            ),
          ];
    final readingsOn =
        _isWord ? const <Reading>[] : _parseReadings(_onYomi.text);
    final readingsKun =
        _isWord ? const <Reading>[] : _parseReadings(_kunYomi.text);
    final reading = _isWord ? _reading.text.trim() : '';
    final Kanji kanji;
    if (_isEditing && _original != null) {
      kanji = _original!.copyWith(
        literal: literal,
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

  /// 폼의 모든 입력 사항을 초기화한다.
  Future<void> _resetForm(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.resetForm),
          content: Text(l10n.resetFormConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.resetForm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _literal.clear();
      _meaning.clear();
      _onYomi.clear();
      _kunYomi.clear();
      _reading.clear();
      _exampleJp.clear();
      _exampleKo.clear();
    });
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
    await ref
        .read(catalogControllerProvider.notifier)
        .deleteUserKanji(original.id);
    if (mounted) {
      context.pop();
    }
  }

  /// `,` `、` `/` 공백으로 여러 읽기를 받는다.
  List<Reading> _parseReadings(String raw) {
    return raw
        .split(RegExp(r'[,、/\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((kana) => Reading(kana: kana))
        .toList();
  }

  /// AI 자동완성 다이얼로그를 연다. (Crew AI 백엔드 호출)
  Future<void> _openAiSuggestions(AppLocalizations l10n) async {
    // 키보드 닫기
    FocusScope.of(context).unfocus();

    // 입력된 텍스트 가져오기
    final inputText = _literal.text.isNotEmpty
        ? _literal.text
        : (_meaning.text.isNotEmpty ? _meaning.text : _reading.text);

    if (inputText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력된 텍스트가 없습니다')),
      );
      return;
    }

    // 로딩 표시
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.aiLoadingSuggestions),
              ],
            ),
          ),
        ),
      ),
    );

    List<Kanji> suggestions;

    try {
      // 실제 AI API 호출
      final aiService = AiService();
      suggestions = await aiService.getSuggestions(
        text: inputText.trim(),
        kind: _kind,
      );
    } catch (e) {
      // 에러 발생 시 더미 데이터로 폴백
      print('AI API 호출 실패, 더미 데이터 사용: $e');
      suggestions = _generateDummySuggestions();
    }

    if (!mounted) {
      return;
    }

    // 로딩 다이얼로그 닫기
    Navigator.of(context).pop();

    // AI 추천 카드 다이얼로그 열기
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => _AiSuggestionsDialog(
        suggestions: suggestions,
        onSelectSuggestion: (suggestion) => _fillFormWithSuggestion(suggestion),
        l10n: l10n,
      ),
    );
  }

  /// 더미 추천 데이터 생성 (나중에 Crew AI로 교체 예정)
  List<Kanji> _generateDummySuggestions() {
    if (_isWord) {
      // 단어 더미 데이터
      return [
        const Kanji(
          id: 'dummy_1',
          literal: '山登り',
          jlpt: 'N3',
          strokeCount: 0,
          koreanMeaning: '등산',
          meaningsKo: ['등산', '산타기'],
          onYomi: [],
          kunYomi: [],
          examples: [
            KanjiExample(jp: '週末に山登りに行きます', kana: '', ko: '주말에 등산을 갑니다')
          ],
          kind: EntryKind.word,
          listId: 'ai_suggestion',
          reading: 'やまのぼり',
          isUserAdded: false,
        ),
        const Kanji(
          id: 'dummy_2',
          literal: '富士山',
          jlpt: 'N4',
          strokeCount: 0,
          koreanMeaning: '후지산',
          meaningsKo: ['후지산'],
          onYomi: [],
          kunYomi: [],
          examples: [
            KanjiExample(
                jp: '富士山は日本で一番高い山です', kana: '', ko: '후지산은 일본에서 가장 높은 산입니다')
          ],
          kind: EntryKind.word,
          listId: 'ai_suggestion',
          reading: 'ふじさん',
          isUserAdded: false,
        ),
        const Kanji(
          id: 'dummy_3',
          literal: '山道',
          jlpt: 'N3',
          strokeCount: 0,
          koreanMeaning: '산길',
          meaningsKo: ['산길', '산중의 길'],
          onYomi: [],
          kunYomi: [],
          examples: [
            KanjiExample(jp: '山道を歩いていると鹿に会った', kana: '', ko: '산길을 걷다가 사슴을 만났다')
          ],
          kind: EntryKind.word,
          listId: 'ai_suggestion',
          reading: 'やまみち',
          isUserAdded: false,
        ),
      ];
    } else {
      // 한자 더미 데이터
      return [
        const Kanji(
          id: 'dummy_1',
          literal: '山',
          jlpt: 'N5',
          strokeCount: 3,
          koreanMeaning: '산',
          meaningsKo: ['산', '높은 산'],
          onYomi: [Reading(kana: 'サン'), Reading(kana: 'セン')],
          kunYomi: [Reading(kana: 'やま')],
          examples: [KanjiExample(jp: '山に登る', kana: 'やまにのぼる', ko: '산에 오르다')],
          kind: EntryKind.kanji,
          listId: 'ai_suggestion',
          reading: '',
          isUserAdded: false,
        ),
        const Kanji(
          id: 'dummy_2',
          literal: '川',
          jlpt: 'N5',
          strokeCount: 3,
          koreanMeaning: '내, 강',
          meaningsKo: ['내', '강', '하천'],
          onYomi: [Reading(kana: 'セン')],
          kunYomi: [Reading(kana: 'かわ')],
          examples: [KanjiExample(jp: '川で泳ぐ', kana: 'かわでおよぐ', ko: '강에서 수영하다')],
          kind: EntryKind.kanji,
          listId: 'ai_suggestion',
          reading: '',
          isUserAdded: false,
        ),
        const Kanji(
          id: 'dummy_3',
          literal: '森',
          jlpt: 'N4',
          strokeCount: 12,
          koreanMeaning: '숲',
          meaningsKo: ['숲', '수풀'],
          onYomi: [Reading(kana: 'シン')],
          kunYomi: [Reading(kana: 'もり')],
          examples: [
            KanjiExample(jp: '森を散歩する', kana: 'もりをさんぽする', ko: '숲을 산책하다')
          ],
          kind: EntryKind.kanji,
          listId: 'ai_suggestion',
          reading: '',
          isUserAdded: false,
        ),
      ];
    }
  }

  /// 선택한 추천 카드로 폼을 채운다.
  void _fillFormWithSuggestion(Kanji suggestion) {
    setState(() {
      _literal.text = suggestion.literal;
      _meaning.text = suggestion.koreanMeaning;

      if (_isWord) {
        _reading.text = suggestion.reading;
      } else {
        _onYomi.text = suggestion.onYomi.map((r) => r.kana).join('、');
        _kunYomi.text = suggestion.kunYomi.map((r) => r.kana).join('、');
      }

      if (suggestion.examples.isNotEmpty) {
        _exampleJp.text = suggestion.examples.first.jp;
        _exampleKo.text = suggestion.examples.first.ko;
      }
    });

    // 다이얼로그 닫기
    Navigator.of(context).pop();
  }
}

/// AI 추천 카드 다이얼로그 - 플래시카드 스타일로 3개 보여주기
class _AiSuggestionsDialog extends StatefulWidget {
  const _AiSuggestionsDialog({
    required this.suggestions,
    required this.onSelectSuggestion,
    required this.l10n,
  });

  final List<Kanji> suggestions;
  final Function(Kanji) onSelectSuggestion;
  final AppLocalizations l10n;

  @override
  State<_AiSuggestionsDialog> createState() => _AiSuggestionsDialogState();
}

class _AiSuggestionsDialogState extends State<_AiSuggestionsDialog> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFE85A7B)),
                  const SizedBox(width: 8),
                  Text(
                    widget.l10n.aiSuggestions,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFE85A7B),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // 카드 페이지뷰 with 좌우 화살표
            Expanded(
              child: Row(
                children: [
                  IconButton(
                    onPressed: _currentIndex == 0
                        ? null
                        : () => _goTo(_currentIndex - 1),
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 40,
                      color: Color(0xFFE85A7B),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      itemCount: widget.suggestions.length,
                      itemBuilder: (context, index) {
                        final kanji = widget.suggestions[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _SuggestionCard(
                            kanji: kanji,
                            l10n: widget.l10n,
                          ),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: _currentIndex >= widget.suggestions.length - 1
                        ? null
                        : () => _goTo(_currentIndex + 1),
                    icon: const Icon(
                      Icons.chevron_right,
                      size: 40,
                      color: Color(0xFFE85A7B),
                    ),
                  ),
                ],
              ),
            ),
            // [이 내용으로 채우기] 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    widget
                        .onSelectSuggestion(widget.suggestions[_currentIndex]);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE85A7B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    widget.l10n.fillWithThis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 추천 카드 - 플래시카드와 유사한 스타일
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.kanji,
    required this.l10n,
  });

  final Kanji kanji;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 한자/단어 카드
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE8D5C4), width: 2),
            ),
            child: Container(
              height: 180,
              alignment: Alignment.center,
              child: Text(
                kanji.literal,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: const Color(0xFF5C3A45),
                      fontWeight: FontWeight.w500,
                      fontSize: kanji.isWord ? 56 : 72,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 정보 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 뜻
                _InfoRow(
                  label: l10n.koreanMeaning,
                  value: kanji.koreanMeaning,
                  highlight: true,
                ),
                const SizedBox(height: 8),
                // 읽기 (단어) 또는 음독/훈독 (한자)
                if (kanji.isWord)
                  _InfoRow(
                    label: l10n.readingLabel,
                    value: kanji.reading,
                  )
                else ...[
                  _InfoRow(
                    label: l10n.onYomi,
                    value: kanji.onYomi.map((r) => r.kana).join('、'),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: l10n.kunYomi,
                    value: kanji.kunYomi.map((r) => r.kana).join('、'),
                  ),
                ],
                // 예문
                if (kanji.examples.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.examples,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kanji.examples.first.jp,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    kanji.examples.first.ko,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 정보 행 (레이블: 값)
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: highlight ? 18 : 15,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? const Color(0xFFE85A7B) : null,
            ),
          ),
        ),
      ],
    );
  }
}

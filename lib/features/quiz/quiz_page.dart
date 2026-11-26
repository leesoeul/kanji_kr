import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/kana.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/study_filter.dart';
import '../../core/theme/app_theme.dart';
import '../../features/study/home_pickers.dart';
import '../../shared/models/kanji.dart';
import 'quiz_builder.dart';

/// 목록을 고르면 퀴즈 모드 선택 화면이 나타나고, 사용자가 "시작" 버튼을 눌러 퀴즈를 시작한다.
class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key, this.listId});

  /// `/quiz/:listId`. 없으면 탭의 목록 고르기 화면이다.
  final String? listId;

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  QuizMode _mode = QuizMode.meaning;

  /// 목록 전체에서 만든 문항. 화면에는 [_setStart]부터 20개씩만 낸다.
  List<QuizQuestion> _allQuestions = const [];

  /// 오답 보기를 뽑을 목록. 틀린 문제만 다시 풀 때도 쓴다.
  List<Kanji> _pool = const [];
  int _setStart = 0;
  int _index = 0;

  /// 고른 보기. 아직 안 골랐으면 null, "잘 모르겠어요"는 -1.
  int? _picked;
  int _correctCount = 0;
  List<QuizQuestion> _wrongAnswers = const [];
  bool _playing = false;
  bool _showReading = false;

  List<QuizQuestion> get _questions {
    final end = _setStart + kQuizSetSize;
    return _allQuestions.sublist(
      _setStart,
      end < _allQuestions.length ? end : _allQuestions.length,
    );
  }

  void _begin() {
    final catalog = ref.read(catalogControllerProvider).valueOrNull;
    if (catalog == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final kind = ref.read(studySessionProvider).kind;
    final lists = catalog.dropdownLists(
      userTitle: defaultUserListTitle(l10n, kind),
      favoritesTitle: l10n.favorites,
      kind: kind,
    );
    final listId = resolveListId(widget.listId ?? '', lists);
    final pool = catalog.itemsFor(listId, kind: kind);
    final questions = buildQuiz(items: pool, mode: _mode);
    if (questions.isEmpty) {
      // 카드는 4장 이상이어도 뜻이 겹치면 서로 다른 보기 4개를 못 만든다.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizEmpty(kQuizChoiceCount))),
      );
    }
    setState(() {
      _pool = pool;
      _allQuestions = questions;
      _setStart = 0;
      _startSet();
      _playing = questions.isNotEmpty;
    });
  }

  /// 틀린 문제만 다시 만든다. 오답 보기는 원래 목록에서 뽑는다.
  void _retryWrong() {
    final questions = buildQuiz(
      items: _pool,
      prompts: [for (final wrong in _wrongAnswers) wrong.prompt],
      mode: _mode,
    );
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).quizEmpty(kQuizChoiceCount),
          ),
        ),
      );
      return;
    }
    setState(() {
      _allQuestions = questions;
      _setStart = 0;
      _startSet();
      _playing = true;
    });
  }

  void _nextSet() {
    setState(() {
      _setStart += kQuizSetSize;
      _startSet();
      _playing = true;
    });
  }

  void _startSet() {
    _index = 0;
    _picked = null;
    _correctCount = 0;
    _wrongAnswers = [];
    _showReading = false;
  }

  /// [choice]가 null이면 "잘 모르겠어요". 이미 답했으면 무시한다.
  void _answer(int? choice) {
    if (_picked != null) {
      return;
    }
    final question = _questions[_index];
    final correct = choice != null && choice == question.correctIndex;
    setState(() {
      _picked = choice ?? -1;
      if (correct) {
        _correctCount += 1;
      } else {
        _wrongAnswers = [..._wrongAnswers, question];
      }
    });
  }

  Widget _choiceRow(QuizQuestion question, int row, bool answered) {
    return Row(
      children: [
        for (final column in [0, 1]) ...[
          if (column == 1) const SizedBox(width: 10),
          Expanded(
            child: _ChoiceCard(
              label: question.choices[row * 2 + column],
              kanji: question.choiceKanji[row * 2 + column],
              revealed: answered,
              correct:
                  answered && row * 2 + column == question.correctIndex,
              wrong: answered &&
                  _picked == row * 2 + column &&
                  row * 2 + column != question.correctIndex,
              onTap: () => _answer(row * 2 + column),
            ),
          ),
        ],
      ],
    );
  }

  void _next() {
    if (_index >= _questions.length - 1) {
      setState(() => _playing = false);
      return;
    }
    setState(() {
      _index += 1;
      _picked = null;
      _showReading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(studySessionProvider);
    final asyncCatalog = ref.watch(catalogControllerProvider);
    final playingDeck = widget.listId != null;

    return PopScope(
      canPop: playingDeck || !session.hasKind,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || playingDeck) {
          return;
        }
        if (session.hasKind) {
          ref.read(studySessionProvider.notifier).clearKind();
        }
      },
      child: Scaffold(
        appBar: playingDeck
            ? AppBar(
                title: Text(l10n.quizTitle),
              )
            : null,
        body: asyncCatalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (catalog) {
            if (!playingDeck) {
              return HomeBrowseBody(
                catalog: catalog,
                session: session,
                isDark: ref.watch(studyPrefsProvider).isDark,
                openAs: ListOpenTarget.quiz,
                titleOverride: l10n.quizTitle,
              );
            }
            final lists = catalog.dropdownLists(
              userTitle: defaultUserListTitle(l10n, session.kind),
              favoritesTitle: l10n.favorites,
              kind: session.kind,
            );
            final listId = resolveListId(widget.listId!, lists);
            final items = catalog.itemsFor(listId, kind: session.kind);
            return _body(context, l10n, items);
          },
        ),
      ),
    );
  }

  String _guide(AppLocalizations l10n, QuizQuestion question) {
    if (question.mode == QuizMode.meaning) {
      return l10n.quizGuideMeaning;
    }
    return l10n.quizGuideLiteral(
      question.prompt.isWord ? l10n.kindWord : l10n.kindKanji,
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    List<Kanji> items,
  ) {
    if (_questions.isNotEmpty && !_playing) {
      final remaining = _allQuestions.length - (_setStart + kQuizSetSize);
      return _ResultView(
        l10n: l10n,
        correct: _correctCount,
        total: _questions.length,
        wrongs: _wrongAnswers,
        nextSetCount: remaining <= 0
            ? 0
            : (remaining < kQuizSetSize ? remaining : kQuizSetSize),
        onRetryWrong: _retryWrong,
        onNextSet: _nextSet,
      );
    }
    if (!_playing) {
      // 퀴즈 모드 선택 화면
      final canStart = items.length >= kQuizChoiceCount;

      if (!canStart) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.quizEmpty(kQuizChoiceCount),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.quizModeSelect,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: FilledButton(
                  onPressed: () {
                    setState(() => _mode = QuizMode.meaning);
                    _begin();
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l10n.quizModePickLiteral,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: FilledButton(
                  onPressed: () {
                    setState(() => _mode = QuizMode.literal);
                    _begin();
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l10n.quizModePickMeaning,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final question = _questions[_index];
    final answered = _picked != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Text(
            l10n.quizProgress(_index + 1, _questions.length),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _guide(l10n, question),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5C3A45),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: AppTheme.softCard(context),
              child: _QuizPrompt(
                kanji: question.prompt,
                mode: question.mode,
                l10n: l10n,
                showReading: _showReading,
                onToggleReading: () {
                  setState(() => _showReading = !_showReading);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                for (final row in [0, 1]) ...[
                  if (row == 1) const SizedBox(height: 10),
                  Expanded(child: _choiceRow(question, row, answered)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: answered ? null : () => _answer(null),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.meaningPink,
                side: BorderSide(
                  color: answered
                      ? AppTheme.cardBorder
                      : AppTheme.meaningPink,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                l10n.quizDontKnow,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: answered
                ? _NextGaugeButton(label: l10n.quizNextArrow, onAdvance: _next)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// 문제 칸. 훈독·음독(또는 단어 읽기)은 오른쪽 위 힌트를 열었을 때만 보인다.
class _QuizPrompt extends StatelessWidget {
  const _QuizPrompt({
    required this.kanji,
    required this.mode,
    required this.l10n,
    required this.showReading,
    required this.onToggleReading,
  });

  final Kanji kanji;
  final QuizMode mode;
  final AppLocalizations l10n;
  final bool showReading;
  final VoidCallback onToggleReading;

  @override
  Widget build(BuildContext context) {
    final main =
        mode == QuizMode.meaning ? kanji.literal : kanji.displayMeaning;
    final readings = _readingLine();

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56),
          child: Column(
            children: [
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  main,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: const Color(0xFF5C3A45),
                        fontWeight: mode == QuizMode.meaning
                            ? FontWeight.w600
                            : FontWeight.bold,
                        fontSize: mode == QuizMode.meaning ? 72 : 40,
                      ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: showReading && readings.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            readings,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF5C3A45),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        if (readings.isNotEmpty)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: l10n.quizHint,
              onPressed: onToggleReading,
              icon: Icon(
                showReading ? Icons.lightbulb : Icons.lightbulb_outline,
                color: AppTheme.sakura,
              ),
            ),
          ),
      ],
    );
  }

  String _readingLine() {
    if (kanji.isWord) {
      final reading = kanji.displayReading;
      if (reading.isEmpty) {
        return '';
      }
      return '${l10n.cardReading}: $reading';
    }
    final kun = kanji.kunYomi.map((item) => item.kana).join('・');
    final on =
        kanji.onYomi.map((item) => katakanaToHiragana(item.kana)).join('・');
    return '${l10n.cardKun}: ${kun.isEmpty ? '—' : kun}\n${l10n.cardOn}: ${on.isEmpty ? '—' : on}';
  }
}

/// 2×2 보기 카드. 정답은 초록, 내가 고른 오답은 분홍으로 제자리에서 표시한다.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.kanji,
    required this.revealed,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final String label;
  final Kanji kanji;
  final bool revealed;
  final bool correct;
  final bool wrong;
  final VoidCallback onTap;

  String get _reading => kanji.displayKunOn.trim();

  /// 표제어가 이미 한국어 뜻이면 같은 줄을 또 쓰지 않는다.
  String get _meaning {
    final meaning = kanji.displayMeaning.trim();
    return meaning == label ? '' : meaning;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = correct
        ? const Color(0xFFE5F6E8)
        : wrong
            ? const Color(0xFFFDE8EC)
            : (isDark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Colors.white);
    final border = correct
        ? const Color(0xFF43A047)
        : wrong
            ? const Color(0xFFE53935)
            : AppTheme.cardBorder;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: correct || wrong ? 2 : 1.5),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: correct || wrong || !isDark
                                ? const Color(0xFF5C3A45)
                                : null,
                          ),
                    ),
                    if (revealed && _reading.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _reading,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : const Color(0xFF5C3A45))
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    if (revealed && _meaning.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _meaning,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.meaningPink.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (correct || wrong)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    correct ? Icons.check_circle : Icons.cancel,
                    size: 20,
                    color: correct
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE53935),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 답 고른 뒤 나타나는 다음 버튼. 1.2초 동안 색이 차오르면 스스로 넘어간다.
class _NextGaugeButton extends StatefulWidget {
  const _NextGaugeButton({required this.label, required this.onAdvance});

  final String label;
  final VoidCallback onAdvance;

  @override
  State<_NextGaugeButton> createState() => _NextGaugeButtonState();
}

class _NextGaugeButtonState extends State<_NextGaugeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  bool _advanced = false;

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(_advance);
  }

  /// 게이지가 다 차거나 버튼을 누르면 한 번만 넘어간다.
  void _advance() {
    if (_advanced || !mounted) {
      return;
    }
    _advanced = true;
    _controller.stop();
    widget.onAdvance();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.progressPill,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _advance,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _controller.value,
                  heightFactor: 1,
                  child: const ColoredBox(color: AppTheme.meaningPink),
                ),
              ),
            ),
            Center(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Color(0xFF7A3048),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 세트 결과. 점수, 틀린 문제, 다시 풀기와 다음 세트.
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.l10n,
    required this.correct,
    required this.total,
    required this.wrongs,
    required this.nextSetCount,
    required this.onRetryWrong,
    required this.onNextSet,
  });

  final AppLocalizations l10n;
  final int correct;
  final int total;
  final List<QuizQuestion> wrongs;
  final int nextSetCount;
  final VoidCallback onRetryWrong;
  final VoidCallback onNextSet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Text(l10n.quizResult, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            l10n.quizCorrectLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            l10n.quizScore(correct, total),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppTheme.meaningPink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.quizWrongList,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: wrongs.isEmpty
                ? Center(child: Text(l10n.quizAllCorrect))
                : ListView.separated(
                    itemCount: wrongs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final kanji = wrongs[index].prompt;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.progressPill,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Text(
                              kanji.literal,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                kanji.displayMeaning,
                                style: const TextStyle(
                                  color: AppTheme.meaningPink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          if (wrongs.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.meaningPink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onRetryWrong,
                child: Text(
                  l10n.quizRetryWrong(wrongs.length),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (nextSetCount > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.meaningPink,
                  side: const BorderSide(color: AppTheme.meaningPink, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onNextSet,
                child: Text(
                  l10n.quizNextSet(nextSetCount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

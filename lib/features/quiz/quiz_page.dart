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

/// 목록을 고르면 카드가 2장 이상일 때 자동으로 [_begin]한다.
class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key});

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  QuizMode _mode = QuizMode.meaning;
  List<QuizQuestion> _questions = const [];
  int _index = 0;
  int? _picked;
  int _correctCount = 0;
  bool _playing = false;

  void _resetLocal() {
    _playing = false;
    _questions = const [];
    _picked = null;
    _index = 0;
    _correctCount = 0;
  }

  void _begin() {
    final catalog = ref.read(catalogControllerProvider).valueOrNull;
    if (catalog == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final session = ref.read(quizSessionProvider);
    final lists = catalog.dropdownLists(
      userTitle: l10n.listUser,
      favoritesTitle: l10n.favorites,
      kind: session.kind,
    );
    final listId = resolveListId(session.listId, lists);
    final questions = buildQuiz(
      items: catalog.itemsFor(listId, kind: session.kind),
      mode: _mode,
    );
    setState(() {
      _questions = questions;
      _index = 0;
      _picked = null;
      _correctCount = 0;
      _playing = questions.isNotEmpty;
    });
  }

  void _leaveQuiz() {
    setState(_resetLocal);
    ref.read(quizSessionProvider.notifier).clearList();
  }

  /// 보기 하나를 고른다. 이미 골랐으면 무시. 맞으면 [_correctCount]를 올린다.
  void _pick(int choice) {
    if (_picked != null) {
      return;
    }
    final question = _questions[_index];
    setState(() {
      _picked = choice;
      if (choice == question.correctIndex) {
        _correctCount += 1;
      }
    });
  }

  void _next() {
    if (_index >= _questions.length - 1) {
      setState(() => _playing = false);
      return;
    }
    setState(() {
      _index += 1;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(quizSessionProvider);
    final asyncCatalog = ref.watch(catalogControllerProvider);

    // 목록을 비우면 (뒤로가기) 로컬 퀴즈 상태도 리셋.
    ref.listen<StudySession>(quizSessionProvider, (prev, next) {
      if (next.hasDeck) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(_resetLocal);
      });
    });

    return PopScope(
      canPop: !session.hasKind,
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        if (session.hasDeck) {
          _leaveQuiz();
        } else if (session.hasKind) {
          ref.read(studySessionProvider.notifier).clearKind();
        }
      },
      child: Scaffold(
        appBar: session.hasDeck
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _leaveQuiz,
                ),
                title: Text(l10n.quizTitle),
              )
            : null,
        body: asyncCatalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (catalog) {
            if (!session.hasDeck) {
              return HomeBrowseBody(
                catalog: catalog,
                session: session,
                isDark: ref.watch(studyPrefsProvider).isDark,
                forQuiz: true,
              );
            }
            final lists = catalog.dropdownLists(
              userTitle: l10n.listUser,
              favoritesTitle: l10n.favorites,
              kind: session.kind,
            );
            final listId = resolveListId(session.listId, lists);
            final items = catalog.itemsFor(listId, kind: session.kind);
            if (!_playing && _questions.isEmpty && items.length >= 2) {
              // 목록을 고르자마자 퀴즈를 시작한다. 카드가 2장 미만이면 시작 화면.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _playing || _questions.isNotEmpty) {
                  return;
                }
                _begin();
              });
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<QuizMode>(
                    segments: [
                      ButtonSegment(
                        value: QuizMode.meaning,
                        label: Text(l10n.quizModeMeaning),
                      ),
                      ButtonSegment(
                        value: QuizMode.literal,
                        label: Text(l10n.quizModeLiteral),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (next) {
                      setState(() {
                        _mode = next.first;
                        _resetLocal();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: _body(context, l10n, items)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    List<Kanji> items,
  ) {
    if (_questions.isNotEmpty && !_playing) {
      //결과 화면
      return _ResultView(
        l10n: l10n,
        correct: _correctCount,
        total: _questions.length,
        onRetry: _begin,
      );
    }
    if (!_playing) {
      //퀴즈 시작 화면
      final canStart = items.length >= 2;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                canStart
                    ? (_mode == QuizMode.meaning
                        ? l10n.quizPickMeaning
                        : l10n.quizPickLiteral)
                    : l10n.quizEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canStart ? _begin : null,
                child: Text(l10n.quizStart),
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
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : AppTheme.creamCard,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.cardBorder, width: 2),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FittedBox(
                    child: _QuizPrompt(
                      kanji: question.prompt,
                      mode: question.mode,
                      l10n: l10n,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < question.choices.length; i++) ...[
            _ChoiceTile(
              label: question.choices[i],
              selected: _picked == i,
              correct: answered && i == question.correctIndex,
              wrong: answered && _picked == i && i != question.correctIndex,
              onTap: () => _pick(i),
            ),
            const SizedBox(height: 8),
          ],
          if (answered) ...[
            Text(
              _picked == question.correctIndex
                  ? l10n.quizCorrect
                  : l10n.quizWrong,
              style: TextStyle(
                color: _picked == question.correctIndex
                    ? const Color(0xFF2E7D32)
                    : AppTheme.meaningPink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _next,
              child: Text(
                _index >= _questions.length - 1
                    ? l10n.quizSeeResult
                    : l10n.quizNext,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 문제 칸. 뜻 고르기·글자 고르기 모두 훈독·음독(또는 단어 읽기)을 같이 보여 준다.
class _QuizPrompt extends StatelessWidget {
  const _QuizPrompt({
    required this.kanji,
    required this.mode,
    required this.l10n,
  });

  final Kanji kanji;
  final QuizMode mode;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final main =
        mode == QuizMode.meaning ? kanji.literal : kanji.displayMeaning;
    final readings = _readingLine();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          main,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: const Color(0xFF5C3A45),
                fontWeight: FontWeight.w500,
                fontSize: mode == QuizMode.meaning ? 72 : 36,
              ),
        ),
        if (readings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            readings,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF5C3A45),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
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
    return '${l10n.cardKun}: ${kun.isEmpty ? '—' : kun} / ${l10n.cardOn}: ${on.isEmpty ? '—' : on}';
  }
}

/// 객관식 보기. 채점 후 정답은 초록, 오답은 분홍.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color? color;
    if (correct) {
      color = const Color(0xFFC8E6C9);
    } else if (wrong) {
      color = const Color(0xFFFFCDD2);
    } else if (selected) {
      color = AppTheme.progressPill;
    }
    return Material(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 마지막 문항 다음. 점수와 다시 풀기.
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.l10n,
    required this.correct,
    required this.total,
    required this.onRetry,
  });

  final AppLocalizations l10n;
  final int correct;
  final int total;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.quizResult, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            l10n.quizScore(correct, total),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppTheme.meaningPink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetry,
            child: Text(l10n.quizRetry),
          ),
        ],
      ),
    );
  }
}

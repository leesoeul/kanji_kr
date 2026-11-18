import 'dart:math';

import '../../shared/models/kanji.dart';

/// 뜻 맞히기 / 글자 맞히기.
enum QuizMode { meaning, literal }

/// 한 문항의 보기 수. 목록에 이만큼 카드가 있어야 퀴즈를 낼 수 있다.
const int kQuizChoiceCount = 4;

/// 한 세트에 내는 문제 수. 목록이 더 길면 이어서 다음 세트로 나눈다.
const int kQuizSetSize = 20;

/// 객관식 한 문항. 보기는 항상 정답 1 + 오답 3.
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.choices,
    required this.choiceKanji,
    required this.correctIndex,
    required this.mode,
  });

  final Kanji prompt;
  final List<String> choices;

  /// [choices]와 같은 순서의 원본 카드. 답을 고른 뒤 읽기와 뜻을 보여 줄 때 쓴다.
  final List<Kanji> choiceKanji;
  final int correctIndex;
  final QuizMode mode;

  String get correctChoice => choices[correctIndex];
}

/// 선택한 목록의 카드를 섞어 복습 퀴즈를 만든다.
///
/// [items]는 오답 보기를 뽑는 전체 목록이다. [prompts]가 있으면 그 카드만 문제로 낸다.
/// 틀린 문제만 다시 풀 때 쓴다. 목록이 [kQuizChoiceCount]장 미만이면 빈 배열.
/// 뜻이 겹쳐서 서로 다른 오답 3개를 못 채우면 그 문항은 건너뛴다.
List<QuizQuestion> buildQuiz({
  required List<Kanji> items,
  List<Kanji>? prompts,
  required QuizMode mode,
  Random? random,
}) {
  final rng = random ?? Random();
  if (items.length < kQuizChoiceCount) {
    return const [];
  }
  final shuffled = [...(prompts ?? items)]..shuffle(rng);
  final questions = <QuizQuestion>[];
  for (final item in shuffled) {
    final correct = _label(item, mode);
    if (correct.isEmpty) {
      continue;
    }
    final distractors = <Kanji>[];
    final seen = <String>{correct};
    final pool = [...items]..shuffle(rng);
    for (final other in pool) {
      if (other.id == item.id) {
        continue;
      }
      final value = _label(other, mode);
      if (value.isEmpty || seen.contains(value)) {
        continue;
      }
      seen.add(value);
      distractors.add(other);
      if (distractors.length >= kQuizChoiceCount - 1) {
        break;
      }
    }
    if (distractors.length < kQuizChoiceCount - 1) {
      continue;
    }
    final options = [item, ...distractors]..shuffle(rng);
    questions.add(
      QuizQuestion(
        prompt: item,
        choices: [for (final option in options) _label(option, mode)],
        choiceKanji: options,
        correctIndex: options.indexOf(item),
        mode: mode,
      ),
    );
  }
  return questions;
}

/// 모드에 따라 보기 문자열. 뜻 맞히기는 displayMeaning, 글자 맞히기는 literal.
String _label(Kanji item, QuizMode mode) {
  switch (mode) {
    case QuizMode.meaning:
      return item.displayMeaning.trim();
    case QuizMode.literal:
      return item.literal.trim();
  }
}

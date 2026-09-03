import 'dart:math';

import '../../shared/models/kanji.dart';

/// 뜻 맞히기 / 글자 맞히기.
enum QuizMode { meaning, literal }

/// 객관식 한 문항. 보기 수는 정답 1 + 오답 최대 3 (2–4).
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.mode,
  });

  final Kanji prompt;
  final List<String> choices;
  final int correctIndex;
  final QuizMode mode;

  String get correctChoice => choices[correctIndex];
}

/// 선택한 목록의 카드를 섞어 복습 퀴즈를 만든다.
///
/// 카드가 2장 미만이면 빈 배열. 오답 보기가 하나도 안 나오면 그 문항은 건너뛴다.
List<QuizQuestion> buildQuiz({
  required List<Kanji> items,
  required QuizMode mode,
  Random? random,
}) {
  final rng = random ?? Random();
  if (items.length < 2) {
    return const [];
  }
  final shuffled = [...items]..shuffle(rng);
  final questions = <QuizQuestion>[];
  for (final item in shuffled) {
    final correct = _label(item, mode);
    if (correct.isEmpty) {
      continue;
    }
    final distractors = <String>{};
    final pool = [...items]..shuffle(rng);
    for (final other in pool) {
      if (other.id == item.id) {
        continue;
      }
      final value = _label(other, mode);
      if (value.isEmpty || value == correct) {
        continue;
      }
      distractors.add(value);
      if (distractors.length >= 3) {
        break;
      }
    }
    if (distractors.isEmpty) {
      continue;
    }
    final choices = [correct, ...distractors]..shuffle(rng);
    questions.add(
      QuizQuestion(
        prompt: item,
        choices: choices,
        correctIndex: choices.indexOf(correct),
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

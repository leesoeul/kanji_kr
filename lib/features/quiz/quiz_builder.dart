import 'dart:math';

import '../../shared/models/kanji.dart';

enum QuizMode { meaning, literal }

/// 객관식 한 문항. 보기 수는 2–4.
/// 選択式の1問。選択肢は 2–4。
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
/// 選んだ一覧のカードを混ぜて復習クイズを作る。
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

String _label(Kanji item, QuizMode mode) {
  switch (mode) {
    case QuizMode.meaning:
      return item.displayMeaning.trim();
    case QuizMode.literal:
      return item.literal.trim();
  }
}

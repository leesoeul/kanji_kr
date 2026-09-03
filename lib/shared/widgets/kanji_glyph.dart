import 'package:flutter/material.dart';

/// 큰 한자(또는 단어) 글리프.
/// 학습 카드는 지금은 Text를 직접 쓰고, 이 위젯은 목록 leading 등에 쓸 수 있다.
class KanjiGlyph extends StatelessWidget {
  const KanjiGlyph({
    super.key,
    required this.literal,
    this.size = 96,
  });

  final String literal;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      literal,
      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: size),
      textAlign: TextAlign.center,
    );
  }
}

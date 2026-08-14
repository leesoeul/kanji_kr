import 'package:flutter/material.dart';

/// 큰 한자 글리프. 학습 카드와 목록 leading에서 쓴다.
/// 大きな漢字グリフ。学習カードと一覧 leading で使う。
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

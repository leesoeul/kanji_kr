import 'package:flutter/material.dart';

/// JLPT / 내 한자 칩.
/// JLPT / 自分の漢字チップ。
class LevelChip extends StatelessWidget {
  const LevelChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

/// 시드면 JLPT, 사용자 한자면 "내 한자" 라벨.
/// シードなら JLPT、ユーザー漢字なら「내 한자」ラベル。
String kanjiLevelLabel({
  required bool isUserAdded,
  required String jlpt,
  required String userLabel,
  required String Function(String level) jlptLabel,
}) {
  return isUserAdded ? userLabel : jlptLabel(jlpt);
}

import 'package:flutter/material.dart';

/// JLPT / 내 한자 칩. 목록 화면에 붙일 수 있지만 지금은 거의 안 쓴다.
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

/// 시드면 JLPT 라벨, 사용자 카드면 "내 한자".
String kanjiLevelLabel({
  required bool isUserAdded,
  required String jlpt,
  required String userLabel,
  required String Function(String level) jlptLabel,
}) {
  return isUserAdded ? userLabel : jlptLabel(jlpt);
}

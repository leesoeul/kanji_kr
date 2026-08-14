/// JLPT 레벨 표시용. 시드 기본값은 N5.
/// JLPTレベル表示用。シード既定値は N5。
enum JlptLevel {
  n5('N5'),
  n4('N4'),
  n3('N3'),
  n2('N2'),
  n1('N1');

  const JlptLevel(this.label);
  final String label;

  static JlptLevel fromLabel(String label) {
    return JlptLevel.values.firstWhere(
      (level) => level.label == label,
      orElse: () => JlptLevel.n5,
    );
  }
}

/// JLPT 레벨 표시용 enum.
///
/// 시드 한자는 N5~N1 또는 ADV 같은 문자열을 쓰고,
/// 파싱에 실패하면 N5로 떨어진다. 설정 화면 표시에만 쓰인다.
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

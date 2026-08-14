/// 음독 시드는 가타카나인데, 학습 UI는 히라가나로 보여 준다.
/// 音読みシードはカタカナだが、学習UIはひらがなで見せる。
String katakanaToHiragana(String input) {
  final buffer = StringBuffer();
  for (final code in input.runes) {
    // 가타카나 ァ–ヶ 를 히라가나 ぁ–ヶ 로 옮긴다 (U+60).
    // カタカナ ァ–ヶ をひらがな ぁ–ヶ へ移す (U+60)。
    if (code >= 0x30A1 && code <= 0x30F6) {
      buffer.writeCharCode(code - 0x60);
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}

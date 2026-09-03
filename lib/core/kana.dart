/// 음독 시드는 가타카나(サン)로 들어 오지만, 학습 화면은 히라가나(さん)로 보여 준다.
///
/// 유니코드에서 가타카나 ァ(U+30A1)–ヶ(U+30F6)는
/// 히라가나 ぁ(U+3041)보다 0x60 크다. 그 구간만 빼고 그대로 둔다.
String katakanaToHiragana(String input) {
  final buffer = StringBuffer();
  for (final code in input.runes) {
    if (code >= 0x30A1 && code <= 0x30F6) {
      buffer.writeCharCode(code - 0x60);
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}

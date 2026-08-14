import 'dart:convert';
import 'dart:io';

import 'package:kanji_kr/core/kana.dart';
import 'package:kanji_kr/core/storage/user_data.dart';
import 'package:kanji_kr/shared/models/kanji.dart';
import 'package:test/test.dart';

/// 시드 JSON 파싱·검색·사용자 데이터 직렬화.
/// シードJSONパース・検索・ユーザーデータ直列化。
void main() {
  test('N5 시드에 山이 있다', () {
    final raw = File('assets/data/kanji/n5.json').readAsStringSync();
    final list = jsonDecode(raw) as List<dynamic>;
    expect(list, hasLength(20));
    final kanji = Kanji.fromJson(list.first as Map<String, dynamic>);
    expect(kanji.literal, '山');
    expect(kanji.id, 'yama');
    expect(kanji.jlpt, 'N5');
    expect(kanji.strokeCount, 3);
    expect(kanji.meaningsKo, contains('산'));
    expect(kanji.isUserAdded, isFalse);
    expect(kanji.matchesQuery('山'), isTrue);
    expect(kanji.matchesQuery('산'), isTrue);
    expect(kanji.matchesQuery('やま'), isTrue);
    expect(kanji.matchesQuery('さん'), isTrue);
    expect(kanji.matchesQuery('水'), isFalse);
  });

  test('사용자 한자와 즐겨찾기를 JSON으로 저장할 수 있다', () {
    final kanji = Kanji(
      id: Kanji.userIdFor('川'),
      literal: '川',
      jlpt: 'USER',
      strokeCount: 0,
      koreanHanja: '川',
      koreanMeaning: '내 천',
      meaningsKo: const ['강'],
      onYomi: const [],
      kunYomi: const [],
      examples: const [],
      isUserAdded: true,
    );
    final data = UserData(
      favoriteIds: {kanji.id, 'yama'},
      userKanjis: [kanji],
    );
    final restored = UserData.fromJson(data.toJson());
    expect(restored.favoriteIds, containsAll(['user_川', 'yama']));
    expect(restored.userKanjis.single.literal, '川');
    expect(restored.userKanjis.single.isUserAdded, isTrue);
    expect(restored.alwaysShowAnswer, isFalse);
  });

  test('음독 가타카나를 히라가나로 바꾼다', () {
    expect(katakanaToHiragana('サン'), 'さん');
    expect(katakanaToHiragana('ニチ'), 'にち');
    expect(katakanaToHiragana('やま'), 'やま');
  });
}

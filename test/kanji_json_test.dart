import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:kanji_kr/core/import/list_import.dart';
import 'package:kanji_kr/core/kana.dart';
import 'package:kanji_kr/core/storage/user_data.dart';
import 'package:kanji_kr/core/study_filter.dart';
import 'package:kanji_kr/features/quiz/quiz_builder.dart';
import 'package:kanji_kr/shared/models/kanji.dart';
import 'package:kanji_kr/shared/models/study_list.dart';
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
    expect(kanji.kind, EntryKind.kanji);
    expect(kanji.matchesQuery('山'), isTrue);
    expect(kanji.matchesQuery('산'), isTrue);
    expect(kanji.matchesQuery('やま'), isTrue);
    expect(kanji.matchesQuery('さん'), isTrue);
    expect(kanji.matchesQuery('水'), isFalse);
  });

  test('한자 뜻은 훈음으로 보여 준다', () {
    expect(
      Kanji.fromJson({
        'literal': '苦',
        'koreanMeaning': '쓸 고/괴로울 고',
      }).displayMeaning,
      '쓸 고 · 괴로울 고',
    );
    expect(
      Kanji.fromJson({
        'literal': '並',
        'koreanMeaning': '나란할 병',
      }).displayMeaning,
      '나란할 병',
    );
  });

  test('N5 단어 시드에 山登り가 있다', () {
    final raw = File('assets/data/word/n5.json').readAsStringSync();
    final list = jsonDecode(raw) as List<dynamic>;
    expect(list, hasLength(18));
    final word = Kanji.fromJson(list.first as Map<String, dynamic>);
    expect(word.literal, '山登り');
    expect(word.kind, EntryKind.word);
    expect(word.listId, 'n5_word');
    expect(word.reading, 'やまのぼり');
    expect(word.displayMeaning, '등산');
    expect(word.matchesQuery('やまのぼり'), isTrue);
    expect(word.matchesQuery('등산'), isTrue);
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
      listId: ListIds.user,
      isUserAdded: true,
    );
    final data = UserData(
      favoriteIds: {kanji.id, 'yama'},
      userKanjis: [kanji],
      selectedListId: 'n5_word',
    );
    final restored = UserData.fromJson(data.toJson());
    expect(restored.favoriteIds, containsAll(['user_川', 'yama']));
    expect(restored.userKanjis.single.literal, '川');
    expect(restored.userKanjis.single.isUserAdded, isTrue);
    expect(restored.userKanjis.single.listId, ListIds.user);
    expect(restored.alwaysShowAnswer, isFalse);
    expect(restored.selectedListId, 'n5_word');
  });

  test('음독 가타카나를 히라가나로 바꾼다', () {
    expect(katakanaToHiragana('サン'), 'さん');
    expect(katakanaToHiragana('ニチ'), 'にち');
    expect(katakanaToHiragana('やま'), 'やま');
  });

  test('목록 필터가 한자·단어·즐겨찾기를 나눈다', () {
    final yama = Kanji.fromJson({
      'id': 'yama',
      'literal': '山',
      'listId': 'n5_kanji',
      'meaningsKo': ['산'],
    });
    final word = Kanji.fromJson({
      'id': 'sensei',
      'kind': 'word',
      'listId': 'n5_word',
      'literal': '先生',
      'reading': 'せんせい',
      'meaningsKo': ['선생님'],
    });
    final mine = Kanji.fromJson({
      'id': 'user_猫',
      'kind': 'word',
      'listId': ListIds.user,
      'literal': '猫',
      'reading': 'ねこ',
      'meaningsKo': ['고양이'],
      'isUserAdded': true,
    });
    final all = [yama, word, mine];
    expect(
      itemsForList(all: all, favoriteIds: {'yama'}, listId: 'n5_kanji')
          .map((item) => item.id),
      ['yama'],
    );
    expect(
      itemsForList(all: all, favoriteIds: {'yama'}, listId: 'n5_word')
          .single
          .literal,
      '先生',
    );
    expect(
      itemsForList(all: all, favoriteIds: {'yama'}, listId: ListIds.favorites)
          .single
          .id,
      'yama',
    );
    expect(
      itemsForList(all: all, favoriteIds: {}, listId: ListIds.user)
          .single
          .literal,
      '猫',
    );
    expect(
      itemsForList(
        all: all,
        favoriteIds: {},
        listId: ListIds.all,
        kind: EntryKind.kanji,
      ).map((item) => item.id),
      ['yama'],
    );
    expect(
      itemsForList(all: all, favoriteIds: {}, listId: ''),
      isEmpty,
    );
  });

  test('한자 종류 목록에는 전체가 없고 초급 한자가 있다', () {
    final lists = composeListsForKind(
      kind: EntryKind.kanji,
      userTitle: '내가 추가',
      favoritesTitle: '즐겨찾기',
      builtin: const [
        StudyList(
          id: 'kanji_beg',
          kind: EntryKind.kanji,
          titleKo: '초급 한자',
          titleJa: '初級漢字',
        ),
        StudyList(
          id: 'verb_beg',
          kind: EntryKind.word,
          titleKo: '초급 동사',
          titleJa: '初級動詞',
        ),
      ],
      imported: const [],
    );
    expect(lists.map((item) => item.id), isNot(contains(ListIds.all)));
    expect(lists.map((item) => item.id), contains('kanji_beg'));
    expect(lists.map((item) => item.id), isNot(contains('verb_beg')));
  });

  test('JSON 배열을 가져와 새 목록으로 만든다', () {
    final parsed = parseImportJson(
      jsonEncode([
        {
          'literal': '切符',
          'kind': 'word',
          'reading': 'きっぷ',
          'meaningsKo': ['표'],
        },
      ]),
      nowMs: 123,
    );
    expect(parsed.list.id, 'import_123');
    expect(parsed.list.kind, EntryKind.word);
    expect(parsed.items.single.literal, '切符');
    expect(parsed.items.single.isUserAdded, isTrue);
    expect(parsed.items.single.listId, 'import_123');
  });

  test('퀴즈는 정답이 보기 안에 있다', () {
    final items = [
      Kanji.fromJson({
        'id': 'a',
        'literal': '山',
        'meaningsKo': ['산'],
      }),
      Kanji.fromJson({
        'id': 'b',
        'literal': '川',
        'meaningsKo': ['강'],
      }),
      Kanji.fromJson({
        'id': 'c',
        'literal': '人',
        'meaningsKo': ['사람'],
      }),
    ];
    final questions = buildQuiz(
      items: items,
      mode: QuizMode.meaning,
      random: Random(1),
    );
    expect(questions, isNotEmpty);
    for (final question in questions) {
      expect(question.choices, contains(question.prompt.displayMeaning));
      expect(
        question.choices[question.correctIndex],
        question.prompt.displayMeaning,
      );
    }
  });
}

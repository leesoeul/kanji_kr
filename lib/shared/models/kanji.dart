import '../../core/kana.dart';
import 'reading.dart';
import 'study_list.dart';

/// 예문 한 쌍 (일본어 / 가나 / 한국어).
/// 추가·수정 폼에서는 지금은 1개만 다룬다.
class KanjiExample {
  const KanjiExample({
    required this.jp,
    required this.kana,
    required this.ko,
  });

  final String jp;
  final String kana;
  final String ko;

  factory KanjiExample.fromJson(Map<String, dynamic> json) {
    return KanjiExample(
      jp: json['jp'] as String? ?? '',
      kana: json['kana'] as String? ?? '',
      ko: json['ko'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'jp': jp,
        'kana': kana,
        'ko': ko,
      };
}

/// 학습 카드 한 장.
///
/// 한자·단어, 시드와 사용자 추가가 같은 모델을 쓴다.
/// [kind]로 한자/단어를 가른다. 클래스 이름은 한자이지만 동사 JSON도 이 타입이다.
class Kanji {
  const Kanji({
    required this.id,
    required this.literal,
    required this.jlpt,
    required this.strokeCount,
    required this.koreanMeaning,
    required this.meaningsKo,
    required this.onYomi,
    required this.kunYomi,
    required this.examples,
    this.kind = EntryKind.kanji,
    this.listId = '',
    this.reading = '',
    this.isUserAdded = false,
  });

  final String id;

  /// 화면에 크게 보여 주는 글자. 한자면 `山`, 단어면 `食べる`.
  final String literal;
  final String jlpt;
  final int strokeCount;

  /// 훈음 표기 (예: 메 산). 카드 부제·정답에도 쓴다.
  final String koreanMeaning;

  /// 학습에 보여주는 짧은 뜻 (예: 산). 단어는 여기가 주 뜻.
  final List<String> meaningsKo;
  final List<Reading> onYomi;
  final List<Reading> kunYomi;
  final List<KanjiExample> examples;
  final EntryKind kind;

  /// 소속 목록. 시드는 `kanji_beg` 등, 직접 추가는 `user`.
  final String listId;

  /// 단어 전체 읽기. 한자면 비우고 훈/음독을 쓴다.
  final String reading;

  final bool isUserAdded;

  bool get isWord => kind == EntryKind.word;

  /// 한자는 훈음(나란할 병). `/`는 ` · `로 바꾼다. 단어는 짧은 뜻.
  String get displayMeaning {
    if (!isWord) {
      final hunEum = koreanMeaning.trim();
      if (hunEum.isNotEmpty) {
        return hunEum.replaceAll('/', ' · ');
      }
    }
    if (meaningsKo.isNotEmpty) {
      return meaningsKo.join(', ');
    }
    return koreanMeaning;
  }

  /// 목록 부제용. 한자는 훈독·음독, 단어는 읽기.
  String get displayKunOn {
    if (isWord) {
      return displayReading;
    }
    final kun = kunYomi.map((item) => item.kana).join('・');
    final on = onYomi.map((item) => katakanaToHiragana(item.kana)).join('・');
    if (kun.isEmpty && on.isEmpty) {
      return '';
    }
    if (kun.isEmpty) {
      return on;
    }
    if (on.isEmpty) {
      return kun;
    }
    return '$kun / $on';
  }

  /// 단어는 [reading], 없으면 훈독. 한자는 빈 문자열 (훈/음독은 [displayKunOn]).
  String get displayReading {
    if (reading.isNotEmpty) {
      return reading;
    }
    if (isWord) {
      return kunYomi.map((item) => item.kana).join('・');
    }
    return '';
  }

  /// 사용자 추가 카드의 안정 id. 같은 글자를 두 번 넣지 못하게 하는 키로도 쓴다.
  static String userIdFor(String literal, {EntryKind kind = EntryKind.kanji}) {
    final prefix = kind == EntryKind.word ? 'user_word_' : 'user_';
    return '$prefix$literal';
  }

  factory Kanji.fromJson(Map<String, dynamic> json) {
    List<Reading> readings(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw
          .map((item) => Reading.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final literal = json['literal'] as String? ?? '';
    final kind = EntryKind.fromName(json['kind'] as String?);
    final id = json['id'] as String? ?? userIdFor(literal, kind: kind);

    return Kanji(
      id: id,
      literal: literal,
      jlpt: json['jlpt'] as String? ?? 'USER',
      strokeCount: json['strokeCount'] as int? ?? 0,
      koreanMeaning: json['koreanMeaning'] as String? ?? '',
      meaningsKo: (json['meaningsKo'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      onYomi: readings('onYomi'),
      kunYomi: readings('kunYomi'),
      examples: (json['examples'] as List<dynamic>? ?? const [])
          .map((item) => KanjiExample.fromJson(item as Map<String, dynamic>))
          .toList(),
      kind: kind,
      listId: json['listId'] as String? ?? '',
      reading: json['reading'] as String? ?? '',
      isUserAdded: json['isUserAdded'] as bool? ?? false,
    );
  }

  /// 검색: 글자·id·훈음·뜻·읽기. 음독은 가타카나 시드를 히라가나로도 맞춘다.
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }
    if (literal.contains(query.trim()) || id.toLowerCase().contains(q)) {
      return true;
    }
    if (koreanMeaning.toLowerCase().contains(q)) {
      return true;
    }
    if (meaningsKo.any((item) => item.toLowerCase().contains(q))) {
      return true;
    }
    if (reading.contains(query.trim()) || reading.toLowerCase().contains(q)) {
      return true;
    }
    return onYomi.any((item) {
          final hira = katakanaToHiragana(item.kana);
          return item.kana.contains(query.trim()) || hira.contains(q);
        }) ||
        kunYomi.any((item) => item.kana.contains(query.trim()));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'literal': literal,
        'jlpt': jlpt,
        'strokeCount': strokeCount,
        'koreanMeaning': koreanMeaning,
        'meaningsKo': meaningsKo,
        'onYomi': onYomi.map((item) => item.toJson()).toList(),
        'kunYomi': kunYomi.map((item) => item.toJson()).toList(),
        'examples': examples.map((item) => item.toJson()).toList(),
        'kind': kind.jsonName,
        'listId': listId,
        'reading': reading,
        'isUserAdded': isUserAdded,
      };

  Kanji copyWith({
    String? id,
    String? literal,
    String? jlpt,
    int? strokeCount,
    String? koreanMeaning,
    List<String>? meaningsKo,
    List<Reading>? onYomi,
    List<Reading>? kunYomi,
    List<KanjiExample>? examples,
    EntryKind? kind,
    String? listId,
    String? reading,
    bool? isUserAdded,
  }) {
    return Kanji(
      id: id ?? this.id,
      literal: literal ?? this.literal,
      jlpt: jlpt ?? this.jlpt,
      strokeCount: strokeCount ?? this.strokeCount,
      koreanMeaning: koreanMeaning ?? this.koreanMeaning,
      meaningsKo: meaningsKo ?? this.meaningsKo,
      onYomi: onYomi ?? this.onYomi,
      kunYomi: kunYomi ?? this.kunYomi,
      examples: examples ?? this.examples,
      kind: kind ?? this.kind,
      listId: listId ?? this.listId,
      reading: reading ?? this.reading,
      isUserAdded: isUserAdded ?? this.isUserAdded,
    );
  }
}

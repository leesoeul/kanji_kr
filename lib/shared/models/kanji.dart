import '../../core/kana.dart';
import 'reading.dart';

/// 예문 한 쌍. 폼에서는 지금은 1개만 다룬다.
/// 例文の1組。フォームでは今は1件だけ扱う。
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

/// 학습 카드 한 장. 시드와 사용자 추가가 같은 모델을 쓴다.
/// 学習カード1枚。シードとユーザー追加が同じモデルを使う。
class Kanji {
  const Kanji({
    required this.id,
    required this.literal,
    required this.jlpt,
    required this.strokeCount,
    required this.koreanHanja,
    required this.koreanMeaning,
    required this.meaningsKo,
    required this.onYomi,
    required this.kunYomi,
    required this.examples,
    this.isUserAdded = false,
  });

  final String id;
  final String literal;
  final String jlpt;
  final int strokeCount;
  final String koreanHanja;
  /// 훈음 표기 (예: 메 산). 카드 부제에도 쓴다.
  /// 訓音表記 (例: 메 산)。カード副題にも使う。
  final String koreanMeaning;
  /// 학습에 보여주는 짧은 뜻 (예: 산).
  /// 学習で見せる短い意味 (例: 산)。
  final List<String> meaningsKo;
  final List<Reading> onYomi;
  final List<Reading> kunYomi;
  final List<KanjiExample> examples;
  final bool isUserAdded;

  /// 사용자 추가 한자의 안정 id. 같은 글자를 두 번 넣지 못하게 하는 키로도 쓴다.
  /// ユーザー追加漢字の安定 id。同じ字を二度入れないキーにも使う。
  static String userIdFor(String literal) => 'user_$literal';

  factory Kanji.fromJson(Map<String, dynamic> json) {
    List<Reading> readings(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw
          .map((item) => Reading.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return Kanji(
      id: json['id'] as String,
      literal: json['literal'] as String,
      jlpt: json['jlpt'] as String? ?? 'USER',
      strokeCount: json['strokeCount'] as int? ?? 0,
      koreanHanja: json['koreanHanja'] as String? ?? json['literal'] as String,
      koreanMeaning: json['koreanMeaning'] as String? ?? '',
      meaningsKo: (json['meaningsKo'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      onYomi: readings('onYomi'),
      kunYomi: readings('kunYomi'),
      examples: (json['examples'] as List<dynamic>? ?? const [])
          .map((item) => KanjiExample.fromJson(item as Map<String, dynamic>))
          .toList(),
      isUserAdded: json['isUserAdded'] as bool? ?? false,
    );
  }

  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }
    if (literal.contains(query.trim()) || id.toLowerCase().contains(q)) {
      return true;
    }
    if (koreanMeaning.toLowerCase().contains(q) ||
        koreanHanja.contains(query.trim())) {
      return true;
    }
    if (meaningsKo.any((item) => item.toLowerCase().contains(q))) {
      return true;
    }
    // 음독은 시드가 가타카나라, 히라가나 검색도 맞춘다.
    // 音読みはシードがカタカナなので、ひらがな検索も合わせる。
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
        'koreanHanja': koreanHanja,
        'koreanMeaning': koreanMeaning,
        'meaningsKo': meaningsKo,
        'onYomi': onYomi.map((item) => item.toJson()).toList(),
        'kunYomi': kunYomi.map((item) => item.toJson()).toList(),
        'examples': examples.map((item) => item.toJson()).toList(),
        'isUserAdded': isUserAdded,
      };

  Kanji copyWith({
    String? id,
    String? literal,
    String? jlpt,
    int? strokeCount,
    String? koreanHanja,
    String? koreanMeaning,
    List<String>? meaningsKo,
    List<Reading>? onYomi,
    List<Reading>? kunYomi,
    List<KanjiExample>? examples,
    bool? isUserAdded,
  }) {
    return Kanji(
      id: id ?? this.id,
      literal: literal ?? this.literal,
      jlpt: jlpt ?? this.jlpt,
      strokeCount: strokeCount ?? this.strokeCount,
      koreanHanja: koreanHanja ?? this.koreanHanja,
      koreanMeaning: koreanMeaning ?? this.koreanMeaning,
      meaningsKo: meaningsKo ?? this.meaningsKo,
      onYomi: onYomi ?? this.onYomi,
      kunYomi: kunYomi ?? this.kunYomi,
      examples: examples ?? this.examples,
      isUserAdded: isUserAdded ?? this.isUserAdded,
    );
  }
}

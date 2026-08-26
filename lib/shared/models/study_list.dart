/// 카드 종류. 한자 한 글자와 단어(熟語)를 같은 카탈로그에 둔다.
/// カード種類。漢字1字と単語(熟語)を同じカタログに置く。
enum EntryKind {
  kanji,
  word,
  mixed;

  static EntryKind fromName(String? raw) {
    switch (raw) {
      case 'word':
        return EntryKind.word;
      case 'mixed':
        return EntryKind.mixed;
      default:
        return EntryKind.kanji;
    }
  }

  String get jsonName {
    switch (this) {
      case EntryKind.kanji:
        return 'kanji';
      case EntryKind.word:
        return 'word';
      case EntryKind.mixed:
        return 'mixed';
    }
  }
}

/// 가상 목록 id. 에셋 JSON이 아니라 필터로 만든다.
/// 仮想一覧 id。アセットJSONではなくフィルタで作る。
class ListIds {
  static const all = 'all';
  static const favorites = 'favorites';
  static const user = 'user';
}

/// 학습 목록 한 줄. 시드·가져오기·가상 필터가 같은 모델을 쓴다.
/// 学習一覧の1行。シード・インポート・仮想フィルタが同じモデルを使う。
class StudyList {
  const StudyList({
    required this.id,
    required this.kind,
    required this.titleKo,
    required this.titleJa,
    this.asset,
    this.isVirtual = false,
    this.isImported = false,
  });

  final String id;
  final EntryKind kind;
  final String titleKo;
  final String titleJa;

  /// 번들 JSON 경로. 가상·가져오기 목록은 null.
  /// バンドルJSONパス。仮想・インポート一覧は null。
  final String? asset;
  final bool isVirtual;
  final bool isImported;

  String titleFor(String languageCode) {
    return languageCode == 'ja' ? titleJa : titleKo;
  }

  factory StudyList.fromJson(Map<String, dynamic> json) {
    return StudyList(
      id: json['id'] as String,
      kind: EntryKind.fromName(json['kind'] as String?),
      titleKo: json['titleKo'] as String? ?? json['id'] as String,
      titleJa: json['titleJa'] as String? ?? json['titleKo'] as String? ?? '',
      asset: json['asset'] as String?,
      isVirtual: json['isVirtual'] as bool? ?? false,
      isImported: json['isImported'] as bool? ?? json['id']?.toString().startsWith('import_') == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.jsonName,
        'titleKo': titleKo,
        'titleJa': titleJa,
        'isImported': isImported,
      };

  StudyList copyWith({
    String? id,
    EntryKind? kind,
    String? titleKo,
    String? titleJa,
    String? asset,
    bool? isVirtual,
    bool? isImported,
  }) {
    return StudyList(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      titleKo: titleKo ?? this.titleKo,
      titleJa: titleJa ?? this.titleJa,
      asset: asset ?? this.asset,
      isVirtual: isVirtual ?? this.isVirtual,
      isImported: isImported ?? this.isImported,
    );
  }
}

import '../../shared/models/kanji.dart';
import '../../shared/models/study_list.dart';

/// 시드 JSON을 고칠 때마다 올린다.
///
/// 이 값보다 낮은 로컬 저장본은 시드를 고친 사본을 버리고,
/// 다음에 켤 때 번들 시드를 다시 쓴다. 직접 추가한 카드는 남긴다.
const int kSeedRevision = 2;

/// 기기에 남는 사용자 상태. 시드 JSON과는 별개다.
///
/// [userKanjis]에는 직접 추가한 카드뿐 아니라, 시드를 고친 사본도 들어간다.
class UserData {
  const UserData({
    required this.favoriteIds,
    required this.userKanjis,
    this.alwaysShowAnswer = false,
    this.isDark = false,
    this.selectedListId = '',
    this.selectedKind = '',
    this.userDecks = const [],
    this.userListTitle = '',
    this.userListHidden = false,
    this.seedRevision = kSeedRevision,
  });

  final Set<String> favoriteIds;

  /// 직접 추가한 카드 + 시드를 고친 사본.
  final List<Kanji> userKanjis;

  /// 정답 버튼을 더블탭하면 켜진다. 모든 카드에 답을 항상 보여 준다.
  final bool alwaysShowAnswer;
  final bool isDark;

  /// 홈에서 마지막에 고른 목록 id. 비어 있으면 목록 고르기 화면.
  final String selectedListId;

  /// `kanji` 또는 `word`. 비어 있으면 한자/동사 고르기 화면.
  final String selectedKind;

  /// 사용자가 만든 목록. 시드와 즐겨찾기는 여기 없다.
  final List<UserDeck> userDecks;

  /// 내가 추가의 바꾼 이름. 비어 있으면 기본 문구를 쓴다.
  final String userListTitle;

  /// 내가 추가를 지운 상태. 단어를 다시 넣으면 목록이 돌아온다.
  final bool userListHidden;

  /// 이 기기에 마지막으로 적용한 시드 개정. 없으면 0으로 본다.
  final int seedRevision;

  factory UserData.empty() => const UserData(
        favoriteIds: {},
        userKanjis: [],
      );

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      favoriteIds: {
        for (final id in json['favoriteIds'] as List<dynamic>? ?? const [])
          id as String,
      },
      userKanjis: [
        for (final item in json['userKanjis'] as List<dynamic>? ?? const [])
          Kanji.fromJson(item as Map<String, dynamic>),
      ],
      alwaysShowAnswer: json['alwaysShowAnswer'] as bool? ?? false,
      isDark: json['isDark'] as bool? ?? false,
      selectedListId: _normalizeListId(json['selectedListId'] as String?),
      selectedKind: json['selectedKind'] as String? ?? '',
      userDecks: [
        for (final item in json['userDecks'] as List<dynamic>? ?? const [])
          UserDeck.fromJson(item as Map<String, dynamic>),
      ],
      userListTitle: json['userListTitle'] as String? ?? '',
      userListHidden: json['userListHidden'] as bool? ?? false,
      seedRevision: json['seedRevision'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'favoriteIds': favoriteIds.toList(),
        'userKanjis': userKanjis.map((item) => item.toJson()).toList(),
        'alwaysShowAnswer': alwaysShowAnswer,
        'isDark': isDark,
        'selectedListId': selectedListId,
        'selectedKind': selectedKind,
        'userDecks': userDecks.map((item) => item.toJson()).toList(),
        'userListTitle': userListTitle,
        'userListHidden': userListHidden,
        'seedRevision': seedRevision,
      };

  UserData copyWith({
    Set<String>? favoriteIds,
    List<Kanji>? userKanjis,
    bool? alwaysShowAnswer,
    bool? isDark,
    String? selectedListId,
    String? selectedKind,
    List<UserDeck>? userDecks,
    String? userListTitle,
    bool? userListHidden,
    int? seedRevision,
  }) {
    return UserData(
      favoriteIds: favoriteIds ?? this.favoriteIds,
      userKanjis: userKanjis ?? this.userKanjis,
      alwaysShowAnswer: alwaysShowAnswer ?? this.alwaysShowAnswer,
      isDark: isDark ?? this.isDark,
      selectedListId: selectedListId ?? this.selectedListId,
      selectedKind: selectedKind ?? this.selectedKind,
      userDecks: userDecks ?? this.userDecks,
      userListTitle: userListTitle ?? this.userListTitle,
      userListHidden: userListHidden ?? this.userListHidden,
      seedRevision: seedRevision ?? this.seedRevision,
    );
  }
}

/// 비어 있으면 홈이 카드가 아니라 선택 화면을 연다.
String _normalizeListId(String? raw) {
  if (raw == null || raw.isEmpty) {
    return '';
  }
  return raw;
}

import '../../shared/models/kanji.dart';

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
    );
  }

  Map<String, dynamic> toJson() => {
        'favoriteIds': favoriteIds.toList(),
        'userKanjis': userKanjis.map((item) => item.toJson()).toList(),
        'alwaysShowAnswer': alwaysShowAnswer,
        'isDark': isDark,
        'selectedListId': selectedListId,
        'selectedKind': selectedKind,
      };

  UserData copyWith({
    Set<String>? favoriteIds,
    List<Kanji>? userKanjis,
    bool? alwaysShowAnswer,
    bool? isDark,
    String? selectedListId,
    String? selectedKind,
  }) {
    return UserData(
      favoriteIds: favoriteIds ?? this.favoriteIds,
      userKanjis: userKanjis ?? this.userKanjis,
      alwaysShowAnswer: alwaysShowAnswer ?? this.alwaysShowAnswer,
      isDark: isDark ?? this.isDark,
      selectedListId: selectedListId ?? this.selectedListId,
      selectedKind: selectedKind ?? this.selectedKind,
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

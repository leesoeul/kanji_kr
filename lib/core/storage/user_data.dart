import '../../shared/models/kanji.dart';

/// 기기 로컬에 남는 사용자 상태. 시드 JSON과는 별개.
/// 端末ローカルに残るユーザー状態。シードJSONとは別。
class UserData {
  const UserData({
    required this.favoriteIds,
    required this.userKanjis,
    this.alwaysShowAnswer = false,
    this.isDark = false,
  });

  final Set<String> favoriteIds;

  /// 직접 추가한 한자 + 시드를 고친 사본.
  /// 自分で足した漢字 + シードを直したコピー。
  final List<Kanji> userKanjis;
  final bool alwaysShowAnswer;
  final bool isDark;

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
    );
  }

  Map<String, dynamic> toJson() => {
        'favoriteIds': favoriteIds.toList(),
        'userKanjis': userKanjis.map((item) => item.toJson()).toList(),
        'alwaysShowAnswer': alwaysShowAnswer,
        'isDark': isDark,
      };

  UserData copyWith({
    Set<String>? favoriteIds,
    List<Kanji>? userKanjis,
    bool? alwaysShowAnswer,
    bool? isDark,
  }) {
    return UserData(
      favoriteIds: favoriteIds ?? this.favoriteIds,
      userKanjis: userKanjis ?? this.userKanjis,
      alwaysShowAnswer: alwaysShowAnswer ?? this.alwaysShowAnswer,
      isDark: isDark ?? this.isDark,
    );
  }
}

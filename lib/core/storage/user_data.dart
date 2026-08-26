import '../../shared/models/kanji.dart';
import '../../shared/models/study_list.dart';

/// 기기 로컬에 남는 사용자 상태. 시드 JSON과는 별개.
/// 端末ローカルに残るユーザー状態。シードJSONとは別。
class UserData {
  const UserData({
    required this.favoriteIds,
    required this.userKanjis,
    this.alwaysShowAnswer = false,
    this.isDark = false,
    this.selectedListId = '',
    this.selectedKind = '',
    this.importedLists = const [],
  });

  final Set<String> favoriteIds;

  /// 직접 추가한 한자 + 시드를 고친 사본.
  /// 自分で足した漢字 + シードを直したコピー。
  final List<Kanji> userKanjis;
  final bool alwaysShowAnswer;
  final bool isDark;
  final String selectedListId;
  final String selectedKind;

  /// JSON으로 가져온 목록 메타. 카드는 userKanjis에 같이 둔다.
  /// JSONで入れた一覧メタ。カードは userKanjis に一緒に置く。
  final List<StudyList> importedLists;

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
      importedLists: [
        for (final item in json['importedLists'] as List<dynamic>? ?? const [])
          StudyList.fromJson(item as Map<String, dynamic>).copyWith(
            isImported: true,
          ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'favoriteIds': favoriteIds.toList(),
        'userKanjis': userKanjis.map((item) => item.toJson()).toList(),
        'alwaysShowAnswer': alwaysShowAnswer,
        'isDark': isDark,
        'selectedListId': selectedListId,
        'selectedKind': selectedKind,
        'importedLists': importedLists.map((item) => item.toJson()).toList(),
      };

  UserData copyWith({
    Set<String>? favoriteIds,
    List<Kanji>? userKanjis,
    bool? alwaysShowAnswer,
    bool? isDark,
    String? selectedListId,
    String? selectedKind,
    List<StudyList>? importedLists,
  }) {
    return UserData(
      favoriteIds: favoriteIds ?? this.favoriteIds,
      userKanjis: userKanjis ?? this.userKanjis,
      alwaysShowAnswer: alwaysShowAnswer ?? this.alwaysShowAnswer,
      isDark: isDark ?? this.isDark,
      selectedListId: selectedListId ?? this.selectedListId,
      selectedKind: selectedKind ?? this.selectedKind,
      importedLists: importedLists ?? this.importedLists,
    );
  }
}

String _normalizeListId(String? raw) {
  if (raw == null || raw.isEmpty || raw == ListIds.all) {
    return '';
  }
  return raw;
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/kanji.dart';
import '../../shared/models/study_list.dart';
import 'string_store.dart';
import 'string_store_stub.dart'
    if (dart.library.html) 'string_store_web.dart'
    if (dart.library.io) 'string_store_io.dart';
import 'user_data.dart';

export 'user_data.dart';

/// 즐겨찾기·직접 추가 카드·학습 설정의 영속 레이어.
///
/// 시드 JSON(에셋)은 여기 두지 않는다. 앱 번들을 덮어쓰지 않기 때문이다.
/// 사용자 데이터만 [key] 하나에 JSON으로 남긴다.
class UserStore {
  UserStore(this._store);

  final StringStore _store;

  /// 웹은 origin(포트)마다 localStorage가 갈린다. iOS/Android는 파일 하나.
  static const key = 'kanji_kr_user_v1';

  /// 저장소를 열고, 예전 SharedPreferences 값이 있으면 한 번 옮긴다.
  static Future<UserStore> create() async {
    final store = UserStore(await createStringStore());
    if (store._store.read(key) == null) {
      await store._migrateFromSharedPreferences();
    }
    return store;
  }

  UserData load() {
    final raw = _store.read(key);
    if (raw == null || raw.isEmpty) {
      return UserData.empty();
    }
    return UserData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(UserData data) {
    return _store.write(key, jsonEncode(data.toJson()));
  }

  /// 넘긴 필드만 갈아끼운다. null은 기존 값 유지.
  Future<void> patch({
    Set<String>? favoriteIds,
    List<Kanji>? userKanjis,
    bool? alwaysShowAnswer,
    bool? isDark,
    String? selectedListId,
    String? selectedKind,
    List<StudyList>? importedLists,
  }) {
    return save(
      load().copyWith(
        favoriteIds: favoriteIds,
        userKanjis: userKanjis,
        alwaysShowAnswer: alwaysShowAnswer,
        isDark: isDark,
        selectedListId: selectedListId,
        selectedKind: selectedKind,
        importedLists: importedLists,
      ),
    );
  }

  Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        return;
      }
      await _store.write(key, raw);
    } catch (_) {
      // 이전 SharedPreferences 값이 없으면 빈 데이터로 시작한다.
    }
  }
}

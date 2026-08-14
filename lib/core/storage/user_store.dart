import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/kanji.dart';
import 'string_store.dart';
import 'string_store_stub.dart'
    if (dart.library.html) 'string_store_web.dart'
    if (dart.library.io) 'string_store_io.dart';
import 'user_data.dart';

export 'user_data.dart';

/// 즐겨찾기·사용자 한자·학습 설정의 영속 레이어.
/// お気に入り・ユーザー漢字・学習設定の永続レイヤー。
///
/// 시드 `n5.json`은 여기 두지 않는다. 앱 에셋은 덮어쓰지 않기 때문.
/// シード `n5.json` はここに置かない。アセットを上書きしないため。
class UserStore {
  UserStore(this._store);

  final StringStore _store;

  /// 웹은 origin(포트)마다 localStorage가 갈린다. iOS/Android는 파일 하나.
  /// Web は origin(ポート)ごとに localStorage が分かれる。iOS/Android はファイル一つ。
  static const key = 'kanji_kr_user_v1';

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
  /// 渡したフィールドだけ差し替える。null は既存値を維持。
  Future<void> patch({
    Set<String>? favoriteIds,
    List<Kanji>? userKanjis,
    bool? alwaysShowAnswer,
    bool? isDark,
  }) {
    return save(
      load().copyWith(
        favoriteIds: favoriteIds,
        userKanjis: userKanjis,
        alwaysShowAnswer: alwaysShowAnswer,
        isDark: isDark,
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
      // 以前の SharedPreferences 値がなければ空データで始める。
    }
  }
}

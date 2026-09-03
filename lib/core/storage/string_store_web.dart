// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'string_store.dart';

/// 웹 저장. origin(스킴+호스트+포트)마다 localStorage가 갈린다.
///
/// `flutter run -d chrome --web-port=xxxx`로 포트가 바뀌면
/// 데이터가 사라진 것처럼 보인다. 예전 SharedPreferences 웹 키
/// (`flutter.$key`)도 한 번 읽어 마이그레이션한다.
class WebStringStore implements StringStore {
  @override
  String? read(String key) {
    return html.window.localStorage[key] ??
        html.window.localStorage['flutter.$key'];
  }

  @override
  Future<void> write(String key, String value) async {
    html.window.localStorage[key] = value;
  }
}

Future<StringStore> createStringStore() async => WebStringStore();

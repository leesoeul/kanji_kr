// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'string_store.dart';

/// 웹: origin마다 localStorage가 갈린다. 포트가 바뀌면 데이터가 사라진 것처럼 보인다.
/// Web: origin ごとに localStorage が分かれる。ポートが変わるとデータが消えたように見える。
class WebStringStore implements StringStore {
  @override
  String? read(String key) {
    // 예전 SharedPreferences 웹 키(`flutter.$key`)도 한 번 읽어 본다.
    // 以前の SharedPreferences Web キー(`flutter.$key`) も一度読む。
    return html.window.localStorage[key] ??
        html.window.localStorage['flutter.$key'];
  }

  @override
  Future<void> write(String key, String value) async {
    html.window.localStorage[key] = value;
  }
}

Future<StringStore> createStringStore() async => WebStringStore();

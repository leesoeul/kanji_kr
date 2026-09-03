import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'string_store.dart';

/// iOS/Android 파일 저장. 앱 지원 폴더의 `kanji_kr_user.json` 하나.
///
/// 파일 내용은 `{ "kanji_kr_user_v1": "<UserData JSON 문자열>" }` 형태다.
class FileStringStore implements StringStore {
  FileStringStore(this._file, this._values);

  final File _file;
  final Map<String, String> _values;

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(_values));
  }
}

Future<StringStore> createStringStore() async {
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}/kanji_kr_user.json');
  var values = <String, String>{};
  if (await file.exists()) {
    final raw = await file.readAsString();
    if (raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        values = {
          for (final entry in decoded.entries) entry.key: '${entry.value}',
        };
      }
    }
  }
  return FileStringStore(file, values);
}

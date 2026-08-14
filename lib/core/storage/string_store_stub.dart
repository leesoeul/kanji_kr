import 'string_store.dart';

/// 테스트·미지원 플랫폼용. 프로세스 메모리에만 둔다.
/// テスト・未対応プラットフォーム用。プロセスメモリにだけ置く。
class MemoryStringStore implements StringStore {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

Future<StringStore> createStringStore() async => MemoryStringStore();

import 'string_store.dart';

/// 테스트·미지원 플랫폼용. 프로세스가 끝나면 사라진다.
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

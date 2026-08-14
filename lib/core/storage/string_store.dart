/// 플랫폼별 키-값 저장. io / web / stub 구현을 conditional import로 고른다.
/// プラットフォーム別キー値保存。io / web / stub 実装を conditional import で選ぶ。
abstract class StringStore {
  String? read(String key);

  Future<void> write(String key, String value);
}

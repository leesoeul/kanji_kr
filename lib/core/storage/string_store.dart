/// 플랫폼별 키-값 문자열 저장소.
///
/// [user_store.dart]가 conditional import로 구현을 고른다.
/// - 웹: localStorage ([string_store_web.dart])
/// - iOS/Android: 앱 지원 폴더 JSON 파일 ([string_store_io.dart])
/// - 테스트 등: 메모리 ([string_store_stub.dart])
abstract class StringStore {
  String? read(String key);

  Future<void> write(String key, String value);
}

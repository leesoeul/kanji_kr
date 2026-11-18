# 직전 커밋 이후 변경 학습 노트

기준 커밋은 `8cc462a` (`feat(backend): generalize word suggestion prompt to all parts of speech`)이다. 이 파일은 그 이후 워킹트리의 수정·추가를 `git status` / `git diff`로 보고 정리한 것이다. 커밋이나 푸시는 하지 않았다.

한자 900장, 단어 600장은 그대로다. 바뀐 것은 그 데이터를 찾고, 목록에 넣고, 퀴즈로 내는 방식이다.

## 핵심 변경 요약

- **검색 탭.** 하단 탭이 홈 / 목록 / 퀴즈 / 검색 네 개다. 검색은 번들 SQLite(`assets/db/dictionary.db`)를 읽는다. 시드 1,500장에 KANJIDIC 한자와 위키낱말사전 단어를 합쳐 약 1만 행이다. 시드 카드는 플래시카드로 들어가고, 외부 사전 항목은 상세 시트로만 본다.
- **목록.** 즐겨찾기 전용 탭은 없앴다. 즐겨찾기는 목록 안의 가상 목록이다. 사용자가 목록을 만들고, 이름을 바꾸고, 지울 수 있다. 목록을 지우면 그 안의 사용자 카드도 같이 지운다. '내가 추가'를 숨기면 단어 추가 시트가 그 목록을 되살리지 않는다. 시트 맨 아래에는 항상 '새 목록 만들기'가 있다.
- **퀴즈.** 카드가 4장 미만이면 시작하지 않는다. 한 세트는 20문제, 보기는 2×2 네 장이다. 답을 고르면 네 장 모두 읽기와 뜻을 보여주고, 다음 버튼이 2초 동안 차오른 뒤 넘어간다. 결과에서 틀린 문제만 다시 풀거나 다음 20문제로 갈 수 있다.
- **플래시카드.** 제목은 그 카드가 속한 목록 이름이다. 검색에서 열면 첫 카드만 정답을 펼친다. 예문을 보려는 세로 스크롤은 정답을 닫지 않고, 가로로 카드를 넘길 때만 닫는다.
- **시드 데이터.** 단어 16개의 깨진 표제어·읽기를 고쳤다. 고급 한자 중 화면에서 길어지던 훈독·음독 34자는 자주 쓰는 읽기 2~3개만 남겼다. `弾` 훈독은 `ひく・はずむ・たま`다. 사전 DB 버전은 4, 시드 개정은 2다. 앱을 다시 켜면 기기 DB를 바꾸고, 예전에 시드를 고쳐 둔 사본은 버린다. 직접 추가한 카드는 남긴다.
- **웹.** `sqflite_common_ffi_web`으로 같은 사전 DB를 IndexedDB에 넣는다. AI 추천 카드는 마우스로 넘기고 점을 눌러 이동할 수 있다.
- **이번 정리.** 화면에 연결되지 않은 SRS·칩·글리프 파일을 지웠다. 목록 삭제 때 카드를 한 장씩 저장하던 것을 한 번 저장으로 바꿨다. 크림 카드 색과 테두리를 `AppTheme.cardColor` / `softCard`로 모았다. 보이는 색과 모서리 크기는 그대로다.

`font_preview_page.dart`와 `print('test')`는 저장소에 없었다. Dart의 `print`는 AI 호출 실패 로그 한 곳뿐이었고, 그 줄은 `debugPrint`로 바꿨다. 파이썬 빌드 스크립트와 백엔드의 `print`는 터미널 출력이라 그대로 두었다.

## 파일별 상세 해설

### 라우팅 — `lib/core/router/app_router.dart`

`StatefulShellRoute.indexedStack` 분기가 네 개다. 탭을 바꿔도 각 탭의 스크롤과 선택 상태가 유지된다. 카드, 목록 안, 퀴즈 플레이, 추가, 수정, 설정은 셸 밖 `GoRoute`라서 하단 바 위에 쌓인다.

검색에서 시드 카드를 열 때는 `/kanji/:id?reveal=1`이다. `reveal=1`은 첫 카드의 정답만 연다.

### 검색과 사전 DB

`lib/core/services/dictionary_db_service.dart`가 에셋 DB를 연다. 네이티브는 앱 문서 폴더에 복사하고, 웹은 wasm이 IndexedDB에 쓴다. `PRAGMA user_version`이 `kDictionaryDbVersion`(지금 4)보다 낮으면 에셋을 다시 복사한다. 그래서 시드를 고쳐 DB를 다시 빌드한 뒤 앱을 완전히 재실행하면 옛 복사본이 남이 있지 않다. hot reload로는 에셋과 DB가 안 바뀐다.

```dart
static Future<DictionaryDbService> open() async {
  if (kIsWeb) {
    return _openWeb();
  }
  final dir = await getDatabasesPath();
  final path = p.join(dir, _fileName);
  if (!await _isCurrent(databaseFactory, path)) {
    await Directory(dir).create(recursive: true);
    await File(path).writeAsBytes(await _assetBytes(), flush: true);
  }
  final db = await openDatabase(path, readOnly: true);
  return DictionaryDbService._(db);
}
```

검색어가 3글자 이상이면 FTS5 trigram을 쓰고, 더 짧거나 FTS가 실패하면 `LIKE`로 내려간다. 로마자와 가타카나는 `kana_kit`으로 히라가나로 바꾼 뒤 같이 찾는다. 정렬은 정확 일치, 시드 우선, 짧은 표제어 순이다. 시드가 같은 글자를 가지고 있으면 빌드 스크립트가 외부 사전 행을 넣지 않는다.

`lib/features/search/search_page.dart`는 이 서비스를 구독한다. 시드면 `context.push('/kanji/...')`, 외부 사전이면 바텀시트다. 시트에서 목록에 넣으면 `showListPickSheet`가 고른 목록 id로 사용자 카드를 만든다. 탭 안의 시트는 하단 바에 가려지므로 `useRootNavigator: true`로 루트 내비게이터에 띄운다.

`scripts/build_dictionary_db.py`가 JSON 시드와 캐시된 KANJIDIC·위키 덤프를 합쳐 `assets/db/dictionary.db`를 만든다. 위키 뜻은 품사 접두어, 괄호, 백과사전식 장문을 걷어 내고 짧은 뜻을 최대 3개만 남긴다. 가타카나만 있는 외래어 표제어는 넣지 않는다. `DB_VERSION`과 `kDictionaryDbVersion`은 항상 같이 올린다.

`web/sqflite_sw.js`, `web/sqlite3.wasm`은 `dart run sqflite_common_ffi_web:setup`이 만든 런타임이다. 웹 빌드에 필요해서 커밋 대상이다.

### 카탈로그와 사용자 저장

시드 JSON은 앱을 켤 때마다 다시 읽는다. 사용자가 고친 카드와 직접 추가한 카드만 `UserStore` JSON에 남고, 그 다음 시드 위에 덮어쓴다.

시드를 고친 사본이 새 읽기를 영원히 가리면 안 되므로 `kSeedRevision`을 둔다. 저장본의 개정이 낮으면 `isUserAdded == false`인 사본을 버리고 번들 시드를 쓴다.

```dart
final overlays = user.seedRevision < kSeedRevision
    ? user.userKanjis.where((item) => item.isUserAdded).toList()
    : user.userKanjis;
```

`lib/core/providers.dart`의 `CatalogController`는 이 결과를 `CatalogState` 스냅샷으로 만든다. 화면은 repository를 직접 구독하지 않고 이 스냅샷을 `ref.watch`한다. 쓰기가 끝나면 `_reload()`가 스냅샷을 다시 만든다.

목록 삭제는 예전에는 카드마다 `deleteUserKanji` → `_persist`였다. 카드가 많으면 같은 JSON을 여러 번 썼다. 지금은 id를 모아 `deleteUserKanjis`에서 메모리에서 지운 뒤 저장을 한 번 한다. 시드 카드는 여전히 건너뛴다.

`StudySession`은 홈의 종류·목록이고 기기에 남는다. `QuizSession`은 같은 모양의 클래스지만 저장하지 않아서, 퀴즈 탭에서 목록을 골라도 홈 카드가 바뀌지 않는다. 종류를 고를 때만 퀴즈 세션에 복사한다.

`lib/core/database/app_database.dart`는 SQLite가 아니다. 프로세스 메모리의 `Map`이다. 화면에 연결되지 않은 복습 레코드를 카드마다 만들던 코드는 지웠다.

### 목록 UI

`lib/features/study/home_pickers.dart`의 `HomeBrowseBody`를 홈(`study`), 목록(`deck`), 퀴즈(`quiz`)가 같이 쓴다. `openAs`만 다르다. 목록 탭만 '새 목록' 아이콘이 있어서 줄 높이가 달랐다. 세 탭 모두 그 줄을 높이 48로 고정하고, 아이콘이 없는 탭에는 같은 너비의 빈 칸을 두었다.

`lib/shared/widgets/list_name_dialog.dart`는 목록 이름 입력이다. `TextEditingController`를 State에서 해제해서, 다이얼로그가 닫히는 애니메이션 중에 컨트롤러가 먼저 사라지지 않게 했다.

`lib/shared/widgets/list_pick_sheet.dart`는 추가·검색이 공유하는 목록 선택 시트다. 숨긴 '내가 추가'는 후보에서 빠진다. 맨 아래 만들기를 고르면 `createUserDeck`이 `user_<시각>` id를 만들고, 그 id를 방금 넣으려던 단어의 목록으로 돌려준다.

### 플래시카드 — `lib/features/study/study_page.dart`

덱과 제목이 서로 다른 목록을 보던 문제를 `_source`로 맞췄다. `/kanji/:id`에 `?list=`가 없으면 그 카드의 `listId`와 `kind`를 쓴다. 외부 사전에는 시드 id가 없으므로 제목은 종류 이름('한자' 또는 '단어')으로 떨어진다. 예전에 쓰던 `studyTitle`(漢字を覚えよう) 키는 arb에서 지웠다.

```dart
(String, EntryKind?) _source(CatalogState catalog, StudySession session) {
  if (widget.initialId == null) {
    return (widget.listId ?? session.listId, session.kind);
  }
  final target = catalog.kanjis.cast<Kanji?>().firstWhere(
        (item) => item?.id == widget.initialId,
        orElse: () => null,
      );
  if (target == null) {
    return (widget.listId ?? '', session.kind);
  }
  return (widget.listId ?? target.listId, target.kind);
}
```

정답을 닫는 조건은 `ScrollUpdateNotification`이면서 `metrics.axis == Axis.horizontal`일 때뿐이다. 예문 칸의 세로 스크롤은 답을 닫지 않는다.

`reveal=1`은 `_revealAfterJump`로 점프한 카드 한 장만 연다. `onPageChanged`에서 그 플래그를 끄므로 다음 카드는 `alwaysShowAnswer` 설정을 따른다.

### 퀴즈 — `lib/features/quiz/quiz_builder.dart`, `quiz_page.dart`

`buildQuiz`는 정답 라벨과 다른 오답 3개를 못 채우면 그 문항을 건너뛴다. `prompts`를 넘기면 그 카드만 문제고, 오답 풀은 원래 `items`다. 그래서 '틀린 문제만 다시 풀기'에서도 보기는 네 개다.

화면 상태는 `_allQuestions`, `_setStart`, `_picked`다. `_picked == null`은 아직 답을 안 고른 상태이고, `-1`은 '잘 모르겠어요'다. 세트는 `_allQuestions`의 20개 부분 리스트다. 게이지 버튼은 2초 `AnimationController`가 끝나면 한 번만 다음으로 가고, 도중에 누르면 즉시 간다.

답을 고르기 전에는 보기 표제어만 보인다. 고른 뒤에는 `displayKunOn`과 뜻을 줄바꿈해서 보여 준다. 표제어가 이미 뜻이면 뜻을 다시 쓰지 않는다.

### 단어 추가 — `lib/features/kanji_add/kanji_add_page.dart`

AI 추천 `PageView`에 `dragDevices: PointerDeviceKind.values`를 넣었다. Flutter 웹의 기본 스크롤은 마우스 드래그를 받지 않아서다. 하단 점은 `GestureDetector`로 해당 페이지로 애니메이션한다.

API가 실패하면 더미 추천으로 떨어지고, 그 사실은 `debugPrint`로만 남긴다. 화면 흐름은 같다.

종류를 고르기 전 홈의 '단어 추가' 버튼은 `session.kind == null`이면 숨긴다. 목록 단계부터 보인다.

### 시드 JSON

`assets/data/word/verb_beg.json`, `verb_mid.json`에서 한국어·다른 문자가 섞인 읽기와 표제어를 고쳤다. 예: `洗う`의 읽기 `아라우` → `あらう`, `洗탁する` → `洗濯する`, `伝える`의 읽기 `つ伝える` → `つたえる`. `〜ていただく` 같은 문법 패턴은 그대로다.

`assets/data/kanji/adv.json`의 긴 훈독·음독만 줄였다. 초급·중급 한자의 음독·훈독 칸에는 한국어가 없었다.

### 테마 — `lib/core/theme/app_theme.dart`

본문 폰트는 Klee One, 폴백은 Gowun Dodum이다. 주석으로 남아 있던 다른 폰트 후보는 지웠다. 카드 배경이 라이트에서 크림(`0xFFFFFBFC`), 다크에서 `surfaceContainerHighest`인 곳을 `cardColor`로 모았다. 테두리까지 같은 카드는 `softCard`다. 퀴즈 보기처럼 정답 초록·오답 분홍이 끼는 카드는 색이 달라서 이 헬퍼를 쓰지 않는다.

### 문구 — `l10n/app_ko.arb`, `app_ja.arb`

퀴즈 문구(잘 모르겠어요, 다음 세트, 틀린 문제만 다시)와 목록 삭제 문구를 넣었다. `kindVerb`는 `kindWord`로 통일했다. 생성 파일 `lib/core/l10n/generated/`는 `flutter gen-l10n` 결과라 손으로 고치지 않는다.

### 그 밖에 같이 바뀐 파일

- `lib/core/study_filter.dart` — 종류별 목록 조합, 숨긴 '내가 추가', 사용자 목록.
- `lib/shared/models/study_list.dart` — `UserDeck`, 목록 편집 가능 여부.
- `lib/features/kanji_list/kanji_list_page.dart` — 목록 탭이 `HomeBrowseBody`를 쓰고, 첫 화면에서는 추가 버튼을 숨긴다.
- `lib/features/study/kanji_search_sheet.dart` — 헤더 검색이 카탈로그 카드로 이어진다.
- `test/kanji_json_test.dart` — 시드 1,500장, DB `user_version` 4, `弾` 훈독, 퀴즈 보기 4개.
- `pubspec.yaml` — `sqflite_common_ffi_web`, `assets/db/dictionary.db`.
- `firebase.json`, `.firebaserc` — 웹 빌드(`build/web`) 호스팅 설정. `.firebase/`는 CLI 캐시라 `.gitignore`에 넣었다. `n/`에 생겼던 Firebase 기본 환영 페이지는 앱이 쓰지 않아서 지웠다.
- `ios/` — Flutter iOS 템플릿의 SceneDelegate(`UIApplicationSceneManifest`) 동기화와 Pod 잠금 갱신이다. 학습 기능 로직은 여기 없다.
- `analysis_options.yaml` — 생성 l10n과 플랫폼 폴더를 analyzer 제외에 넣었다.

지운 파일: `lib/features/favorites/favorites_page.dart`, `lib/features/srs/srs_controller.dart`, `lib/shared/models/review_card.dart`, `lib/core/constants/srs.dart`, `lib/shared/widgets/level_chip.dart`, `lib/shared/widgets/kanji_glyph.dart`. 즐겨찾기 페이지는 목록 줄으로 대체됐다. 나머지는 어떤 파일도 import하지 않았다.

## Flutter / Riverpod / DB 학습 포인트

### 상태 관리는 스냅샷을 다시 만드는 쪽에 가깝다

`AsyncNotifier`의 `state`를 필드 단위로 고치지 않고, 저장이 끝난 뒤 `_reload()`가 `CatalogState`를 새로 만든다. 화면은 `ref.watch(catalogControllerProvider)`로 그 스냅샷만 본다. 그래서 즐겨찾기, 목록 이름, 카드 목록이 서로 어긋나기 어렵다. 비용은 카드 1,500장을 다시 읽는 것인데, 이 크기에서는 그게 맞다.

`ref.watch`는 값이 바뀔 때 위젯을 다시 그린다. 시트 안에서 카탈로그를 한 번만 읽으면 `ref.read`다. `showListPickSheet`가 그렇다. watch로 바꾸면 시트가 열린 동안 목록이 바뀔 때마다 시트가 다시 빌드된다.

홈 세션과 퀴즈 세션을 클래스는 공유하고 Provider는 나눈 이유가 여기 있다. 같은 객체를 두 탭이 watch하면 한쪽 선택이 다른 탭을 다시 그린다.

### 셸 라우트와 루트 내비게이터

`StatefulShellRoute` 안에서 `showModalBottomSheet`의 기본 내비게이터는 그 탭이다. 하단 `NavigationBar`가 시트를 가린다. `useRootNavigator: true`는 시트를 셸 밖에 붙인다.

### SQLite를 두 층으로 나눈다

학습 카드는 메모리 `Map` + 사용자 JSON이다. 켤 때마다 시드 에셋을 다시 읽으므로 시드 파일 수정이 앱 재시작만으로 반영된다. 사용자가 고친 시드 사본만 예외였고, 그건 `seedRevision`으로 한 번 걷어 낸다.

검색 사전은 읽기 전용 SQLite다. 에셋 바이트를 통째로 복사하고 버전 숫자로 교체한다. 마이그레이션 SQL을 쓰지 않는다. 데이터가 바뀌면 파이썬에서 DB를 다시 만들고 버전을 올린다. 웹은 파일이 없으므로 같은 바이트를 IndexedDB에 쓴다. import는 `sqflite_ffi_io.dart`를 모바일에서, `sqflite_ffi_web.dart`를 웹에서 고르는 조건부 export라 iOS 코드가 웹 전용 API를 직접 부르지 않는다.

### 폰트 폴백

`fontFamily`에 Klee One을 두고 `fontFamilyFallback`에 Gowun Dodum을 둔다. Klee One에 없는 한글 글리프는 폴백이 그린다. 테마에 한 번만 지정하면 `Text`를 만든 화면이 따라간다. 카드 색처럼 화면마다 반복되던 값만 `AppTheme` 헬퍼로 올렸다.

### 웹 스크롤

머티리얼 기본 `ScrollBehavior`의 드래그 장치는 터치와 트랙패드다. 마우스는 포함되지 않아서 웹 `PageView`가 드래그로 안 움직인다. `copyWith(dragDevices: PointerDeviceKind.values.toSet())`를 그 `PageView`에만 주면 다른 스크롤 동작은 그대로다.

### 읽어 볼 순서

1. `assets/data/lists.json` → `kanji_detail_repository.dart`의 `ensureReady`
2. `providers.dart`의 `CatalogState`와 `CatalogController._reload`
3. `app_router.dart`의 셸과 `/kanji/:id`
4. `study_page.dart`의 `_source`, `_deck`
5. `dictionary_db_service.dart`의 `open` / `search`
6. `quiz_builder.dart`의 `buildQuiz`와 `quiz_page.dart`의 `_answer`, `_next`

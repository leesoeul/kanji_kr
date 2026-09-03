# kanji_kr 구조 노트

> Flutter 한자·동사 학습 앱. `kanji_game`의 후속.
>
> 노션: 이 파일 전체를 복사 → 페이지에 붙여넣기 (Markdown으로 인식됨)

---

## 한 줄 요약

`kanji_game`과 같은 플래시카드 앱이다. 차이는 데이터와 상태관리 방식이다.

- **kanji_game:** `setState` + mixin, 한자/동사 모델 분리, Dart에 데이터 하드코딩, Firebase
- **kanji_kr:** Riverpod + go_router, `Kanji` 하나로 kind 구분, JSON 에셋, 로컬 JSON persist

---

## 실행 흐름

1. `main.dart` — `UserStore`(로컬 JSON)를 연다
2. `ProviderScope`에 실제 `UserStore`를 주입한다 (`userStoreProvider` override)
3. `KanjiKrApp` — 테마·한국어 locale·라우터
4. `CatalogController` — 시드 JSON + 사용자 데이터를 합쳐 카탈로그를 만든다
5. 하단 4탭 셸이 뜬다

탭: **홈(학습) / 목록 / 퀴즈 / 즐겨찾기**

추가·수정·설정은 탭 위에 올린다 (하단바에 없음).

홈·퀴즈 모두 2단: `한자 | 동사` → 목록 고르기 → 카드/문제

세션은 홈(`studySessionProvider`)과 퀴즈(`quizSessionProvider`)가 **따로**다.

하단 내비 숨김:

- 홈: 종류 고르기 전, 또는 이미 카드 보는 중
- 퀴즈: 이미 문제 푸는 중
- 목록 고르는 화면에서는 내비 유지 (퀴즈 탭으로 갈 수 있게)

---

## 폴더

```
lib/
  main.dart              저장소 연 뒤 Provider 주입
  app.dart               MaterialApp.router, 테마, ko locale
  core/
    providers.dart       앱 상태 전부
    router/app_router.dart
    database/app_database.dart   SQLite 아님. 세션용 Map
    storage/             UserStore — 즐겨찾기·직접추가·설정 persist
    study_filter.dart    목록 id로 카드 걸러 내기
    import/list_import.dart
    l10n/  theme/  kana.dart
  features/
    study/               홈 피커 + 플래시카드
    quiz/                객관식
    kanji_list/          목록 탭
    kanji_add/           추가·수정
    favorites/
    settings/
    kanji_detail/        실제로는 카탈로그 repository (이름만 detail)
    srs/                 UI에 안 연결됨 (죽은 코드)
  shared/models/         Kanji, StudyList, Reading, ReviewCard
  shared/widgets/

assets/data/
  lists.json             목록 카탈로그 (어떤 JSON을 쓸지)
  kanji/beg.json mid.json adv.json
  word/verb_beg.json verb_mid.json verb_adv.json
```

---

## 핵심 파일

| 파일 | 하는 일 | 줄 수 대략 |
|------|---------|-----------|
| `lib/core/providers.dart` | 카탈로그, 학습/퀴즈 선택, 다크·정답표시 | ~310 |
| `lib/core/router/app_router.dart` | 4탭 셸 + `/add` `/edit` `/settings` `/kanji/:id` | ~150 |
| `lib/features/kanji_detail/kanji_detail_repository.dart` | 시드 JSON + UserStore 합치기 | ~200 |
| `lib/core/study_filter.dart` | `listId` → 카드 배열 | ~160 |
| `lib/features/study/study_page.dart` | 홈 플래시카드 UI | ~600 |
| `lib/features/study/home_pickers.dart` | 종류·목록 고르기 | ~310 |
| `lib/features/quiz/quiz_page.dart` | 퀴즈 UI | ~460 |
| `lib/features/quiz/quiz_builder.dart` | 객관식 문항 생성 | ~80 |
| `lib/shared/models/kanji.dart` | 카드 1장 (한자·단어 공통) | ~250 |
| `lib/core/storage/user_store.dart` | persist 키 `kanji_kr_user_v1` | ~90 |

읽는 순서 (추천):

1. `main.dart`
2. `providers.dart`
3. `kanji_detail_repository.dart`
4. `study_filter.dart`
5. `study_page.dart`

---

## 데이터

### 시드 (앱에 묶임)

`assets/data/lists.json`이 목록 메타다. 각 항목의 `asset`이 카드 JSON 경로다.

| id | kind | 제목 |
|----|------|------|
| `kanji_beg` | kanji | 초급 한자 |
| `kanji_mid` | kanji | 중급 한자 |
| `kanji_adv` | kanji | 고급 한자 |
| `verb_beg` | word | 초급 동사 |
| `verb_mid` | word | 중급 동사 |
| `verb_adv` | word | 고급 동사 |

시드는 **에셋을 덮어쓰지 않는다.** 수정분은 UserStore에만 남긴다.

에셋 JSON 변경은 핫 리로드로 안 들어온다. **핫 리스타트 또는 재빌드.**

`KanjiRepository`는 프로세스당 한 번만 로드한다 (`_ready` 캐시).

예전 샘플 `n5_word` / `n5_kanji`는 번들에 남아 있어도 목록에서 뺀다.

### 사용자 데이터 (기기)

`UserStore` 키: `kanji_kr_user_v1`

- 즐겨찾기 id
- 직접 추가한 카드, 시드를 고친 카드
- JSON으로 import한 목록
- 선택한 kind / listId
- 다크모드, 정답 항상 표시

웹은 origin(포트)마다 localStorage가 갈린다. iOS/Android는 파일 하나.

### 메모리 DB

`AppDatabase`는 SQLite가 아니다. 실행 중 `Map`이다.

앱을 끄면 시드는 다시 JSON에서 읽고, 사용자 분만 UserStore에서 복구한다.

---

## 모델

한 장 = `Kanji`. 한자·단어가 같은 클래스다. `kind`로 가른다.

- `kind`: `kanji` | `word` | `mixed`
- `listId`: 시드는 `kanji_beg` 등, 직접 추가는 `user`
- `literal`: 글자 또는 단어 표기
- `koreanMeaning`: 훈음 (예: 메 산)
- `meaningsKo`: 짧은 뜻
- `onYomi` / `kunYomi`: 한자 읽기
- `reading`: 단어 전체 읽기
- `hint`: 어원·암기. 비어 있으면 정답에 안 냄
- `isUserAdded`

가상 목록 id (`ListIds`):

- `favorites` — 즐겨찾기
- `user` — 내가 추가

`composeListsForKind`가 builtin + imported + 가상(내가 추가, 즐겨찾기)을 한 줄 목록으로 만든다.

---

## 상태 (Riverpod)

전부 `lib/core/providers.dart`에 있다.

| Provider | 내용 |
|----------|------|
| `userStoreProvider` | `main`에서 override. 기본값은 예외 |
| `appDatabaseProvider` | 인메모리 DB |
| `kanjiRepositoryProvider` | 시드+사용자 합치기 |
| `catalogControllerProvider` | 화면에 주는 카드·목록·즐겨찾기. 쓰기 후 `_reload` |
| `studyPrefsProvider` | 정답 항상 표시, 다크모드 |
| `studySessionProvider` | 홈: kind, listId, shuffleNonce. persist |
| `quizSessionProvider` | 퀴즈 전용. persist 안 함. 홈 선택과 안 섞음 |

퀴즈 탭을 처음 열 때, 퀴즈에 kind가 없으면 홈 kind를 복사한다.

---

## 화면

### 홈 `StudyPage`

1. kind 없음 → 한자/동사 고르기 (`home_pickers.dart`)
2. listId 없음 → 목록 고르기
3. 둘 다 있음 → `PageView` 플래시카드

정답은 카드 탭이 아니라 **아래 버튼**으로만 연다.

헤더: 제목 가운데 / 셔플·다크 왼쪽 / 장수·검색 오른쪽

`/kanji/:id`로 들어오면 특정 카드로 점프 (목록·즐겨찾기에서).

### 퀴즈 `QuizPage`

같은 2단 피커. `buildQuiz`가 객관식 (뜻 맞히기 / 글자 맞히기).

보기 2–4개. 카드가 2장 미만이면 퀴즈를 안 만든다.

### 목록 / 즐겨찾기 / 추가

- 목록 탭: 현재 카탈로그를 리스트로
- 즐겨찾기 탭: 하트 친 카드
- `/add` `/edit/:id`: 직접 추가·수정 폼
- JSON import: `CatalogController.importJson` → 마지막 import 목록을 홈에서 연다

---

## kanji_game 대응표

| kanji_game | kanji_kr |
|------------|----------|
| `Navigator` + `home:` | `go_router` StatefulShell |
| `setState` + `StudyLogicMixin` | Riverpod `StudySession` / `CatalogController` |
| `Kanji` + `Verb` 따로 | `Kanji` + `EntryKind` |
| `kanji_data.dart` / `verb_data.dart` | `assets/data/*.json` |
| Firestore 진도 | 로컬 JSON. 카드 인덱스 진도는 거의 없음 |
| Firebase 로그인 | 없음 |
| 한자 홈 / 동사 홈 화면 분리 | 같은 `StudyPage`, kind만 다름 |
| 테마 전역 `ValueNotifier` | `studyPrefsProvider` |

이미 아는 것: 카드 넘기기, 정답 열기, 셔플, 검색, 한자/동사 분리 UX

새로 볼 것: Riverpod `Notifier`, 라우터 셸, JSON 카탈로그, UserStore

막히기 쉬운 한 줄: **시드는 에셋, 사용자 데이터만 persist.**

---

## 리팩터링

지금 규모에 **큰 리라이트는 필요 없다.** Dart UI 로직은 대략 2–3천 줄.

나중에 손대면 좋은 것:

1. `providers.dart` — 카탈로그 / 세션 / 설정을 파일로 쪼개기
2. 이름 — `Kanji`가 단어까지 담당, `kanji_detail`은 실제론 카탈로그
3. SRS — `srs_controller`, `ReviewCard`는 UI에 없음. 쓰거나 지우기
4. `study_page.dart` (~600줄) — `kanji_game` mixin 분리와 비슷한 두께. 급하지 않음

기능이 더 붙기 전에 **이름 정리**는 가치 있다. 아키텍처 교체는 이르다.

---

## 이해 시간 (소을 기준)

Flutter와 플래시카드 UX는 이미 있다. 처음부터 다시 배울 양은 아니다.

| 목표 | 시간 |
|------|------|
| 화면만 고치기 (`study_page`, `home_pickers`, `quiz_page`) | 30분–1시간 |
| 목록이 왜 나오는지 (`lists.json` → repo → filter → session) | 1–2시간 |
| 추가 / 즐겨찾기 / import까지 (`UserStore` + `CatalogController`) | 반나절 |
| 전체 분석·리팩터 판단 | 하루 |
| 숙련 | 2–3일 만지면서 |

---

## 스택

- Flutter SDK `>=3.4.3`
- `flutter_riverpod`
- `go_router`
- `shared_preferences` / `path_provider` (UserStore)
- l10n: ARB는 ko/ja 있지만 UI locale은 **한국어 고정**
- 테스트: `test/kanji_json_test.dart` (시드 JSON 무결성)

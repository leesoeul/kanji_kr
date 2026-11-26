// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '하루 탄고';

  @override
  String get homeTitle => '플래시카드';

  @override
  String get todayReview => '오늘 복습';

  @override
  String reviewCount(int count) {
    return '$count장';
  }

  @override
  String get continueLearning => '이어서 학습';

  @override
  String get noReviews => '오늘 복습할 카드가 없습니다';

  @override
  String get onYomi => '음읽기';

  @override
  String get kunYomi => '훈읽기';

  @override
  String get koreanMeaning => '한국어 뜻';

  @override
  String get examples => '예문';

  @override
  String get kanjiList => '목록';

  @override
  String get settings => '설정';

  @override
  String get quizComingSoon => '퀴즈는 곧 제공됩니다';

  @override
  String get quizTitle => '퀴즈';

  @override
  String listUser(String kind) {
    return '추가한 $kind';
  }

  @override
  String get shuffle => '랜덤';

  @override
  String get shuffled => '순서를 섞었습니다';

  @override
  String get kindKanji => '한자';

  @override
  String get kindWord => '단어';

  @override
  String get pickKindTitle => '한자 / 단어';

  @override
  String get pickListTitle => '목록을 고르세요';

  @override
  String get pickPracticeList => '연습할 목록을 고르세요';

  @override
  String get pickManageList => '단어를 한눈에 보고 관리하세요';

  @override
  String get practiceLabel => '연습';

  @override
  String get emptyPracticeList => '아직 등록된 단어가 없습니다';

  @override
  String get readingLabel => '읽기';

  @override
  String get readingHint => '예: やまのぼり';

  @override
  String get surfaceLabel => '표기';

  @override
  String get quizStart => '시작';

  @override
  String get quizNext => '다음';

  @override
  String get quizSeeResult => '결과 보기';

  @override
  String get quizHint => '힌트';

  @override
  String get quizResult => '결과';

  @override
  String quizScore(int correct, int total) {
    return '$correct / $total';
  }

  @override
  String get quizRetry => '다시 풀기';

  @override
  String get quizDontKnow => '잘 모르겠어요';

  @override
  String get quizNextArrow => '다음 >';

  @override
  String get quizCorrectLabel => '맞힌 개수';

  @override
  String get quizWrongList => '틀린 문제';

  @override
  String get quizAllCorrect => '모두 맞혔어요';

  @override
  String quizRetryWrong(int count) {
    return '틀린 문제만 다시 풀기 ($count문제)';
  }

  @override
  String quizNextSet(int count) {
    return '다음 퀴즈로 넘어가기 (다음 $count문제)';
  }

  @override
  String get quizCorrect => '정답';

  @override
  String get quizWrong => '오답';

  @override
  String quizEmpty(int count) {
    return '퀴즈를 풀려면 목록에 카드가 $count장 이상 있어야 해요';
  }

  @override
  String get quizPickMeaning => '뜻을 고르세요';

  @override
  String get quizPickLiteral => '글자를 고르세요';

  @override
  String get quizGuideMeaning => '알맞은 뜻을 고르세요';

  @override
  String quizGuideLiteral(String kind) {
    return '알맞은 $kind를 고르세요';
  }

  @override
  String get quizModeMeaning => '뜻';

  @override
  String get quizModeLiteral => '글자';

  @override
  String get quizModeSelect => '퀴즈 모드를 선택하세요';

  @override
  String get quizModePickMeaning => '뜻 보고 글자 맞히기';

  @override
  String get quizModePickLiteral => '글자 보고 뜻 맞히기';

  @override
  String quizProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get addItem => '추가';

  @override
  String get addWord => '단어 추가';

  @override
  String get addList => '목록 추가';

  @override
  String get newList => '새 목록 만들기';

  @override
  String get renameList => '이름 변경';

  @override
  String get deleteList => '목록 삭제';

  @override
  String get listNameLabel => '목록 이름';

  @override
  String deleteListTitle(String name) {
    return '\'$name\' 목록을 삭제할까요?';
  }

  @override
  String deleteListBody(int count) {
    return '목록 안의 단어 $count개도 함께 삭제됩니다.';
  }

  @override
  String get emptyList => '이 목록이 비어 있습니다';

  @override
  String emptyFavorites(String kind) {
    return '즐겨찾은 $kind가 없습니다';
  }

  @override
  String get cardReading => '읽기';

  @override
  String jlptLevel(String level) {
    return 'JLPT $level';
  }

  @override
  String strokeCountLabel(int count) {
    return '획수 $count';
  }

  @override
  String get uiLanguage => 'UI 언어';

  @override
  String get learningLevel => '학습 레벨';

  @override
  String get favorites => '즐겨찾기';

  @override
  String get noFavorites => '즐겨찾은 한자가 없습니다';

  @override
  String favoriteCount(int count) {
    return '$count자';
  }

  @override
  String get addKanji => '한자 추가';

  @override
  String get editKanji => '한자 수정';

  @override
  String get literalLabel => '한자';

  @override
  String get meaningHint => '예: 산';

  @override
  String get onYomiHint => '예: さん';

  @override
  String get kunYomiHint => '예: やま';

  @override
  String get exampleJp => '예문 (일본어)';

  @override
  String get exampleKo => '예문 (한국어)';

  @override
  String get save => '저장';

  @override
  String get delete => '삭제';

  @override
  String get cancel => '취소';

  @override
  String get deleteKanjiConfirm => '이 항목을 삭제할까요?';

  @override
  String get alreadyExists => '이미 있는 항목입니다';

  @override
  String get requiredField => '필수 항목입니다';

  @override
  String get userKanji => '내 한자';

  @override
  String get bookmarkAdd => '즐겨찾기';

  @override
  String get bookmarkRemove => '즐겨찾기 해제';

  @override
  String get added => '추가했습니다';

  @override
  String get saved => '저장했습니다';

  @override
  String get showAnswer => '정답';

  @override
  String get showAnswerLocked => '정답 고정';

  @override
  String get cardKun => '훈독';

  @override
  String get cardOn => '음독';

  @override
  String get searchKanji => '검색';

  @override
  String get searchHint => '한자, 단어, 뜻, 읽기';

  @override
  String get noSearchResults => '검색 결과가 없습니다';

  @override
  String get alwaysShowOn => '이제부터 정답을 보여 줍니다';

  @override
  String get alwaysShowOff => '이제부터 정답을 숨깁니다';

  @override
  String get doubleTapHint => '💡 \"정답\"를 두 번 탭하면 정답이 항상 표시됩니다.';

  @override
  String get aiAutocomplete => 'AI 자동완성';

  @override
  String get aiSuggestions => 'AI 추천';

  @override
  String get aiLoadingSuggestions => 'AI가 추천 중...';

  @override
  String get aiConnectionError => '연결할 수 없습니다. 네트워크를 확인해 주세요.';

  @override
  String get aiRetry => '다시 시도';

  @override
  String get fillWithThis => '이 내용으로 채우기';

  @override
  String get requiredFieldMark => '*';

  @override
  String get resetForm => '초기화';

  @override
  String get resetFormConfirm => '입력한 내용을 모두 지울까요?';

  @override
  String get searchTab => '검색';

  @override
  String get dictionaryHint => '한자, 히라가나, 로마자, 한국어 뜻';

  @override
  String get filterAll => '전체';

  @override
  String get filterKanji => '한자';

  @override
  String get filterWord => '단어';

  @override
  String get addToMyList => '추가';

  @override
  String get pickTargetList => '어느 목록에 넣을까요?';

  @override
  String addedToList(String name) {
    return '\'$name\'에 추가했어요';
  }

  @override
  String get aiFindAndAdd => '원하는 단어가 없나요? AI로 찾아서 추가하기';

  @override
  String get dictionaryEmptyQuery => '찾고 싶은 단어를 입력해 보세요';
}

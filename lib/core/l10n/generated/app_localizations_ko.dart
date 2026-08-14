import 'app_localizations.dart';

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '한자 학습';

  @override
  String get homeTitle => '홈';

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
  String get koreanHanja => '한국 한자';

  @override
  String get examples => '예문';

  @override
  String get kanjiList => '한자 목록';

  @override
  String get settings => '설정';

  @override
  String get quizComingSoon => '퀴즈는 곧 제공됩니다';

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
  String get koreanHanjaHint => '비워 두면 한자와 같음';

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
  String get deleteKanjiConfirm => '이 한자를 삭제할까요?';

  @override
  String get alreadyExists => '이미 있는 한자입니다';

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
  String get studyTitle => '漢字을 覚えよう！';

  @override
  String get showAnswer => '정답';

  @override
  String get hint => '힌트';

  @override
  String get cardKun => '훈독';

  @override
  String get cardOn => '음독';

  @override
  String get searchKanji => '검색';

  @override
  String get searchHint => '한자, 뜻, 읽기';

  @override
  String get noSearchResults => '검색 결과가 없습니다';

  @override
  String get alwaysShowOn => '이제부터 정답을 보여 줍니다';

  @override
  String get alwaysShowOff => '이제부터 정답을 숨깁니다';
}

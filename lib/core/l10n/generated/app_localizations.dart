import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ja'),
    Locale('ko')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'한자 학습'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In ko, this message translates to:
  /// **'홈'**
  String get homeTitle;

  /// No description provided for @todayReview.
  ///
  /// In ko, this message translates to:
  /// **'오늘 복습'**
  String get todayReview;

  /// No description provided for @reviewCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}장'**
  String reviewCount(int count);

  /// No description provided for @continueLearning.
  ///
  /// In ko, this message translates to:
  /// **'이어서 학습'**
  String get continueLearning;

  /// No description provided for @noReviews.
  ///
  /// In ko, this message translates to:
  /// **'오늘 복습할 카드가 없습니다'**
  String get noReviews;

  /// No description provided for @onYomi.
  ///
  /// In ko, this message translates to:
  /// **'음읽기'**
  String get onYomi;

  /// No description provided for @kunYomi.
  ///
  /// In ko, this message translates to:
  /// **'훈읽기'**
  String get kunYomi;

  /// No description provided for @koreanMeaning.
  ///
  /// In ko, this message translates to:
  /// **'한국어 뜻'**
  String get koreanMeaning;

  /// No description provided for @koreanHanja.
  ///
  /// In ko, this message translates to:
  /// **'한국 한자'**
  String get koreanHanja;

  /// No description provided for @examples.
  ///
  /// In ko, this message translates to:
  /// **'예문'**
  String get examples;

  /// No description provided for @kanjiList.
  ///
  /// In ko, this message translates to:
  /// **'목록'**
  String get kanjiList;

  /// No description provided for @settings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settings;

  /// No description provided for @quizComingSoon.
  ///
  /// In ko, this message translates to:
  /// **'퀴즈는 곧 제공됩니다'**
  String get quizComingSoon;

  /// No description provided for @quizTitle.
  ///
  /// In ko, this message translates to:
  /// **'퀴즈'**
  String get quizTitle;

  /// No description provided for @listUser.
  ///
  /// In ko, this message translates to:
  /// **'내가 추가'**
  String get listUser;

  /// No description provided for @shuffle.
  ///
  /// In ko, this message translates to:
  /// **'랜덤'**
  String get shuffle;

  /// No description provided for @shuffled.
  ///
  /// In ko, this message translates to:
  /// **'순서를 섞었습니다'**
  String get shuffled;

  /// No description provided for @kindKanji.
  ///
  /// In ko, this message translates to:
  /// **'한자'**
  String get kindKanji;

  /// No description provided for @kindWord.
  ///
  /// In ko, this message translates to:
  /// **'단어'**
  String get kindWord;

  /// No description provided for @kindVerb.
  ///
  /// In ko, this message translates to:
  /// **'동사'**
  String get kindVerb;

  /// No description provided for @pickKindTitle.
  ///
  /// In ko, this message translates to:
  /// **'한자 / 동사'**
  String get pickKindTitle;

  /// No description provided for @pickListTitle.
  ///
  /// In ko, this message translates to:
  /// **'목록을 고르세요'**
  String get pickListTitle;

  /// No description provided for @readingLabel.
  ///
  /// In ko, this message translates to:
  /// **'읽기'**
  String get readingLabel;

  /// No description provided for @readingHint.
  ///
  /// In ko, this message translates to:
  /// **'예: やまのぼり'**
  String get readingHint;

  /// No description provided for @surfaceLabel.
  ///
  /// In ko, this message translates to:
  /// **'표기'**
  String get surfaceLabel;

  /// No description provided for @quizStart.
  ///
  /// In ko, this message translates to:
  /// **'시작'**
  String get quizStart;

  /// No description provided for @quizNext.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get quizNext;

  /// No description provided for @quizSeeResult.
  ///
  /// In ko, this message translates to:
  /// **'결과 보기'**
  String get quizSeeResult;

  /// No description provided for @quizResult.
  ///
  /// In ko, this message translates to:
  /// **'결과'**
  String get quizResult;

  /// No description provided for @quizScore.
  ///
  /// In ko, this message translates to:
  /// **'{correct} / {total}'**
  String quizScore(int correct, int total);

  /// No description provided for @quizRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 풀기'**
  String get quizRetry;

  /// No description provided for @quizCorrect.
  ///
  /// In ko, this message translates to:
  /// **'정답'**
  String get quizCorrect;

  /// No description provided for @quizWrong.
  ///
  /// In ko, this message translates to:
  /// **'오답'**
  String get quizWrong;

  /// No description provided for @quizEmpty.
  ///
  /// In ko, this message translates to:
  /// **'이 목록에 퀴즈를 낼 카드가 부족합니다'**
  String get quizEmpty;

  /// No description provided for @quizPickMeaning.
  ///
  /// In ko, this message translates to:
  /// **'뜻을 고르세요'**
  String get quizPickMeaning;

  /// No description provided for @quizPickLiteral.
  ///
  /// In ko, this message translates to:
  /// **'글자를 고르세요'**
  String get quizPickLiteral;

  /// No description provided for @quizModeMeaning.
  ///
  /// In ko, this message translates to:
  /// **'뜻'**
  String get quizModeMeaning;

  /// No description provided for @quizModeLiteral.
  ///
  /// In ko, this message translates to:
  /// **'글자'**
  String get quizModeLiteral;

  /// No description provided for @quizProgress.
  ///
  /// In ko, this message translates to:
  /// **'{current} / {total}'**
  String quizProgress(int current, int total);

  /// No description provided for @addItem.
  ///
  /// In ko, this message translates to:
  /// **'추가'**
  String get addItem;

  /// No description provided for @addWord.
  ///
  /// In ko, this message translates to:
  /// **'단어 추가'**
  String get addWord;

  /// No description provided for @emptyList.
  ///
  /// In ko, this message translates to:
  /// **'이 목록이 비어 있습니다'**
  String get emptyList;

  /// No description provided for @cardReading.
  ///
  /// In ko, this message translates to:
  /// **'읽기'**
  String get cardReading;

  /// No description provided for @jlptLevel.
  ///
  /// In ko, this message translates to:
  /// **'JLPT {level}'**
  String jlptLevel(String level);

  /// No description provided for @strokeCountLabel.
  ///
  /// In ko, this message translates to:
  /// **'획수 {count}'**
  String strokeCountLabel(int count);

  /// No description provided for @uiLanguage.
  ///
  /// In ko, this message translates to:
  /// **'UI 언어'**
  String get uiLanguage;

  /// No description provided for @learningLevel.
  ///
  /// In ko, this message translates to:
  /// **'학습 레벨'**
  String get learningLevel;

  /// No description provided for @favorites.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기'**
  String get favorites;

  /// No description provided for @noFavorites.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾은 한자가 없습니다'**
  String get noFavorites;

  /// No description provided for @favoriteCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}자'**
  String favoriteCount(int count);

  /// No description provided for @addKanji.
  ///
  /// In ko, this message translates to:
  /// **'한자 추가'**
  String get addKanji;

  /// No description provided for @editKanji.
  ///
  /// In ko, this message translates to:
  /// **'한자 수정'**
  String get editKanji;

  /// No description provided for @literalLabel.
  ///
  /// In ko, this message translates to:
  /// **'한자'**
  String get literalLabel;

  /// No description provided for @meaningHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 산'**
  String get meaningHint;

  /// No description provided for @onYomiHint.
  ///
  /// In ko, this message translates to:
  /// **'예: さん'**
  String get onYomiHint;

  /// No description provided for @kunYomiHint.
  ///
  /// In ko, this message translates to:
  /// **'예: やま'**
  String get kunYomiHint;

  /// No description provided for @koreanHanjaHint.
  ///
  /// In ko, this message translates to:
  /// **'비워 두면 한자와 같음'**
  String get koreanHanjaHint;

  /// No description provided for @exampleJp.
  ///
  /// In ko, this message translates to:
  /// **'예문 (일본어)'**
  String get exampleJp;

  /// No description provided for @exampleKo.
  ///
  /// In ko, this message translates to:
  /// **'예문 (한국어)'**
  String get exampleKo;

  /// No description provided for @save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @deleteKanjiConfirm.
  ///
  /// In ko, this message translates to:
  /// **'이 항목을 삭제할까요?'**
  String get deleteKanjiConfirm;

  /// No description provided for @alreadyExists.
  ///
  /// In ko, this message translates to:
  /// **'이미 있는 항목입니다'**
  String get alreadyExists;

  /// No description provided for @requiredField.
  ///
  /// In ko, this message translates to:
  /// **'필수 항목입니다'**
  String get requiredField;

  /// No description provided for @userKanji.
  ///
  /// In ko, this message translates to:
  /// **'내 한자'**
  String get userKanji;

  /// No description provided for @bookmarkAdd.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기'**
  String get bookmarkAdd;

  /// No description provided for @bookmarkRemove.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기 해제'**
  String get bookmarkRemove;

  /// No description provided for @added.
  ///
  /// In ko, this message translates to:
  /// **'추가했습니다'**
  String get added;

  /// No description provided for @saved.
  ///
  /// In ko, this message translates to:
  /// **'저장했습니다'**
  String get saved;

  /// No description provided for @studyTitle.
  ///
  /// In ko, this message translates to:
  /// **'漢字을 覚えよう！'**
  String get studyTitle;

  /// No description provided for @showAnswer.
  ///
  /// In ko, this message translates to:
  /// **'정답'**
  String get showAnswer;

  /// No description provided for @hint.
  ///
  /// In ko, this message translates to:
  /// **'힌트'**
  String get hint;

  /// No description provided for @cardKun.
  ///
  /// In ko, this message translates to:
  /// **'훈독'**
  String get cardKun;

  /// No description provided for @cardOn.
  ///
  /// In ko, this message translates to:
  /// **'음독'**
  String get cardOn;

  /// No description provided for @searchKanji.
  ///
  /// In ko, this message translates to:
  /// **'검색'**
  String get searchKanji;

  /// No description provided for @searchHint.
  ///
  /// In ko, this message translates to:
  /// **'한자, 단어, 뜻, 읽기'**
  String get searchHint;

  /// No description provided for @noSearchResults.
  ///
  /// In ko, this message translates to:
  /// **'검색 결과가 없습니다'**
  String get noSearchResults;

  /// No description provided for @alwaysShowOn.
  ///
  /// In ko, this message translates to:
  /// **'이제부터 정답을 보여 줍니다'**
  String get alwaysShowOn;

  /// No description provided for @alwaysShowOff.
  ///
  /// In ko, this message translates to:
  /// **'이제부터 정답을 숨깁니다'**
  String get alwaysShowOff;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ja': return AppLocalizationsJa();
    case 'ko': return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}

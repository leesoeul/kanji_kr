import 'app_localizations.dart';

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '漢字学習';

  @override
  String get homeTitle => 'ホーム';

  @override
  String get todayReview => '今日の復習';

  @override
  String reviewCount(int count) {
    return '$count枚';
  }

  @override
  String get continueLearning => '続きから学ぶ';

  @override
  String get noReviews => '今日復習するカードはありません';

  @override
  String get onYomi => '音読み';

  @override
  String get kunYomi => '訓読み';

  @override
  String get koreanMeaning => '韓国語の意味';

  @override
  String get koreanHanja => '韓国漢字';

  @override
  String get examples => '例文';

  @override
  String get kanjiList => '漢字一覧';

  @override
  String get settings => '設定';

  @override
  String get quizComingSoon => 'クイズは近日公開です';

  @override
  String jlptLevel(String level) {
    return 'JLPT $level';
  }

  @override
  String strokeCountLabel(int count) {
    return '画数 $count';
  }

  @override
  String get uiLanguage => 'UI言語';

  @override
  String get learningLevel => '学習レベル';

  @override
  String get favorites => 'お気に入り';

  @override
  String get noFavorites => 'お気に入りの漢字はありません';

  @override
  String favoriteCount(int count) {
    return '$count字';
  }

  @override
  String get addKanji => '漢字を追加';

  @override
  String get editKanji => '漢字を編集';

  @override
  String get literalLabel => '漢字';

  @override
  String get meaningHint => '例: 山';

  @override
  String get onYomiHint => '例: さん';

  @override
  String get kunYomiHint => '例: やま';

  @override
  String get koreanHanjaHint => '空なら漢字と同じ';

  @override
  String get exampleJp => '例文（日本語）';

  @override
  String get exampleKo => '例文（韓国語）';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get cancel => 'キャンセル';

  @override
  String get deleteKanjiConfirm => 'この漢字を削除しますか？';

  @override
  String get alreadyExists => 'すでに登録されている漢字です';

  @override
  String get requiredField => '必須項目です';

  @override
  String get userKanji => 'マイ漢字';

  @override
  String get bookmarkAdd => 'お気に入り';

  @override
  String get bookmarkRemove => 'お気に入り解除';

  @override
  String get added => '追加しました';

  @override
  String get saved => '保存しました';

  @override
  String get studyTitle => '漢字を覚えよう！';

  @override
  String get showAnswer => '答え';

  @override
  String get hint => 'ヒント';

  @override
  String get cardKun => '訓読み';

  @override
  String get cardOn => '音読み';

  @override
  String get searchKanji => '検索';

  @override
  String get searchHint => '漢字・意味・読み';

  @override
  String get noSearchResults => '検索結果がありません';

  @override
  String get alwaysShowOn => 'これから答えを表示します';

  @override
  String get alwaysShowOff => 'これから答えを隠します';
}

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
  String get examples => '例文';

  @override
  String get kanjiList => '一覧';

  @override
  String get settings => '設定';

  @override
  String get quizComingSoon => 'クイズは近日公開です';

  @override
  String get quizTitle => 'クイズ';

  @override
  String get listUser => '追加したカード';

  @override
  String get shuffle => 'ランダム';

  @override
  String get shuffled => '順番を混ぜました';

  @override
  String get kindKanji => '漢字';

  @override
  String get kindWord => '単語';

  @override
  String get kindVerb => '動詞';

  @override
  String get pickKindTitle => '漢字 / 動詞';

  @override
  String get pickListTitle => '一覧を選んでください';

  @override
  String get readingLabel => '読み';

  @override
  String get readingHint => '例: やまのぼり';

  @override
  String get surfaceLabel => '表記';

  @override
  String get quizStart => '開始';

  @override
  String get quizNext => '次へ';

  @override
  String get quizSeeResult => '結果を見る';

  @override
  String get quizResult => '結果';

  @override
  String quizScore(int correct, int total) {
    return '$correct / $total';
  }

  @override
  String get quizRetry => 'もう一度';

  @override
  String get quizCorrect => '正解';

  @override
  String get quizWrong => '不正解';

  @override
  String get quizEmpty => 'この一覧ではクイズを作れません';

  @override
  String get quizPickMeaning => '意味を選んでください';

  @override
  String get quizPickLiteral => '表記を選んでください';

  @override
  String get quizModeMeaning => '意味';

  @override
  String get quizModeLiteral => '表記';

  @override
  String quizProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get addItem => '追加';

  @override
  String get addWord => '単語を追加';

  @override
  String get emptyList => 'この一覧は空です';

  @override
  String get cardReading => '読み';

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
  String get deleteKanjiConfirm => 'この項目を削除しますか？';

  @override
  String get alreadyExists => 'すでに登録されている項目です';

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
  String get cardKun => '訓読み';

  @override
  String get cardOn => '音読み';

  @override
  String get searchKanji => '検索';

  @override
  String get searchHint => '漢字・単語・意味・読み';

  @override
  String get noSearchResults => '検索結果がありません';

  @override
  String get alwaysShowOn => 'これから答えを表示します';

  @override
  String get alwaysShowOff => 'これから答えを隠します';

  @override
  String get aiAutocomplete => 'AI自動補完';

  @override
  String get aiSuggestions => 'AI推薦';

  @override
  String get aiLoadingSuggestions => 'AIが推薦中...';

  @override
  String get fillWithThis => 'この内容で埋める';

  @override
  String get requiredFieldMark => '*';

  @override
  String get resetForm => 'リセット';

  @override
  String get resetFormConfirm => '入力した内容をすべて削除しますか？';
}

import 'package:flutter/material.dart';

/// 사쿠라 핑크 테마. 라이트는 블러시 배경, 다크는 seed에서 만든 ColorScheme.
///
/// 카드 테두리·정답 버튼·진행 pill 색은 학습 화면에서 상수로 직접 참조한다.
class AppTheme {
  static const Color blushBg = Color(0xFFFFF4F7);
  static const Color meaningPink = Color(0xFFE85A7B);
  static const Color cardBorder = Color(0xFFFFC2D4);
  static const Color answerPill = Color(0xFFFFB4C8);
  static const Color progressPill = Color(0xFFFFE0EA);
  static const Color sakura = Color(0xFFF48FB1);
  static const Color creamCard = Color(0xFFFFFBFC);
  static const Color _seed = Color(0xFFF48FB1);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    return _base(
      scheme.copyWith(
        surface: blushBg,
        primary: sakura,
        secondary: meaningPink,
      ),
      blushBg,
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return _base(scheme, scheme.surface);
  }

  static ThemeData _base(ColorScheme scheme, Color scaffold) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffold,
        indicatorColor: progressPill.withOpacity(0.9),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 96,
          fontWeight: FontWeight.w500,
          height: 1.1,
        ),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
      ),
    );
  }
}

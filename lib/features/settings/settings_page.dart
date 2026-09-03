import 'package:flutter/material.dart';

import '../../core/constants/jlpt.dart';
import '../../core/l10n/generated/app_localizations.dart';

/// 하단 탭에 아직 안 붙인 설정 화면. `/settings`로만 들어온다.
/// 언어·레벨은 표시만 하고, 실제 전환은 없다 (UI는 한국어 고정).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.uiLanguage),
            subtitle: const Text('한국어'),
          ),
          ListTile(
            title: Text(l10n.learningLevel),
            subtitle: Text(l10n.jlptLevel(JlptLevel.n5.label)),
          ),
        ],
      ),
    );
  }
}

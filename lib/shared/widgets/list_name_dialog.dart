import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';

/// 목록 이름을 묻는다. 비우거나 닫으면 null.
Future<String?> askListName(
  BuildContext context, {
  required String title,
  String initial = '',
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _ListNameDialog(title: title, initial: initial),
  );
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

/// 컨트롤러는 다이얼로그 State가 사라질 때 버린다. 닫히는 애니메이션 중에 dispose하면 에러가 난다.
class _ListNameDialog extends StatefulWidget {
  const _ListNameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.listNameLabel),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

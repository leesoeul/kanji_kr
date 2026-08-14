import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/kana.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/kanji.dart';
import 'kanji_search_sheet.dart';

/// 홈 플래시카드. 정답은 카드가 아니라 아래 버튼으로만 연다.
/// ホームのフラッシュカード。答えはカードではなく下のボタンだけで開く。
class StudyPage extends ConsumerStatefulWidget {
  const StudyPage({
    super.key,
    this.initialId,
    this.showBack = false,
  });

  final String? initialId;
  final bool showBack;

  @override
  ConsumerState<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends ConsumerState<StudyPage> {
  final _pageController = PageController();
  int _index = 0;
  /// 이 세션에서 정답을 연 카드 인덱스. 항상표시 ON이면 쓰지 않는다.
  /// このセッションで答えを開いたカードindex。常時表示ONなら使わない。
  final Set<int> _revealed = {};
  /// 힌트(뜻만)를 연 카드. 정답보다 약한 공개.
  /// ヒント(意味だけ)を開いたカード。答えより弱い公開。
  final Set<int> _hinted = {};
  bool _didJump = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpTo(int index, int total) {
    if (total == 0) {
      return;
    }
    final next = index.clamp(0, total - 1);
    setState(() => _index = next);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(studyPrefsProvider);
    final asyncCatalog = ref.watch(catalogControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: asyncCatalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (catalog) {
            final kanjis = catalog.kanjis;
            if (kanjis.isEmpty) {
              return Center(child: Text(l10n.noSearchResults));
            }
            if (!_didJump && widget.initialId != null) {
              // `/kanji/:id`로 들어왔을 때 해당 장으로 점프. 한 번만.
              // `/kanji/:id` で入ったとき該当ページへジャンプ。一度だけ。
              final found =
                  kanjis.indexWhere((item) => item.id == widget.initialId);
              if (found >= 0) {
                _index = found;
                _didJump = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(found);
                  }
                });
              }
            }
            final safeIndex = _index.clamp(0, kanjis.length - 1);
            final kanji = kanjis[safeIndex];
            final showAnswer =
                prefs.alwaysShowAnswer || _revealed.contains(_index);
            final showHint = showAnswer || _hinted.contains(_index);

            return Column(
              children: [
                _StudyHeader(
                  showBack: widget.showBack,
                  title: l10n.studyTitle,
                  current: safeIndex + 1,
                  total: kanjis.length,
                  isDark: prefs.isDark,
                  onBack: () => context.pop(),
                  onToggleDark: () =>
                      ref.read(studyPrefsProvider.notifier).toggleDark(),
                  onSearch: () => _openSearch(kanjis, l10n),
                ),
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: safeIndex == 0
                            ? null
                            : () => _jumpTo(safeIndex - 1, kanjis.length),
                        icon: const Icon(
                          Icons.chevron_left,
                          size: 40,
                          color: AppTheme.sakura,
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: kanjis.length,
                          onPageChanged: (value) {
                            setState(() => _index = value);
                          },
                          itemBuilder: (context, index) {
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final maxH = constraints.maxHeight * 0.95;
                                final maxW = constraints.maxWidth * 0.95;
                                // 세로 카드 비율. 높이가 넘치면 너비를 줄인다.
                                // 縦カード比。高さが溢れたら幅を減らす。
                                var width = maxW;
                                var height = width / 0.78;
                                if (height > maxH) {
                                  height = maxH;
                                  width = height * 0.78;
                                }
                                return Center(
                                  child: SizedBox(
                                    width: width,
                                    height: height,
                                    child: _KanjiFlashCard(
                                      kanji: kanjis[index],
                                      starred: catalog
                                          .isFavorite(kanjis[index].id),
                                      onStar: () => ref
                                          .read(
                                            catalogControllerProvider.notifier,
                                          )
                                          .toggleFavorite(kanjis[index].id),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: safeIndex >= kanjis.length - 1
                            ? null
                            : () => _jumpTo(safeIndex + 1, kanjis.length),
                        icon: const Icon(
                          Icons.chevron_right,
                          size: 40,
                          color: AppTheme.sakura,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 88,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: showHint
                        ? _AnswerBlock(
                            kanji: kanji,
                            showReadings: showAnswer,
                            l10n: l10n,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: l10n.hint,
                        onPressed: () => setState(() => _hinted.add(_index)),
                        icon: const Icon(
                          Icons.lightbulb_outline,
                          size: 28,
                          color: AppTheme.meaningPink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            if (_revealed.contains(_index)) {
                              _revealed.remove(_index);
                            } else {
                              _revealed.add(_index);
                            }
                          });
                        },
                        // 더블탭은 전역 설정. 카드가 아니라 이 버튼만 받는다.
                        // ダブルタップは全体設定。カードではなくこのボタンだけ受ける。
                        onDoubleTap: () => _toggleAlwaysShow(l10n),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.answerPill,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Text(
                            l10n.showAnswer,
                            style: const TextStyle(
                              color: Color(0xFF7A3048),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleAlwaysShow(AppLocalizations l10n) async {
    await ref.read(studyPrefsProvider.notifier).toggleAlwaysShowAnswer();
    if (!mounted) {
      return;
    }
    final on = ref.read(studyPrefsProvider).alwaysShowAnswer;
    setState(() {
      if (on) {
        // 항상 표시로 바뀌면 카드별 공개 상태는 의미가 없어진다.
        // 常時表示に変わるとカード別公開状態は意味がなくなる。
        _revealed.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(on ? l10n.alwaysShowOn : l10n.alwaysShowOff),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openSearch(List<Kanji> kanjis, AppLocalizations l10n) async {
    final selected = await showKanjiSearchSheet(
      context: context,
      kanjis: kanjis,
      l10n: l10n,
    );
    if (selected == null || !mounted) {
      return;
    }
    final index = kanjis.indexWhere((item) => item.id == selected.id);
    if (index >= 0) {
      _jumpTo(index, kanjis.length);
    }
  }
}

/// 제목 · 다크 토글 · `현재 / 전체` · 검색.
/// タイトル · ダーク切替 · `現在 / 全体` · 検索。
class _StudyHeader extends StatelessWidget {
  const _StudyHeader({
    required this.showBack,
    required this.title,
    required this.current,
    required this.total,
    required this.isDark,
    required this.onBack,
    required this.onToggleDark,
    required this.onSearch,
  });

  final bool showBack;
  final String title;
  final int current;
  final int total;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onToggleDark;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFE85A7B),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            onPressed: onToggleDark,
            icon: Icon(
              isDark ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
              color: AppTheme.sakura,
            ),
          ),
          Material(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : AppTheme.progressPill,
            borderRadius: BorderRadius.circular(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    '$current / $total',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: l10nSearch(context),
                  visualDensity: VisualDensity.compact,
                  onPressed: onSearch,
                  icon: const Icon(Icons.search, color: Color(0xFFE85A7B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String l10nSearch(BuildContext context) {
    return AppLocalizations.of(context).searchKanji;
  }
}

/// 한자만 크게. 뜻·읽기는 카드 밖 `_AnswerBlock`에 둔다.
/// 漢字だけ大きく。意味・読みはカード外の `_AnswerBlock` に置く。
class _KanjiFlashCard extends StatelessWidget {
  const _KanjiFlashCard({
    required this.kanji,
    required this.starred,
    required this.onStar,
  });

  final Kanji kanji;
  final bool starred;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : AppTheme.creamCard,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.cardBorder, width: 2),
      ),
      child: Stack(
        children: [
          Center(
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  kanji.literal,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: const Color(0xFF5C3A45),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: onStar,
              icon: Icon(
                starred ? Icons.favorite : Icons.favorite_border,
                color: AppTheme.meaningPink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 힌트=뜻만, 정답=뜻+훈독+음독(히라가나).
/// ヒント=意味だけ、答え=意味+訓読み+音読み(ひらがな)。
class _AnswerBlock extends StatelessWidget {
  const _AnswerBlock({
    required this.kanji,
    required this.showReadings,
    required this.l10n,
  });

  final Kanji kanji;
  final bool showReadings;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final meaning = kanji.meaningsKo.isEmpty
        ? kanji.koreanMeaning
        : kanji.meaningsKo.join(' ');
    final kun = kanji.kunYomi.map((item) => item.kana).join('・');
    final on = kanji.onYomi
        .map((item) => katakanaToHiragana(item.kana))
        .join('・');

    return Column(
      children: [
        Text(
          meaning,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.meaningPink,
                fontWeight: FontWeight.w700,
              ),
        ),
        if (showReadings) ...[
          const SizedBox(height: 6),
          Text(
            '${l10n.cardKun}: ${kun.isEmpty ? '—' : kun} / ${l10n.cardOn}: ${on.isEmpty ? '—' : on}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ],
    );
  }
}

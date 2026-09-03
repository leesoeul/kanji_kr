import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/kana.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/study_filter.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/kanji.dart';
import 'home_pickers.dart';
import 'kanji_search_sheet.dart';

/// 홈 플래시카드.
///
/// [StudySession]이 비어 있으면 [HomeBrowseBody] (한자/동사 → 목록).
/// 덱이 있으면 PageView로 카드를 넘긴다.
/// 정답은 카드를 탭하는 게 아니라 아래 분홍 버튼으로만 연다.
/// 더블탭은 "정답 항상 표시" 전역 설정.
///
/// [initialId]가 있으면 `/kanji/:id`로 들어온 것. 해당 장으로 점프하고 뒤로가기가 pop이다.
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
  final Set<int> _revealed = {};
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

  /// 덱을 바꾸면 첫 장으로. PageController는 프레임 뒤에 jump.
  void _resetDeck() {
    _index = 0;
    _revealed.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  /// 학습에 쓸 카드 배열. `/kanji/:id`면 카탈로그 전체에서 해당 id를 찾는다.
  List<Kanji> _deck(CatalogState catalog, StudySession session) {
    if (widget.initialId != null) {
      return catalog.kanjis;
    }
    final lists = catalog.dropdownLists(
      userTitle: '',
      favoritesTitle: '',
      kind: session.kind,
    );
    final listId = resolveListId(session.listId, lists);
    return withShuffle(
      catalog.itemsFor(listId, kind: session.kind),
      session.shuffleNonce,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(studyPrefsProvider);
    final session = ref.watch(studySessionProvider);
    final asyncCatalog = ref.watch(catalogControllerProvider);

    // 목록·셔플·종류가 바뀌면 덱을 처음부터 다시 본다.
    ref.listen<StudySession>(studySessionProvider, (prev, next) {
      if (widget.initialId != null) {
        return;
      }
      if (prev?.listId == next.listId &&
          prev?.shuffleNonce == next.shuffleNonce &&
          prev?.kind == next.kind) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(_resetDeck);
      });
    });

    // 시스템 뒤로가기: 카드 → 목록 고르기 → 종류 고르기. `/kanji/:id`만 진짜 pop.
    return PopScope(
      canPop: widget.showBack || (!session.hasKind && widget.initialId == null),
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        if (session.hasDeck) {
          ref.read(studySessionProvider.notifier).clearList();
        } else if (session.hasKind) {
          ref.read(studySessionProvider.notifier).clearKind();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: asyncCatalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('$error')),
            data: (catalog) {
              if (widget.initialId == null && !session.hasDeck) {
                return HomeBrowseBody(
                  catalog: catalog,
                  session: session,
                  isDark: prefs.isDark,
                );
              }
              final kanjis = _deck(catalog, session);
              final lists = catalog.dropdownLists(
                userTitle: l10n.listUser,
                favoritesTitle: l10n.favorites,
                kind: session.kind,
              );
              final listId = resolveListId(session.listId, lists);
              final currentList = catalog.listById(listId, dropdown: lists);
              final language = Localizations.localeOf(context).languageCode;
              final listTitle =
                  currentList?.titleFor(language) ?? l10n.studyTitle;
              final onHeaderBack = widget.showBack
                  ? () => context.pop()
                  : () => ref.read(studySessionProvider.notifier).clearList();
              if (kanjis.isEmpty) {
                //단어장이 비어있다
                return Column(
                  children: [
                    _StudyHeader(
                      showBack: true,
                      title: listTitle,
                      current: 0,
                      total: 0,
                      isDark: prefs.isDark,
                      canShuffle: false,
                      onBack: onHeaderBack,
                      onToggleDark: () =>
                          ref.read(studyPrefsProvider.notifier).toggleDark(),
                      onSearch: null,
                      onShuffle: null,
                    ),
                    Expanded(child: Center(child: Text(l10n.emptyList))),
                  ],
                );
              }
              if (!_didJump && widget.initialId != null) {
                // `/kanji/:id`로 들어왔을 때 해당 장으로 점프. 한 번만.
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

              return Column(
                children: [
                  _StudyHeader(
                    showBack: true,
                    title: listTitle,
                    current: safeIndex + 1,
                    total: kanjis.length,
                    isDark: prefs.isDark,
                    canShuffle: kanjis.length > 1 && widget.initialId == null,
                    onBack: onHeaderBack,
                    onToggleDark: () =>
                        ref.read(studyPrefsProvider.notifier).toggleDark(),
                    onSearch: () => _openSearch(kanjis, l10n),
                    onShuffle: () {
                      ref.read(studySessionProvider.notifier).shuffle();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.shuffled),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    flex: 5,
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
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                                child: _KanjiFlashCard(
                                  kanji: kanjis[index],
                                  starred: catalog.isFavorite(kanjis[index].id),
                                  onStar: () => ref
                                      .read(
                                        catalogControllerProvider.notifier,
                                      )
                                      .toggleFavorite(kanjis[index].id),
                                ),
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
                    height: 148,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: showAnswer
                          ? SingleChildScrollView(
                              child: _AnswerBlock(
                                kanji: kanji,
                                l10n: l10n,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Center(
                      child: GestureDetector(
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
                        // 더블탭은 전역 "항상 표시".
                        onDoubleTap: () => _toggleAlwaysShow(l10n),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.answerPill,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Text(
                            l10n.showAnswer,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF7A3048),
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              );
            },
          ),
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

/// 제목은 가운데 큰 글씨. 아래줄은 왼쪽 셔플·다크, 오른쪽 장수·검색.
class _StudyHeader extends StatelessWidget {
  const _StudyHeader({
    required this.showBack,
    required this.title,
    required this.current,
    required this.total,
    required this.isDark,
    required this.canShuffle,
    required this.onBack,
    required this.onToggleDark,
    required this.onSearch,
    required this.onShuffle,
  });

  final bool showBack;
  final String title;
  final int current;
  final int total;
  final bool isDark;
  final bool canShuffle;
  final VoidCallback onBack;
  final VoidCallback onToggleDark;
  final VoidCallback? onSearch;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFFE85A7B),
                        fontWeight: FontWeight.w700,
                        fontSize: 26,
                      ),
                ),
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: AppLocalizations.of(context).shuffle,
                onPressed: canShuffle ? onShuffle : null,
                icon: const Icon(
                  Icons.shuffle,
                  color: AppTheme.sakura,
                ),
              ),
              IconButton(
                onPressed: onToggleDark,
                icon: Icon(
                  isDark ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
                  color: AppTheme.sakura,
                ),
              ),
              const Spacer(),
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
                      tooltip: AppLocalizations.of(context).searchKanji,
                      visualDensity: VisualDensity.compact,
                      onPressed: onSearch,
                      icon: const Icon(Icons.search, color: Color(0xFFE85A7B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 한자·단어만 크게. 뜻·읽기는 카드 밖 [_AnswerBlock]에 둔다.
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
                        fontSize: kanji.isWord ? 72 : 96,
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

/// 정답: 뜻 + 읽기(단어) 또는 훈독 + 음독(한자). 힌트가 있으면 그 아래.
/// 슬롯 높이는 바깥 SizedBox(148)에서 고정하고, 길면 스크롤한다.
class _AnswerBlock extends StatelessWidget {
  const _AnswerBlock({
    required this.kanji,
    required this.l10n,
  });

  final Kanji kanji;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final meaning = kanji.displayMeaning;
    final readingLine = kanji.isWord
        ? '${l10n.cardReading}: ${kanji.displayReading.isEmpty ? '—' : kanji.displayReading}'
        : '${l10n.cardKun}: ${_kun()} / ${l10n.cardOn}: ${_on()}';
    final memo = kanji.hint.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          meaning,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.meaningPink,
            fontWeight: FontWeight.w700,
            fontSize: 28,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          readingLine,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            height: 1.3,
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.onSurface
                : const Color(0xFF5C3A45),
          ),
        ),
        if (memo.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            memo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.72),
            ),
          ),
        ],
      ],
    );
  }

  String _kun() {
    final kun = kanji.kunYomi.map((item) => item.kana).join('・');
    return kun.isEmpty ? '—' : kun;
  }

  String _on() {
    final on =
        kanji.onYomi.map((item) => katakanaToHiragana(item.kana)).join('・');
    return on.isEmpty ? '—' : on;
  }
}

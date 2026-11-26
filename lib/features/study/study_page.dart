import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/kana.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/study_filter.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/kanji.dart';
import '../../shared/models/study_list.dart';
import 'home_pickers.dart';
import 'kanji_search_sheet.dart';

/// 홈 플래시카드.
///
/// [listId]가 없으면 [HomeBrowseBody] (한자/동사 → 목록).
/// [listId]가 있으면 그 목록의 카드를 새 페이지로 보여 준다.
/// 정답은 아래 분홍 버튼으로만 연다. 한 번 탭은 지금 카드만, 넘기면 닫힌다.
/// 더블탭은 "정답 항상 표시". 고정 중에는 버튼이 자물쇠와 "정답 고정"이고, 한 번 탭하면 고정이 풀리며 답이 숨는다.
///
/// [initialId]가 있으면 `/kanji/:id`로 들어온 것. 해당 장으로 점프하고 뒤로가기가 pop이다.
class StudyPage extends ConsumerStatefulWidget {
  const StudyPage({
    super.key,
    this.listId,
    this.initialId,
    this.showBack = false,
    this.revealAnswer = false,
  });

  /// `/study/:listId`로 연 목록. 없으면 탭의 고르기 화면이다.
  final String? listId;
  final String? initialId;
  final bool showBack;

  /// 검색으로 들어온 카드는 정답을 펼친 채로 연다.
  final bool revealAnswer;

  @override
  ConsumerState<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends ConsumerState<StudyPage> {
  final _pageController = PageController();
  int _index = 0;

  /// 지금 카드의 정답만 열었는지. 넘기면 닫힌다. 고정이 켜져 있으면 넘긴 카드도 연다.
  bool _showCurrentAnswer = false;

  /// 이 화면에서만 유지되는 정답 고정. 저장하지 않는다.
  bool _alwaysShow = false;

  /// 검색·진입으로 연 카드는 넘김 직후에도 답을 연다.
  bool _revealAfterJump = false;

  /// 검색으로 연 카드만 답을 연다. 저장된 정답 고정은 건드리지 않는다.
  bool _searchReveal = false;
  bool _didJump = false;
  int _shuffleNonce = 0;

  bool _hasShownHint = false;

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
    _showCurrentAnswer = _alwaysShow;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  /// 덱과 제목이 같이 쓰는 (목록 id, 종류).
  /// `/kanji/:id`는 `?list=`가 없으면 그 카드가 속한 목록을 연다. 검색 탭·헤더 검색이 그렇다.
  (String, EntryKind?) _source(CatalogState catalog, StudySession session) {
    if (widget.initialId == null) {
      return (widget.listId ?? session.listId, session.kind);
    }
    final target = catalog.kanjis.cast<Kanji?>().firstWhere(
          (item) => item?.id == widget.initialId,
          orElse: () => null,
        );
    if (target == null) {
      return (widget.listId ?? '', session.kind);
    }
    return (widget.listId ?? target.listId, target.kind);
  }

  /// 학습에 쓸 카드 배열. `/kanji/:id`면 그 카드가 든 목록, 못 찾으면 카탈로그 전체.
  List<Kanji> _deck(CatalogState catalog, StudySession session) {
    final (listId, kind) = _source(catalog, session);
    if (widget.initialId != null) {
      final subDeck = catalog.itemsFor(listId, kind: kind);
      if (subDeck.any((item) => item.id == widget.initialId)) {
        return subDeck;
      }
      return catalog.kanjis;
    }
    return withShuffle(catalog.itemsFor(listId, kind: kind), _shuffleNonce);
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

    final pushed = widget.showBack || widget.listId != null;
    // 고르기 화면의 시스템 뒤로가기만 종류 선택으로. 카드 페이지는 pop.
    return PopScope(
      canPop: pushed || !session.hasKind,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || pushed) {
          return;
        }
        if (session.hasKind) {
          ref.read(studySessionProvider.notifier).clearKind();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: asyncCatalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('$error')),
            data: (catalog) {
              if (widget.initialId == null && widget.listId == null) {
                return HomeBrowseBody(
                  catalog: catalog,
                  session: session,
                  isDark: prefs.isDark,
                  openAs: ListOpenTarget.study,
                  titleOverride: l10n.homeTitle,
                );
              }
              final kanjis = _deck(catalog, session);
              final (sourceListId, sourceKind) = _source(catalog, session);
              final lists = catalog.dropdownLists(
                userTitle: defaultUserListTitle(l10n, sourceKind),
                favoritesTitle: l10n.favorites,
                kind: sourceKind,
              );
              final listId = resolveListId(sourceListId, lists);
              final currentList = catalog.listById(listId, dropdown: lists);
              final language = Localizations.localeOf(context).languageCode;
              final listTitle = currentList?.titleFor(language) ??
                  (sourceKind == EntryKind.word
                      ? l10n.kindWord
                      : l10n.kindKanji);
              void onHeaderBack() => context.pop();
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
                    Expanded(
                      child: Center(
                        child: Text(
                          emptyListMessage(
                            l10n,
                            listId: listId,
                            kind: sourceKind,
                          ),
                        ),
                      ),
                    ),
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
                  if (widget.revealAnswer) {
                    _showCurrentAnswer = true;
                    _revealAfterJump = true;
                    _searchReveal = true;
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_pageController.hasClients) {
                      _pageController.jumpToPage(found);
                    }
                  });
                }
              }
              final safeIndex = _index.clamp(0, kanjis.length - 1);
              final answerLocked = !_searchReveal && _alwaysShow;

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
                      setState(() {
                        _shuffleNonce = DateTime.now().millisecondsSinceEpoch;
                      });
                      _resetDeck();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.shuffled),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            // 카드 넘김만 본다. 예문 칸의 세로 스크롤은 답을 닫지 않는다.
                            if (notification is ScrollUpdateNotification &&
                                notification.metrics.axis == Axis.horizontal &&
                                _showCurrentAnswer &&
                                !_revealAfterJump &&
                                !_searchReveal &&
                                !_alwaysShow) {
                              setState(() => _showCurrentAnswer = false);
                            }
                            return false;
                          },
                          child: PageView.builder(
                          controller: _pageController,
                          itemCount: kanjis.length,
                          onPageChanged: (value) {
                            setState(() {
                              _index = value;
                              if (_revealAfterJump) {
                                _showCurrentAnswer = true;
                                _searchReveal = true;
                                _alwaysShow = false;
                              } else if (_searchReveal) {
                                _searchReveal = false;
                                _alwaysShow = false;
                                _showCurrentAnswer = false;
                              } else {
                                _showCurrentAnswer = _alwaysShow;
                              }
                              _revealAfterJump = false;
                            });
                          },
                          itemBuilder: (context, index) {
                            final pageKanji = kanjis[index];
                            final showAnswer = _searchReveal
                                ? _showCurrentAnswer
                                : _alwaysShow || _showCurrentAnswer;
                            return Column(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      52,
                                      24,
                                      52,
                                      8,
                                    ),
                                    child: _KanjiFlashCard(
                                      kanji: pageKanji,
                                      starred: catalog.isFavorite(pageKanji.id),
                                      onStar: () => ref
                                          .read(
                                            catalogControllerProvider.notifier,
                                          )
                                          .toggleFavorite(pageKanji.id),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 148,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      20,
                                      24,
                                      0,
                                    ),
                                    child: showAnswer
                                        ? SingleChildScrollView(
                                            child: _AnswerBlock(
                                              kanji: pageKanji,
                                              l10n: l10n,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                                _showAnswerButton(l10n, locked: answerLocked),
                                const Spacer(flex: 2),
                              ],
                            );
                          },
                        ),
                        ),
                        Positioned.fill(
                          child: Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: safeIndex == 0
                                          ? null
                                          : () => _jumpTo(
                                                safeIndex - 1,
                                                kanjis.length,
                                              ),
                                      icon: const Icon(
                                        Icons.chevron_left,
                                        size: 40,
                                        color: AppTheme.sakura,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: safeIndex >= kanjis.length - 1
                                          ? null
                                          : () => _jumpTo(
                                                safeIndex + 1,
                                                kanjis.length,
                                              ),
                                      icon: const Icon(
                                        Icons.chevron_right,
                                        size: 40,
                                        color: AppTheme.sakura,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const ExcludeSemantics(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: 0,
                                    child: SizedBox(height: 148),
                                  ),
                                ),
                              ),
                              ExcludeSemantics(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: 0,
                                    child: _showAnswerButton(
                                      l10n,
                                      locked: answerLocked,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(flex: 2),
                            ],
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
      ),
    );
  }

  Widget _showAnswerButton(AppLocalizations l10n, {required bool locked}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!_searchReveal && _alwaysShow) {
              _toggleAlwaysShow(l10n);
              return;
            }
            if (!_hasShownHint) {
              _hasShownHint = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.doubleTapHint),
                    duration: const Duration(seconds: 3),
                  ),
                );
              });
            }
            setState(() => _showCurrentAnswer = !_showCurrentAnswer);
          },
          onDoubleTap: () => _toggleAlwaysShow(l10n),
          child: Container(
            constraints: const BoxConstraints(minWidth: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: 48,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: locked ? const Color(0xFFFFF0F3) : AppTheme.answerPill,
              borderRadius: BorderRadius.circular(28),
              border: locked
                  ? Border.all(color: AppTheme.meaningPink, width: 1.5)
                  : null,
            ),
            child: locked
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 18,
                        color: AppTheme.meaningPink,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.showAnswerLocked,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.meaningPink,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  )
                : Text(
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
    );
  }

  void _toggleAlwaysShow(AppLocalizations l10n) {
    final on = !_alwaysShow;
    setState(() {
      _searchReveal = false;
      _alwaysShow = on;
      _showCurrentAnswer = on;
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
      _revealAfterJump = true;
      setState(() {
        _searchReveal = true;
        _alwaysShow = false;
        _showCurrentAnswer = true;
      });
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
      decoration: AppTheme.softCard(context, radius: 32),
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
    final example = kanji.examples.isEmpty ? null : kanji.examples.first;

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
        if (example != null &&
            (example.jp.isNotEmpty || example.ko.isNotEmpty)) ...[
          const SizedBox(height: 8),
          if (example.jp.isNotEmpty)
            Text(
              example.jp,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.82),
              ),
            ),
          if (example.ko.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              example.ko,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
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

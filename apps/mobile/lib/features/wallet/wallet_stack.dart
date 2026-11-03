import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../ui/softxu_controls.dart';
import 'card_links.dart';

/// Opens the account side menu from the header.
class WalletMenuHandle {
  VoidCallback? _open;

  /// Slides the account menu open when a [CardsStage] is showing it.
  void open() => _open?.call();

  void bind(VoidCallback open) => _open = open;

  void unbind(VoidCallback open) {
    if (identical(_open, open)) _open = null;
  }
}

/// Header control for [WalletMenuHandle]. Sits in the leading corner, the
/// same kind of bar button as Sign out.
class WalletMenuButton extends StatelessWidget {
  const WalletMenuButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.menu, semanticLabel: 'Menu');
    if (iphoneApp) {
      return CupertinoButton(
        key: const ValueKey('wallet-menu'),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: icon,
      );
    }
    return IconButton(
      key: const ValueKey('wallet-menu'),
      tooltip: 'Menu',
      iconSize: 26,
      onPressed: onPressed,
      icon: icon,
    );
  }
}

class WalletFact {
  const WalletFact({
    required this.field,
    required this.label,
    required this.value,
    this.extra,
  });

  final String field;
  final String label;
  final String value;
  final String? extra;
}

class WalletPass {
  const WalletPass({
    required this.label,
    this.detail,
    this.favourite = false,
    this.facts = const [],
    this.onOpen,
  });

  final String label;
  final String? detail;
  final bool favourite;
  final List<WalletFact> facts;
  final VoidCallback? onOpen;
}

/// The exported Cards stage.
///
/// Cards wait in the wallet. Open wallet deals them over 2300ms into the
/// vertical fan. Close wallet runs that deal backwards. Once the fan is open,
/// a vertical scroll eases the stack up or down. The card under the cursor,
/// or the first press on a card, opens that card halfway in its own slot.
/// That press does not open the detail. A later press, once the half-open
/// has settled, opens the full detail in place.
class CardsStage extends StatefulWidget {
  const CardsStage({
    super.key,
    required this.passes,
    required this.onAdd,
    required this.onScan,
    required this.onDesign,
    this.fromCache = false,
    this.notice,
    this.menu,
    this.menuHandle,
    this.openLink,
  });

  final List<WalletPass> passes;
  final VoidCallback onAdd;
  final VoidCallback onScan;
  final VoidCallback onDesign;
  final bool fromCache;
  final String? notice;

  /// Account actions. Hidden until the header menu button opens them.
  final Widget? menu;

  /// Header control that opens [menu]. The stage still draws the panel.
  final WalletMenuHandle? menuHandle;

  /// Opens a fact's map, chat, or profile link. Defaults to [launchCardLink].
  /// Callers may still pass a launcher. A fan press does not open a full-screen card.
  // ignore: unused_field
  final CardLinkLauncher? openLink;

  @override
  State<CardsStage> createState() => _CardsStageState();
}

class _CardsStageState extends State<CardsStage> with TickerProviderStateMixin {
  static const _introMs = 2300;
  static const _wallet = Color(0xFFDD1331);
  static const _ink = Color(0xFFF4F1EA);

  late final AnimationController _deal;
  late final AnimationController _half;
  late final AnimationController _scrollAnim;

  int? _hover;
  int? _pinned;
  int? _halfIndex;

  /// Movement past this counts as a drag, so the fan scrolls and the card
  /// does not half-open or open. Kept inside the tap slop (18px).
  static const _pressSlop = 16.0;
  double _pressTravel = 0;
  double _pressDy = 0;
  bool _pressDrag = false;
  var _menuOpen = false;
  VoidCallback? _showMenu;
  double _scroll = 0;
  double _scrollFrom = 0;
  double _scrollTarget = 0;
  double _scrollLimit = 180;

  @override
  void initState() {
    super.initState();
    _deal =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: _introMs),
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _half =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 220),
          )
          ..addListener(() {
            if (mounted) setState(() {});
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.dismissed &&
                _hover == null &&
                _pinned == null &&
                mounted) {
              setState(() => _halfIndex = null);
            }
          });
    _scrollAnim =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          if (!mounted) return;
          final t = Curves.easeOutCubic.transform(_scrollAnim.value);
          setState(() {
            _scroll = _scrollFrom + (_scrollTarget - _scrollFrom) * t;
          });
        });
    _bindMenu();
  }

  @override
  void didUpdateWidget(CardsStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.menuHandle, widget.menuHandle) ||
        (oldWidget.menu == null) != (widget.menu == null)) {
      _unbindMenu(oldWidget.menuHandle);
      _bindMenu();
    }
  }

  void _bindMenu() {
    final handle = widget.menuHandle;
    if (handle == null || widget.menu == null) return;
    void show() {
      if (!mounted || _menuOpen) return;
      setState(() => _menuOpen = true);
    }

    _showMenu = show;
    handle.bind(show);
  }

  void _unbindMenu(WalletMenuHandle? handle) {
    final show = _showMenu;
    if (handle != null && show != null) handle.unbind(show);
    _showMenu = null;
  }

  @override
  void dispose() {
    _unbindMenu(widget.menuHandle);
    _deal.dispose();
    _half.dispose();
    _scrollAnim.dispose();
    super.dispose();
  }

  double get _intro => _deal.value;

  void _open() {
    if (_deal.isAnimating || _deal.value >= 1) return;
    _deal.forward();
  }

  void _close() {
    if (_deal.isAnimating || _deal.value <= 0) return;
    _scroll = 0;
    _scrollFrom = 0;
    _scrollTarget = 0;
    _scrollAnim.stop();
    _pinned = null;
    _hover = null;
    _collapseLift();
    _deal.reverse();
  }

  double _openAmount(int index) {
    if (_intro < 1 || _halfIndex != index) return 0;
    return Curves.easeOutCubic.transform(_half.value);
  }

  void _nudgeScroll(double dy) {
    if (_intro < 1 || _menuOpen || dy == 0) return;
    _scrollFrom = _scroll;
    final limit = _scrollLimit;
    _scrollTarget = (_scrollTarget + dy).clamp(-limit, limit).toDouble();
    _scrollAnim.forward(from: 0);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _nudgeScroll(event.scrollDelta.dy);
    }
  }

  void _onPanZoom(PointerPanZoomUpdateEvent event) {
    _nudgeScroll(event.panDelta.dy);
  }

  void _onFanPointerDown(PointerDownEvent event) {
    _pressTravel = 0;
    _pressDy = 0;
    _pressDrag = false;
  }

  void _onFanPointerMove(PointerMoveEvent event) {
    if (!event.down) return;
    _pressTravel += event.delta.distance;
    if (_pressTravel < _pressSlop) {
      _pressDy += event.delta.dy;
      return;
    }
    final dy = _pressDy + event.delta.dy;
    _pressDy = 0;
    _pressDrag = true;
    if (dy != 0) _nudgeScroll(dy);
  }

  /// A press that is not a drag half-opens [index] in the fan.
  /// It never covers the screen with a full card.
  void _pressCard(int index) {
    if (_pressDrag || _intro < 1 || _menuOpen) return;
    if (_pinned == index) {
      _aimLift(index);
      return;
    }
    _beginHalfOpen(index);
  }

  void _beginHalfOpen(int index) {
    _pinned = index;
    _aimLift(index);
  }

  void _setHover(int? index) {
    if (index == _hover) return;
    _hover = index;
    _aimLift(_hover ?? _pinned);
  }

  void _aimLift(int? index) {
    if (index == null) {
      _collapseLift();
      return;
    }
    if (_halfIndex == index) {
      if (_half.value < 1 && _half.status != AnimationStatus.forward) {
        _half.forward();
      }
      return;
    }
    if (_halfIndex != null && _half.value > 0) {
      _half.value = 0;
    }
    setState(() => _halfIndex = index);
    _half.forward();
  }

  void _collapseLift() {
    if (_half.value > 0) {
      _half.reverse();
    } else if (_halfIndex != null) {
      setState(() => _halfIndex = null);
    }
  }

  _Deck _present(_Deck deck) {
    final active = _intro >= 1;
    final scroll = active ? _scroll : 0.0;
    final halfIndex = _halfIndex;
    final openT = active && halfIndex != null
        ? Curves.easeOutCubic.transform(_half.value)
        : 0.0;
    if (scroll == 0 && openT == 0) return deck;
    final cards = <_Placed>[
      for (final card in deck.cards)
        _Placed(
          index: card.index,
          cx: card.cx,
          cy: card.cy + scroll,
          width: card.width,
          height: card.height,
          scale: card.scale,
        ),
    ];
    if (halfIndex != null &&
        openT > 0 &&
        halfIndex >= 0 &&
        halfIndex < cards.length - 1) {
      final host = cards[halfIndex];
      final hostTop = host.cy - host.height / 2;
      final hostBottom = hostTop + host.height * (1 + 0.5 * openT);
      final belowTop =
          cards[halfIndex + 1].cy - cards[halfIndex + 1].height / 2;
      final extra = math.max(0.0, hostBottom - belowTop);
      if (extra > 0) {
        for (var i = halfIndex + 1; i < cards.length; i++) {
          final card = cards[i];
          cards[i] = _Placed(
            index: card.index,
            cx: card.cx,
            cy: card.cy + extra,
            width: card.width,
            height: card.height,
            scale: card.scale,
          );
        }
      }
    }
    return _Deck(
      cards: cards,
      walletTop: deck.walletTop,
      walletW: deck.walletW,
      seam: deck.seam,
      wordmarkTop: deck.wordmarkTop,
      wordmarkSize: deck.wordmarkSize,
      floor: deck.floor,
      buttonHeight: deck.buttonHeight,
      buttonGap: deck.buttonGap,
      buttonPad: deck.buttonPad,
      headerHeight: deck.headerHeight,
    );
  }

  Rect _strip(_Placed placed, _Deck deck) {
    final open = _openAmount(placed.index);
    if (open > 0) {
      final grow = 1 + 0.5 * open;
      return Rect.fromLTWH(
        placed.cx - placed.width * grow / 2,
        placed.cy - placed.height / 2,
        placed.width * grow,
        placed.height * grow,
      );
    }
    final box = Rect.fromCenter(
      center: Offset(placed.cx, placed.cy),
      width: placed.width,
      height: placed.height,
    );
    final top = placed.cy - placed.height * placed.scale / 2;
    final full = placed.height * placed.scale;
    var height = full;
    if (placed.index + 1 < deck.cards.length) {
      final next = deck.cards[placed.index + 1];
      final nextTop = next.cy - next.height * next.scale / 2;
      height = (nextTop - top).clamp(1.0, full);
    }
    final visual = Rect.fromLTWH(
      placed.cx - placed.width * placed.scale / 2,
      top,
      placed.width * placed.scale,
      height,
    );
    final hit = visual.intersect(box);
    if (hit.isEmpty) {
      return Rect.fromLTWH(
        box.left,
        box.top,
        box.width,
        math.min(36, box.height),
      );
    }
    return hit;
  }

  int? _indexAt(Offset local, _Deck deck) {
    for (var i = deck.cards.length - 1; i >= 0; i--) {
      if (_strip(deck.cards[i], deck).contains(local)) {
        return deck.cards[i].index;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageW = constraints.maxWidth;
        final stageH = constraints.maxHeight;
        final viewport = MediaQuery.sizeOf(context);
        final phone = viewport.width < 760;
        final laidOut = _layout(
          stageW: stageW,
          stageH: stageH,
          viewportW: viewport.width,
          phone: phone,
          count: widget.passes.length,
          intro: _intro,
        );
        final cardH = laidOut.cards.isEmpty
            ? 180.0
            : laidOut.cards.first.height;
        _scrollLimit = math.max(72, math.min(stageH * 0.34, cardH * 0.8));
        final deck = _present(laidOut);
        final closing = _deal.status == AnimationStatus.reverse;
        final done = _intro >= 1 && !closing;
        final label = done || closing ? 'Close wallet' : 'Open wallet';
        final showWallet = _intro < 1;

        final openingIndex = _halfIndex != null && _half.value > 0
            ? _halfIndex
            : null;

        return PopScope(
          canPop: !_menuOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !_menuOpen) return;
            setState(() => _menuOpen = false);
          },
          child: Listener(
            onPointerSignal: _onPointerSignal,
            onPointerPanZoomUpdate: _onPanZoom,
            child: MouseRegion(
              onHover: (event) => _trackHover(event.localPosition, deck),
              onExit: (_) => _setHover(null),
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: _onFanPointerDown,
                          onPointerMove: _onFanPointerMove,
                          child: Stack(
                            children: [
                              const Positioned.fill(child: SizedBox.expand()),
                              if (showWallet) _walletBack(deck, stageW, stageH),
                              for (final placed in deck.cards)
                                if (placed.index != openingIndex)
                                  _card(placed, deck),
                              if (openingIndex != null &&
                                  openingIndex < deck.cards.length)
                                _card(deck.cards[openingIndex], deck),
                              if (showWallet)
                                _walletFront(deck, stageW, stageH),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: deck.wordmarkTop,
                        left: 12,
                        right: 12,
                        child: _WalletHeader(
                          wordmarkSize: deck.wordmarkSize,
                          buttonHeight: deck.buttonHeight,
                          buttonGap: deck.buttonGap,
                          buttonPad: deck.buttonPad,
                          onAdd: widget.onAdd,
                          onScan: widget.onScan,
                          onDesign: widget.onDesign,
                        ),
                      ),
                      if (widget.fromCache || widget.notice != null)
                        Positioned(
                          top: deck.wordmarkTop + deck.headerHeight + 4,
                          left: 24,
                          right: 24,
                          child: Text(
                            widget.fromCache
                                ? 'Saved on this device. These cards may be out of date.'
                                : widget.notice!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Positioned(
                        right: phone ? 12 : 18,
                        top: deck.floor + 8,
                        child: _Pill(
                          label: label,
                          height: phone ? 36 : 40,
                          scale: 1,
                          onPressed: _deal.isAnimating
                              ? null
                              : () {
                                  if (_intro >= 1) {
                                    _close();
                                  } else {
                                    _open();
                                  }
                                },
                        ),
                      ),
                      if (_menuOpen && widget.menu != null)
                        Positioned.fill(
                          child: _SideMenu(
                            onClose: () => setState(() => _menuOpen = false),
                            child: widget.menu!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card(_Placed placed, _Deck deck) {
    final open = _openAmount(placed.index);
    final grow = 1 + 0.5 * open;
    final boxTop = placed.cy - placed.height / 2;
    final boxLeft = placed.cx - placed.width * grow / 2;
    final boxWidth = placed.width * grow;
    final boxHeight = placed.height * grow;
    final strip = _strip(placed, deck);
    return Positioned(
      left: boxLeft,
      top: boxTop,
      width: boxWidth,
      height: boxHeight,
      child: _HoverCard(
        key: ValueKey('wallet-pass-${placed.index}'),
        pass: widget.passes[placed.index],
        palette: _palettes[placed.index % _palettes.length],
        showBack: placed.index.isOdd,
        scale: placed.scale,
        scaleAlignment: open > 0 ? Alignment.topCenter : Alignment.center,
        stripTop: strip.top - boxTop,
        stripLeft: strip.left - boxLeft,
        stripWidth: strip.width,
        stripHeight: strip.height,
        interactive: _intro >= 1,
        onTap: () => _pressCard(placed.index),
      ),
    );
  }

  void _trackHover(Offset local, _Deck deck) {
    if (_intro < 1 || _menuOpen) {
      _setHover(null);
      return;
    }
    _setHover(_indexAt(local, deck));
  }

  Widget _walletBack(_Deck deck, double stageW, double stageH) {
    final fade = _fade(_intro);
    final drop = _drop(_intro);
    return Positioned(
      left: (stageW - deck.walletW) / 2,
      top: deck.walletTop + drop,
      width: deck.walletW,
      height: math.max(0, stageH - deck.walletTop + 48),
      child: Opacity(
        opacity: fade,
        child: GestureDetector(
          key: const ValueKey('wallet-pocket'),
          onTap: _intro == 0 ? _open : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _wallet,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
                bottom: Radius.circular(34),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x6B000000),
                  blurRadius: 50,
                  offset: Offset(0, 28),
                ),
                BoxShadow(
                  color: Color(0x47000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const CustomPaint(painter: _StitchPainter()),
          ),
        ),
      ),
    );
  }

  Widget _walletFront(_Deck deck, double stageW, double stageH) {
    final fade = _fade(_intro);
    final drop = _drop(_intro);
    final top = deck.walletTop + deck.seam + drop;
    return Positioned(
      left: (stageW - deck.walletW) / 2,
      top: top,
      width: deck.walletW,
      height: math.max(0, stageH - deck.walletTop - deck.seam + 48),
      child: Opacity(
        opacity: fade,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: _wallet,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(8),
                bottom: Radius.circular(34),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x57000000),
                  blurRadius: 16,
                  offset: Offset(0, 12),
                ),
                BoxShadow(
                  color: Color(0x61000000),
                  blurRadius: 36,
                  offset: Offset(0, 22),
                ),
              ],
            ),
            child: Stack(
              children: [
                const CustomPaint(painter: _StitchPainter()),
                Positioned(
                  left: deck.walletW * 0.08,
                  right: deck.walletW * 0.08,
                  top: 0,
                  height: 18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _wallet,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x73000000),
                          blurRadius: 16,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: deck.walletW / 2 - 46,
                  top: 18,
                  width: 92,
                  height: 16,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: _wallet,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// IncardIt on the left, with Add, Scan, and Design on the same row.
class _WalletHeader extends StatelessWidget {
  const _WalletHeader({
    required this.wordmarkSize,
    required this.buttonHeight,
    required this.buttonGap,
    required this.buttonPad,
    required this.onAdd,
    required this.onScan,
    required this.onDesign,
  });

  final double wordmarkSize;
  final double buttonHeight;
  final double buttonGap;
  final double buttonPad;
  final VoidCallback onAdd;
  final VoidCallback onScan;
  final VoidCallback onDesign;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'IncardIt',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: wordmarkSize,
              height: 1,
              letterSpacing: wordmarkSize * -0.03,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0F0F0F),
            ),
          ),
          SizedBox(width: buttonGap + 2),
          _Pill(
            label: 'Add+',
            height: buttonHeight,
            horizontalPadding: buttonPad,
            onPressed: onAdd,
          ),
          SizedBox(width: buttonGap),
          _Pill(
            label: 'Scan',
            height: buttonHeight,
            horizontalPadding: buttonPad,
            onPressed: onScan,
          ),
          SizedBox(width: buttonGap),
          _Pill(
            label: 'Design',
            height: buttonHeight,
            horizontalPadding: buttonPad,
            onPressed: onDesign,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.height,
    required this.onPressed,
    this.scale = 1,
    this.horizontalPadding,
  });

  final String label;
  final double height;
  final double scale;
  final double? horizontalPadding;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF9E2E2E),
      shape: StadiumBorder(
        side: BorderSide(
          color: const Color(0xFFF4F1EA).withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height, maxHeight: height),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding ?? 16 * scale,
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: _CardsStageState._ink,
                  fontSize:
                      ((height / 3).clamp(12, 14) * (scale == 1 ? 1 : 0.9))
                          .toDouble(),
                  letterSpacing: 0.56,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = math.min(300.0, MediaQuery.sizeOf(context).width * 0.84);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Color(0x590F0F0F)),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: width,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -1, end: 0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, dx, child) {
              return FractionalTranslation(
                translation: Offset(dx, 0),
                child: child,
              );
            },
            child: Material(
              color: const Color(0xFFF4F1EA),
              elevation: 16,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          key: const ValueKey('wallet-menu-close'),
                          tooltip: 'Close menu',
                          onPressed: onClose,
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF9E2E2E),
                          ),
                        ),
                      ),
                      Expanded(child: SingleChildScrollView(child: child)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HoverCard extends StatelessWidget {
  const _HoverCard({
    super.key,
    required this.pass,
    required this.palette,
    required this.showBack,
    required this.scale,
    required this.scaleAlignment,
    required this.stripTop,
    required this.stripLeft,
    required this.stripWidth,
    required this.stripHeight,
    required this.interactive,
    required this.onTap,
  });

  final WalletPass pass;
  final _Palette palette;
  final bool showBack;
  final double scale;
  final Alignment scaleAlignment;
  final double stripTop;
  final double stripLeft;
  final double stripWidth;
  final double stripHeight;
  final bool interactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: Transform.scale(
            scale: scale,
            alignment: scaleAlignment,
            child: _FanCard(pass: pass, palette: palette, showBack: showBack),
          ),
        ),
        if (interactive && stripWidth > 0 && stripHeight > 0)
          Positioned(
            left: stripLeft,
            top: stripTop,
            width: stripWidth,
            height: stripHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
            ),
          ),
      ],
    );
  }
}

class _FanCard extends StatelessWidget {
  const _FanCard({
    required this.pass,
    required this.palette,
    required this.showBack,
  });

  final WalletPass pass;
  final _Palette palette;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final face = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: showBack ? palette.field : palette.paper),
          CustomPaint(painter: _FacePainter(palette, showBack)),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, _fanPadTop, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pass.label.isNotEmpty)
                    Text(
                      pass.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: showBack ? palette.light : palette.ink,
                        fontSize: _fanNameSize,
                        height: _fanNameHeight,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  if (pass.detail != null && pass.detail!.isNotEmpty)
                    Text(
                      pass.detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: showBack ? palette.light : palette.ink,
                        fontSize: _fanDetailSize,
                        height: _fanDetailHeight,
                      ),
                    ),
                  if (pass.favourite)
                    Text(
                      'Favourite',
                      style: TextStyle(
                        color: showBack ? palette.light : palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x47000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: face,
    );
  }
}

class _Placed {
  const _Placed({
    required this.index,
    required this.cx,
    required this.cy,
    required this.width,
    required this.height,
    required this.scale,
  });

  final int index;
  final double cx;
  final double cy;
  final double width;
  final double height;
  final double scale;
}

class _Deck {
  const _Deck({
    required this.cards,
    required this.walletTop,
    required this.walletW,
    required this.seam,
    required this.wordmarkTop,
    required this.wordmarkSize,
    required this.floor,
    required this.buttonHeight,
    required this.buttonGap,
    required this.buttonPad,
    required this.headerHeight,
  });

  final List<_Placed> cards;
  final double walletTop;
  final double walletW;
  final double seam;
  final double wordmarkTop;
  final double wordmarkSize;
  final double floor;
  final double buttonHeight;
  final double buttonGap;
  final double buttonPad;
  final double headerHeight;
}

class _Metrics {
  const _Metrics({
    required this.stepX,
    required this.stepY,
    required this.ax,
    required this.ay,
    this.fit = 1,
    this.uniform = false,
  });

  final double stepX;
  final double stepY;
  final double ax;
  final double ay;

  /// Scale applied when a full-size fan would push the names off the stage.
  final double fit;

  /// Every card uses [fit] so a long fan can keep both text lines visible.
  final bool uniform;
}

const _fanPadTop = 8.0;
const _fanNameSize = 16.0;
const _fanNameHeight = 1.15;
const _fanDetailSize = 13.0;
const _fanDetailHeight = 1.2;

/// Top padding plus the name line and the category line, in card pixels.
const _fanHeader =
    _fanPadTop +
    _fanNameSize * _fanNameHeight +
    _fanDetailSize * _fanDetailHeight;

/// Extra pixels so the next card does not sit on the category.
const _fanHeaderSlack = 3.0;

_Deck _layout({
  required double stageW,
  required double stageH,
  required double viewportW,
  required bool phone,
  required int count,
  required double intro,
}) {
  // Phone cards fill the screen with a small inset (14px). On a 390px
  // phone that is 362px. The pocket is a few pixels wider (12px inset)
  // when that still fits. The header sits above the fan, so the cards
  // stay centered.
  final span = math.min(viewportW, stageW);
  const cardInset = 14.0;
  const pocketInset = 12.0;
  final cardW = phone
      ? math.max(0.0, span - cardInset * 2)
      : math.min(270.0, viewportW * 0.26);
  final cardH = cardW * 1.7;
  // Small enough that IncardIt, Add, Scan, and Design share one line.
  final wordmarkSize = phone
      ? (span * 0.066).clamp(22.0, 28.0).toDouble()
      : (span * 0.055).clamp(28.0, 52.0).toDouble();
  final buttonHeight = phone ? 32.0 : 40.0;
  final buttonGap = phone ? 6.0 : 10.0;
  final buttonPad = phone ? 9.0 : 16.0;
  final wordmarkTop = 8.0;
  final headerHeight = math.max(wordmarkSize, buttonHeight);
  final floor = wordmarkTop + headerHeight + 10;
  final walletTop = stageH * (phone ? 0.50 : 0.54);
  final seam = phone ? 48.0 : 78.0;
  final walletW = phone
      ? math.min(math.max(0.0, span - pocketInset * 2), cardW + 4)
      : math.min(460.0, viewportW * 0.42);
  final maxLeft = math.max(0.0, stageW - cardW);
  final cardLeft = ((stageW - cardW) / 2).clamp(0.0, maxLeft);
  final ax = stageW <= 0 ? 0.5 : (cardLeft + cardW / 2) / stageW;
  final m = _fitVertical(
    ax: ax,
    n: count,
    stageH: stageH,
    floor: floor,
    cardH: cardH,
  );
  final focus = math.max(0.0, (count - 1) * 0.46);
  final lipCy = walletTop + seam + 9;
  final pocketX = stageW / 2 - stageW * m.ax;
  final pocketY = lipCy + cardH * 0.5 - 26 - stageH * m.ay;
  final cards = <_Placed>[];
  for (var i = 0; i < count; i++) {
    final t = i - focus;
    var x = t * m.stepX;
    var y = t * m.stepY;
    var scale = _placedScale(i, count, m);
    if (intro < 1) {
      final fromFront = count - 1 - i;
      final gaps = math.max(1, count - 1);
      final start = 0.06 + fromFront * (0.58 / gaps);
      final rise = _ease((intro - start) / 0.3);
      final stack = math.min(18.0, fromFront * 1.6);
      final sx = pocketX + stack * 0.12;
      final sy = pocketY + stack * 0.45;
      x = sx + (x - sx) * rise;
      y = sy + (y - sy) * rise;
      scale = 0.96 + (scale - 0.96) * rise;
    }
    final hh = cardH * scale * 0.5;
    final cy = stageH * m.ay + y;
    final minCy = floor + hh;
    if (cy < minCy) y += minCy - cy;
    cards.add(
      _Placed(
        index: i,
        cx: stageW * m.ax + x,
        cy: stageH * m.ay + y,
        width: cardW,
        height: cardH,
        scale: scale,
      ),
    );
  }
  return _Deck(
    cards: cards,
    walletTop: walletTop,
    walletW: walletW,
    seam: seam,
    wordmarkTop: wordmarkTop,
    wordmarkSize: wordmarkSize,
    floor: floor,
    buttonHeight: buttonHeight,
    buttonGap: buttonGap,
    buttonPad: buttonPad,
    headerHeight: headerHeight,
  );
}

double _depthScale(int index, int count) {
  if (count <= 1) return 1;
  final focus = (count - 1) * 0.46;
  final t = index - focus;
  return (1 + t * 0.012).clamp(0.8, 1.08).toDouble();
}

double _placedScale(int index, int count, _Metrics m) {
  if (count <= 1) return 1;
  if (m.uniform) return m.fit;
  return _depthScale(index, count) * m.fit;
}

_Metrics _fitVertical({
  required double ax,
  required int n,
  required double stageH,
  required double floor,
  required double cardH,
}) {
  const fallback = _Metrics(stepX: 0, stepY: 48, ax: 0.5, ay: 0.46);
  if (n < 1 || cardH < 1 || stageH < 1) return fallback;
  const margin = 16.0;
  final room = stageH - margin - floor;
  final focus = math.max(0.0, (n - 1) * 0.46);

  double scaleOf(int i, double fit, bool uniform) {
    if (n <= 1) return 1;
    if (uniform) return fit;
    return _depthScale(i, n) * fit;
  }

  double stepFor(double fit, bool uniform) {
    if (n <= 1) return 0;
    var step = 0.0;
    for (var i = 0; i < n - 1; i++) {
      final s0 = scaleOf(i, fit, uniform);
      final s1 = scaleOf(i + 1, fit, uniform);
      final need =
          _fanHeader * s0 + (cardH / 2) * (s1 - s0) + _fanHeaderSlack * s0;
      if (need > step) step = need;
    }
    return step;
  }

  double stackHeight(double step, double fit, bool uniform) {
    final s0 = scaleOf(0, fit, uniform);
    final last = scaleOf(n - 1, fit, uniform);
    final hh0 = cardH * s0 / 2;
    final hhLast = cardH * last / 2;
    if (n <= 1) return _fanHeader * s0;
    return hh0 + (n - 1) * step - hhLast + _fanHeader * last;
  }

  var uniform = false;
  var fit = 1.0;
  var step = stepFor(fit, uniform);
  if (n > 1 && room <= 8) {
    step = math.min(step, 10);
  } else if (n > 1 && stackHeight(step, fit, uniform) > room) {
    // The gradient fan cannot show both lines without leaving the stage.
    // One shared scale keeps the name and category on every card.
    uniform = true;
    final unitStep = stepFor(1, true);
    final unitStack = stackHeight(unitStep, 1, true);
    fit = unitStack <= 0 ? 1 : (room / unitStack).clamp(0.62, 1.0).toDouble();
    step = stepFor(fit, true);
  }
  if (step < 0 || !step.isFinite) step = 0;

  double hhAt(int i) => cardH * scaleOf(i, fit, uniform) * 0.5;
  var ay = (floor + hhAt(0) - (0 - focus) * step) / stageH;
  if (!ay.isFinite) ay = 0.46;
  for (var i = 1; i < n; i++) {
    final top = stageH * ay + (i - focus) * step - hhAt(i);
    if (top < floor) ay += (floor - top) / stageH;
  }
  return _Metrics(
    stepX: 0,
    stepY: step,
    ax: ax,
    ay: ay,
    fit: fit,
    uniform: uniform,
  );
}

double _ease(double u) {
  final t = u.clamp(0.0, 1.0).toDouble();
  return 1 - math.pow(1 - t, 3).toDouble();
}

double _fade(double intro) {
  if (intro >= 1) return 0;
  if (intro < 0.8) return 1;
  return math.max(0, 1 - (intro - 0.8) / 0.2);
}

double _drop(double intro) {
  if (intro < 0.8) return 0;
  return ((intro - 0.8) / 0.2).clamp(0.0, 1.0).toDouble() * 140;
}

class _StitchPainter extends CustomPainter {
  const _StitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        10,
        10,
        math.max(0, size.width - 20),
        math.max(0, size.height - 20),
      ),
      const Radius.circular(20),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = const Color(0xB8D6B27A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 7, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 5;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Palette {
  const _Palette({
    required this.ink,
    required this.light,
    required this.paper,
    required this.panel,
    required this.notch,
    required this.ring,
    required this.dot,
    required this.field,
    required this.sweep,
    required this.squares,
  });

  final Color ink;
  final Color light;
  final Color paper;
  final Color panel;
  final Color notch;
  final Color ring;
  final Color dot;
  final Color field;
  final Color sweep;
  final List<Color> squares;
}

/// Dark ink for names and details. Both faces use it so text stays readable
/// on the light pastel paper.
const _cardText = Color(0xFF241C19);

const _palettes = <_Palette>[
  _Palette(
    ink: _cardText,
    light: _cardText,
    paper: Color(0xFFFDE8EF),
    panel: Color(0xFFF7D3DE),
    notch: Color(0xFFF3C6D4),
    ring: Color(0xFFE8AFC2),
    dot: Color(0xFFE09BB2),
    field: Color(0xFFFDE8EF),
    sweep: Color(0xFFF8D5E3),
    squares: [
      Color(0xFFF7D3DE),
      Color(0xFFF3C6D4),
      Color(0xFFFBE3EB),
      Color(0xFFEAB8C8),
    ],
  ),
  _Palette(
    ink: _cardText,
    light: _cardText,
    paper: Color(0xFFE7F7F0),
    panel: Color(0xFFD4EEE4),
    notch: Color(0xFFC6E6D8),
    ring: Color(0xFFA8D8C4),
    dot: Color(0xFF8ECAB2),
    field: Color(0xFFE7F7F0),
    sweep: Color(0xFFD7F0E4),
    squares: [
      Color(0xFFD4EEE4),
      Color(0xFFC6E6D8),
      Color(0xFFE5F6EE),
      Color(0xFFB6E0CE),
    ],
  ),
  _Palette(
    ink: _cardText,
    light: _cardText,
    paper: Color(0xFFFFF8E4),
    panel: Color(0xFFFBEAB4),
    notch: Color(0xFFF6E2A4),
    ring: Color(0xFFF0D48A),
    dot: Color(0xFFE6C56E),
    field: Color(0xFFFFF8E4),
    sweep: Color(0xFFF8E8B0),
    squares: [
      Color(0xFFFBEAB4),
      Color(0xFFF6E2A4),
      Color(0xFFFFF3D0),
      Color(0xFFF0D898),
    ],
  ),
  _Palette(
    ink: _cardText,
    light: _cardText,
    paper: Color(0xFFE8F3FD),
    panel: Color(0xFFD3E6F8),
    notch: Color(0xFFC5DCF5),
    ring: Color(0xFFAFCFF0),
    dot: Color(0xFF96BEE8),
    field: Color(0xFFE8F3FD),
    sweep: Color(0xFFD6E8FA),
    squares: [
      Color(0xFFD3E6F8),
      Color(0xFFC5DCF5),
      Color(0xFFE6F2FC),
      Color(0xFFB9D4F2),
    ],
  ),
  _Palette(
    ink: _cardText,
    light: _cardText,
    paper: Color(0xFFFFF1E6),
    panel: Color(0xFFFADCC8),
    notch: Color(0xFFF5D0B8),
    ring: Color(0xFFF0B992),
    dot: Color(0xFFE8A67A),
    field: Color(0xFFFFF1E6),
    sweep: Color(0xFFF8D7C4),
    squares: [
      Color(0xFFFADCC8),
      Color(0xFFF5D0B8),
      Color(0xFFFFE6D4),
      Color(0xFFF0C4A8),
    ],
  ),
  _Palette(
    ink: _cardText,
    light: _cardText,
    paper: Color(0xFFF4EEFB),
    panel: Color(0xFFE6D6F6),
    notch: Color(0xFFDCC8F2),
    ring: Color(0xFFCDB4EA),
    dot: Color(0xFFBCA0E2),
    field: Color(0xFFF4EEFB),
    sweep: Color(0xFFE8D8F6),
    squares: [
      Color(0xFFE6D6F6),
      Color(0xFFDCC8F2),
      Color(0xFFF1E6FA),
      Color(0xFFD0B8EE),
    ],
  ),
];

class _FacePainter extends CustomPainter {
  const _FacePainter(this.palette, this.back);

  final _Palette palette;
  final bool back;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 680);
    if (back) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 400, 680),
        Paint()..color = palette.field,
      );
      final sweep = Path()
        ..moveTo(0, 0)
        ..lineTo(269, 0)
        ..cubicTo(244, 81, 200, 182, 150, 222)
        ..cubicTo(94, 266, 44, 239, 0, 316)
        ..close();
      canvas.drawPath(sweep, Paint()..color = palette.sweep);
      for (var n = 0; n < palette.squares.length; n++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(284 + (n % 2) * 46, 333 + (n ~/ 2) * 46, 32, 32),
            const Radius.circular(3),
          ),
          Paint()..color = palette.squares[n],
        );
      }
    } else {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 400, 680),
        Paint()..color = palette.paper,
      );
      final panel = Path()
        ..moveTo(0, 0)
        ..lineTo(179, 0)
        ..cubicTo(206, 47, 230, 162, 205, 316)
        ..cubicTo(183, 454, 154, 572, 123, 680)
        ..lineTo(0, 680)
        ..close();
      canvas.drawPath(panel, Paint()..color = palette.panel);
      final notch = Path()
        ..moveTo(123, 680)
        ..cubicTo(156, 680, 183, 586, 199, 482)
        ..cubicTo(179, 572, 150, 680, 123, 680)
        ..close();
      canvas.drawPath(notch, Paint()..color = palette.notch);
      canvas.drawCircle(
        const Offset(74, 199),
        42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = palette.ring,
      );
      canvas.drawCircle(
        const Offset(74, 199),
        12,
        Paint()..color = palette.dot,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) =>
      oldDelegate.back != back || oldDelegate.palette != palette;
}

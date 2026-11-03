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

  /// How far a pressed card rises out of the horizontal row.
  static const _pickLift = 16.0;

  /// Movement past this counts as a drag, so the row slides and the card
  /// does not lift. Kept inside the tap slop (18px).
  static const _pressSlop = 16.0;
  double _pressTravel = 0;
  double _pressDx = 0;
  bool _pressDrag = false;
  var _menuOpen = false;
  VoidCallback? _showMenu;
  double _scroll = 0;
  double _scrollFrom = 0;
  double _scrollTarget = 0;
  double _scrollLimit = 180;
  double _peek = 0;

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

  void _nudgeScroll(double delta, {bool snap = false}) {
    if (_intro < 1 || _menuOpen || delta == 0) return;
    _scrollFrom = _scroll;
    final limit = _scrollLimit;
    var next = (_scrollTarget + delta).clamp(0.0, limit).toDouble();
    if (snap) next = _snapped(next);
    _scrollTarget = next;
    _scrollAnim.forward(from: 0);
  }

  double _snapped(double value) {
    if (_peek <= 0) return value;
    final step = (value / _peek).round() * _peek;
    return step.clamp(0.0, _scrollLimit).toDouble();
  }

  void _snapScroll() {
    if (_intro < 1 || _peek <= 0) return;
    final next = _snapped(_scrollTarget);
    if ((next - _scroll).abs() < 0.5) return;
    _scrollFrom = _scroll;
    _scrollTarget = next;
    _scrollAnim.forward(from: 0);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final delta = event.scrollDelta.dx != 0
          ? event.scrollDelta.dx
          : event.scrollDelta.dy;
      _nudgeScroll(delta, snap: true);
    }
  }

  void _onPanZoom(PointerPanZoomUpdateEvent event) {
    final delta = event.panDelta.dx != 0
        ? event.panDelta.dx
        : event.panDelta.dy;
    _nudgeScroll(delta);
  }

  void _onFanPointerDown(PointerDownEvent event) {
    _pressTravel = 0;
    _pressDx = 0;
    _pressDrag = false;
  }

  void _onFanPointerMove(PointerMoveEvent event) {
    if (!event.down) return;
    _pressTravel += event.delta.distance;
    if (_pressTravel < _pressSlop) {
      _pressDx += event.delta.dx;
      return;
    }
    final dx = _pressDx + event.delta.dx;
    _pressDx = 0;
    _pressDrag = true;
    if (dx != 0) _nudgeScroll(dx);
  }

  void _onFanPointerUp(PointerUpEvent event) {
    if (_pressDrag) _snapScroll();
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
    final count = deck.cards.length;
    final peek = count < 2 ? 0.0 : deck.cards[1].cx - deck.cards[0].cx;
    final units = peek <= 0 ? 0.0 : scroll / peek;
    final lastCx = count == 0 ? 0.0 : deck.cards.last.cx;
    final cards = <_Placed>[
      for (final card in deck.cards)
        _Placed(
          index: card.index,
          cx: _rowCenter(
            card,
            units: units,
            peek: peek,
            lastCx: lastCx,
            count: count,
          ),
          cy: card.cy - (card.index == halfIndex ? _pickLift * openT : 0),
          width: card.width,
          height: card.height,
          scale: card.scale,
        ),
    ];
    return _Deck(
      cards: cards,
      clipLeft: deck.clipLeft,
      clipRight: deck.clipRight,
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

  /// Cards behind the front one stay one peek apart. A card that has been
  /// slid past the front travels by its own width, so it leaves the window
  /// instead of sitting on top of the next card.
  double _rowCenter(
    _Placed card, {
    required double units,
    required double peek,
    required double lastCx,
    required int count,
  }) {
    if (units == 0 || peek <= 0 || count < 2) return card.cx;
    final depth = (count - 1 - units) - card.index;
    if (depth >= 0) return lastCx - depth * peek;
    return lastCx + (-depth) * card.width;
  }

  Rect _strip(_Placed placed, _Deck deck) {
    final left = placed.cx - placed.width * placed.scale / 2;
    final top = placed.cy - placed.height * placed.scale / 2;
    final width = placed.width * placed.scale;
    final height = placed.height * placed.scale;
    var visible = width;
    if (_openAmount(placed.index) == 0 &&
        placed.index + 1 < deck.cards.length) {
      final next = deck.cards[placed.index + 1];
      final nextLeft = next.cx - next.width * next.scale / 2;
      visible = (nextLeft - left).clamp(1.0, width);
    }
    return Rect.fromLTWH(left, top, visible, height);
  }

  int? _indexAt(Offset local, _Deck deck) {
    final lifted = _halfIndex;
    if (lifted != null &&
        lifted >= 0 &&
        lifted < deck.cards.length &&
        _strip(deck.cards[lifted], deck).contains(local)) {
      return lifted;
    }
    for (var i = deck.cards.length - 1; i >= 0; i--) {
      if (i == lifted) continue;
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
        _scrollLimit = laidOut.cards.length < 2
            ? 0
            : (laidOut.cards.last.cx - laidOut.cards.first.cx).abs().clamp(
                0.0,
                4000.0,
              );
        _peek = laidOut.cards.length < 2
            ? 0
            : laidOut.cards[1].cx - laidOut.cards[0].cx;
        final deck = _present(laidOut);
        final closing = _deal.status == AnimationStatus.reverse;
        final done = _intro >= 1 && !closing;
        final label = done || closing ? 'Close wallet' : 'Open wallet';
        final showWallet = _intro < 1;

        final openingIndex = _halfIndex != null && _half.value > 0
            ? _halfIndex
            : null;
        final cardWidgets = <Widget>[
          for (final placed in deck.cards)
            if (placed.index != openingIndex) _card(placed, deck),
          if (openingIndex != null && openingIndex < deck.cards.length)
            _card(deck.cards[openingIndex], deck),
        ];

        return Listener(
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
                        onPointerUp: _onFanPointerUp,
                        child: Stack(
                          children: [
                            const Positioned.fill(child: SizedBox.expand()),
                            if (showWallet) _walletBack(deck, stageW, stageH),
                            if (_intro >= 1)
                              Positioned.fill(
                                child: ClipRect(
                                  clipper: _WindowClipper(
                                    deck.clipLeft,
                                    deck.clipRight,
                                  ),
                                  child: Stack(children: cardWidgets),
                                ),
                              )
                            else
                              ...cardWidgets,
                            if (showWallet) _walletFront(deck, stageW, stageH),
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
        );
      },
    );
  }

  Widget _card(_Placed placed, _Deck deck) {
    final boxTop = placed.cy - placed.height / 2;
    final boxLeft = placed.cx - placed.width / 2;
    final boxWidth = placed.width;
    final boxHeight = placed.height;
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
        scaleAlignment: Alignment.center,
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
      borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(-6, 10),
          ),
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 4,
            offset: Offset(-1, 2),
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
    required this.clipLeft,
    required this.clipRight,
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
  final double clipLeft;
  final double clipRight;
}

_Deck _layout({
  required double stageW,
  required double stageH,
  required double viewportW,
  required bool phone,
  required int count,
  required double intro,
}) {
  // Landscape cards share one horizontal row, like the coupon stack:
  // the same top and height, the front card fully visible on the right,
  // and up to three earlier cards peeking by the same fraction on the left.
  // Cards that do not fit wait off the left edge until the row slides.
  final span = math.min(viewportW, stageW);
  final margin =
      (phone
              ? (span * 0.041).clamp(14.0, 20.0)
              : (span * 0.04).clamp(28.0, 48.0))
          .toDouble();
  final content = math.max(160.0, span - margin * 2);
  const maxPeeks = 3;
  const peekFraction = 0.24;
  const aspect = 1.72;
  final shownPeeks = math.min(maxPeeks, math.max(0, count - 1));
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
  const pocketInset = 12.0;
  final walletW = phone
      ? math.min(math.max(0.0, span - pocketInset * 2), span - 8)
      : math.min(460.0, viewportW * 0.42);
  final controlHeight = phone ? 36.0 : 40.0;
  final belowControls = floor + 8 + controlHeight + (phone ? 28.0 : 36.0);
  final cap = phone ? content : math.min(460.0, content * 0.46);
  var cardW = shownPeeks == 0
      ? content
      : content / (1 + peekFraction * shownPeeks);
  if (cardW > cap) cardW = cap;
  var cardH = cardW / aspect;
  final room = stageH - belowControls - 16;
  if (room > 88 && cardH > room) {
    cardW *= room / cardH;
    cardH = room;
  }
  final peek = shownPeeks == 0 ? 0.0 : cardW * peekFraction;
  final groupW = cardW + shownPeeks * peek;
  // Fill the side margins when the visible group is as wide as the stage.
  // A shorter group, such as on a wide window, stays centered.
  final rowRight = groupW >= content - 0.5
      ? stageW - margin
      : (stageW + groupW) / 2;
  final lastLeft = rowRight - cardW;
  final minTop = belowControls;
  final maxTop = math.max(minTop, stageH - 16 - cardH);
  final rowTop = math
      .max(minTop, stageH * (phone ? 0.30 : 0.26))
      .clamp(minTop, maxTop)
      .toDouble();
  final clipLeft = lastLeft - shownPeeks * peek;
  final clipRight = rowRight;
  final rowCy = rowTop + cardH / 2;
  final pocketCx = stageW / 2;
  final pocketCy = walletTop + seam * 0.35;
  final cards = <_Placed>[];
  for (var i = 0; i < count; i++) {
    final restCx = lastLeft + cardW / 2 - (count - 1 - i) * peek;
    var cx = restCx;
    var cy = rowCy;
    var scale = 1.0;
    if (intro < 1) {
      final fromFront = count - 1 - i;
      final gaps = math.max(1, count - 1);
      final start = 0.06 + fromFront * (0.58 / gaps);
      final rise = _ease((intro - start) / 0.3);
      final stack = math.min(18.0, fromFront * 1.6);
      cx = pocketCx + stack * 0.12 + (restCx - pocketCx) * rise;
      cy = pocketCy + stack * 0.45 + (rowCy - pocketCy) * rise;
      scale = 0.96 + (1 - 0.96) * rise;
    }
    cards.add(
      _Placed(
        index: i,
        cx: cx,
        cy: cy,
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
    clipLeft: clipLeft,
    clipRight: clipRight,
  );
}

class _WindowClipper extends CustomClipper<Rect> {
  const _WindowClipper(this.left, this.right);

  final double left;
  final double right;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(left, 0, math.min(right, size.width), size.height);
  }

  @override
  bool shouldReclip(_WindowClipper oldDelegate) {
    return oldDelegate.left != left || oldDelegate.right != right;
  }
}

const _fanPadTop = 8.0;
const _fanNameSize = 16.0;
const _fanNameHeight = 1.15;
const _fanDetailSize = 13.0;
const _fanDetailHeight = 1.2;

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
    final width = size.width;
    final height = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = back ? palette.field : palette.paper,
    );
    // A wash on the left keeps each peek colored. The accent sits on the
    // right, where the front card is fully visible.
    final wash = Path()
      ..moveTo(0, 0)
      ..lineTo(width * 0.46, 0)
      ..cubicTo(
        width * 0.30,
        height * 0.28,
        width * 0.34,
        height * 0.72,
        width * 0.52,
        height,
      )
      ..lineTo(0, height)
      ..close();
    canvas.drawPath(
      wash,
      Paint()..color = back ? palette.sweep : palette.panel,
    );
    final accent = Offset(width * 0.78, height * 0.62);
    final radius = height * 0.22;
    canvas.drawCircle(
      accent,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3, height * 0.035)
        ..color = palette.ring,
    );
    canvas.drawCircle(accent, radius * 0.34, Paint()..color = palette.dot);
    if (back) {
      for (var n = 0; n < palette.squares.length && n < 4; n++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              width * 0.62 + (n % 2) * height * 0.16,
              height * 0.16 + (n ~/ 2) * height * 0.18,
              height * 0.11,
              height * 0.11,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = palette.squares[n],
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) =>
      oldDelegate.back != back || oldDelegate.palette != palette;
}

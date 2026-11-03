import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'card_fields.dart';

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
/// vertical fan from the Next.js engine. Close wallet runs that deal backwards.
class CardsStage extends StatefulWidget {
  const CardsStage({
    super.key,
    required this.passes,
    required this.onAdd,
    required this.onScan,
    required this.onDesign,
    this.fromCache = false,
    this.notice,
    this.account,
    this.footer,
  });

  final List<WalletPass> passes;
  final VoidCallback onAdd;
  final VoidCallback onScan;
  final VoidCallback onDesign;
  final bool fromCache;
  final String? notice;
  final Widget? account;
  final Widget? footer;

  @override
  State<CardsStage> createState() => _CardsStageState();
}

class _CardsStageState extends State<CardsStage>
    with SingleTickerProviderStateMixin {
  static const _introMs = 2300;
  static const _wallet = Color(0xFFDD1331);
  static const _ink = Color(0xFFF4F1EA);

  late final AnimationController _deal;
  int? _hover;
  int? _opened;

  @override
  void initState() {
    super.initState();
    _deal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _introMs),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _deal.dispose();
    super.dispose();
  }

  double get _intro => _deal.value;

  void _open() {
    if (_deal.isAnimating || _deal.value >= 1) return;
    _deal.forward();
  }

  void _close() {
    if (_deal.isAnimating || _deal.value <= 0) return;
    _deal.reverse();
  }

  Rect _strip(_Placed placed, _Deck deck) {
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
        final deck = _layout(
          stageW: stageW,
          stageH: stageH,
          viewportW: viewport.width,
          viewportH: viewport.height,
          phone: phone,
          count: widget.passes.length,
          intro: _intro,
        );
        final closing = _deal.status == AnimationStatus.reverse;
        final done = _intro >= 1 && !closing;
        final label = done || closing ? 'Close wallet' : 'Open wallet';
        final navScale = 0.94;
        final btnH = (phone ? 36.0 : 40.0) * navScale;
        final gap = (phone ? 8.0 : 10.0) * navScale;
        final insetX = phone ? 12.0 : 14.0;
        final insetY = phone ? 12.0 : 14.0;
        final navTop = (insetY + (stageH - insetY - 48) * 16 / 100)
            .clamp(0.0, math.max(0.0, stageH - 48))
            .toDouble();
        final showWallet = _intro < 1;

        return MouseRegion(
          onHover: (event) => _trackHover(event.localPosition, deck),
          onExit: (_) {
            if (_hover != null) setState(() => _hover = null);
          },
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: ClipRect(
              child: Stack(
                children: [
                  if (showWallet) _walletBack(deck, stageW, stageH),
                  for (final placed in deck.cards)
                    if (placed.index != _hover) _card(placed, deck),
                  if (showWallet) _walletFront(deck, stageW, stageH),
                  Positioned(
                    top: deck.wordmarkTop,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Text(
                        'IncardIt',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: deck.wordmarkSize,
                          height: 0.86,
                          letterSpacing: deck.wordmarkSize * -0.04,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF0F0F0F),
                        ),
                      ),
                    ),
                  ),
                  if (widget.fromCache || widget.notice != null)
                    Positioned(
                      top: deck.wordmarkTop + deck.wordmarkSize,
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
                    left: insetX,
                    top: navTop,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Pill(
                          label: 'Add+',
                          height: btnH,
                          scale: navScale,
                          onPressed: widget.onAdd,
                        ),
                        SizedBox(height: gap),
                        _Pill(
                          label: 'Scan',
                          height: btnH,
                          scale: navScale,
                          onPressed: widget.onScan,
                        ),
                        SizedBox(height: gap),
                        _Pill(
                          label: 'Design',
                          height: btnH,
                          scale: navScale,
                          onPressed: widget.onDesign,
                        ),
                        if (widget.account != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(width: 210, child: widget.account),
                        ],
                      ],
                    ),
                  ),
                  if (widget.footer != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 8,
                      child: widget.footer!,
                    ),
                  if (_hover != null && _hover! < deck.cards.length)
                    _card(deck.cards[_hover!], deck),
                  if (_opened != null && _opened! < widget.passes.length)
                    Positioned.fill(
                      child: _OpenCard(
                        pass: widget.passes[_opened!],
                        palette: _palettes[_opened! % _palettes.length],
                        showBack: _opened!.isOdd,
                        onClose: () => setState(() => _opened = null),
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
                ],
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
    final strip = _strip(placed, deck);
    return Positioned(
      left: boxLeft,
      top: boxTop,
      width: placed.width,
      height: placed.height,
      child: _HoverCard(
        key: ValueKey('wallet-pass-${placed.index}'),
        pass: widget.passes[placed.index],
        palette: _palettes[placed.index % _palettes.length],
        showBack: placed.index.isOdd,
        scale: placed.scale,
        lifted: _hover == placed.index && _opened == null,
        stripTop: strip.top - boxTop,
        stripLeft: strip.left - boxLeft,
        stripWidth: strip.width,
        stripHeight: strip.height,
        interactive: _intro >= 1 && _opened == null,
        onTap: () => setState(() => _opened = placed.index),
      ),
    );
  }

  void _trackHover(Offset local, _Deck deck) {
    if (_intro < 1 || _opened != null) {
      if (_hover != null) setState(() => _hover = null);
      return;
    }
    final index = _indexAt(local, deck);
    if (index != _hover) setState(() => _hover = index);
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.height,
    required this.scale,
    required this.onPressed,
  });

  final String label;
  final double height;
  final double scale;
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
            padding: EdgeInsets.symmetric(horizontal: 16 * scale),
            child: Center(
              child: Text(
                label,
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

class _HoverCard extends StatelessWidget {
  const _HoverCard({
    super.key,
    required this.pass,
    required this.palette,
    required this.showBack,
    required this.scale,
    required this.lifted,
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
  final bool lifted;
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
            child: _Lift(
              lifted: lifted,
              child: _FanCard(pass: pass, palette: palette, showBack: showBack),
            ),
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

class _Lift extends StatelessWidget {
  const _Lift({required this.lifted, required this.child});

  final bool lifted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: lifted ? -0.5 : 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, dy, child) {
        return FractionalTranslation(
          translation: Offset(0, dy),
          transformHitTests: false,
          child: child,
        );
      },
      child: child,
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
          CustomPaint(painter: _FacePainter(palette, showBack)),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pass.label.isNotEmpty)
                    Text(
                      pass.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: showBack ? palette.light : palette.ink,
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  if (pass.detail != null && pass.detail!.isNotEmpty)
                    Text(
                      pass.detail!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: showBack ? palette.light : palette.ink,
                        fontSize: 13,
                        height: 1.2,
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

class _OpenCard extends StatelessWidget {
  const _OpenCard({
    required this.pass,
    required this.palette,
    required this.showBack,
    required this.onClose,
  });

  final WalletPass pass;
  final _Palette palette;
  final bool showBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ink = showBack ? palette.light : palette.ink;
    final facts = pass.facts.isNotEmpty
        ? pass.facts
        : [
            WalletFact(field: 'name', label: 'Name', value: pass.label),
            if (pass.detail != null && pass.detail!.isNotEmpty)
              WalletFact(
                field: 'category',
                label: 'Business category',
                value: pass.detail!,
              ),
          ];
    return ColoredBox(
      color: const Color(0xB3000000),
      child: GestureDetector(
        onTap: onClose,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(340.0, constraints.maxWidth - 32);
                final height = math.min(
                  width * 1.7,
                  constraints.maxHeight - 48,
                );
                return SizedBox(
                  key: const ValueKey('open-card'),
                  width: width,
                  height: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 28,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(painter: _FacePainter(palette, showBack)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: onClose,
                                    child: Text(
                                      'Close',
                                      style: TextStyle(color: ink),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    children: [
                                      for (final fact in facts)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CardFieldIcon(
                                                fact.field,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      fact.value,
                                                      style: TextStyle(
                                                        color: ink,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    if (fact.extra != null &&
                                                        fact.extra!.isNotEmpty)
                                                      Text(
                                                        fact.extra!,
                                                        style: TextStyle(
                                                          color: ink,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
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
  });

  final List<_Placed> cards;
  final double walletTop;
  final double walletW;
  final double seam;
  final double wordmarkTop;
  final double wordmarkSize;
  final double floor;
}

class _Metrics {
  const _Metrics({
    required this.stepX,
    required this.stepY,
    required this.ax,
    required this.ay,
  });

  final double stepX;
  final double stepY;
  final double ax;
  final double ay;
}

_Deck _layout({
  required double stageW,
  required double stageH,
  required double viewportW,
  required double viewportH,
  required bool phone,
  required int count,
  required double intro,
}) {
  final cardW = phone
      ? math.min(200.0, viewportW * 0.54)
      : math.min(270.0, viewportW * 0.26);
  final cardH = cardW * 1.7;
  final wordmarkSize = (viewportW * 0.1355).clamp(64.0, 168.0).toDouble();
  final wordmarkTop = viewportH * 0.004;
  final floor = wordmarkTop + wordmarkSize * 0.86 + 8;
  final walletTop = stageH * (phone ? 0.50 : 0.54);
  final seam = phone ? 48.0 : 78.0;
  final walletW = phone
      ? math.min(230.0, viewportW * 0.62)
      : math.min(460.0, viewportW * 0.42);
  final base = phone
      ? const _Metrics(stepX: 0, stepY: 30, ax: 0.5, ay: 0.46)
      : const _Metrics(stepX: 0, stepY: 50, ax: 0.5, ay: 0.31);
  final m = _fitVertical(base, count, stageH, floor, cardH);
  final focus = math.max(0.0, (count - 1) * 0.46);
  final lipCy = walletTop + seam + 9;
  final pocketX = stageW / 2 - stageW * m.ax;
  final pocketY = lipCy + cardH * 0.5 - 26 - stageH * m.ay;
  final cards = <_Placed>[];
  for (var i = 0; i < count; i++) {
    final t = i - focus;
    var x = t * m.stepX;
    var y = t * m.stepY;
    var scale = (1 + t * 0.012).clamp(0.8, 1.08).toDouble();
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
  );
}

_Metrics _fitVertical(
  _Metrics m,
  int n,
  double stageH,
  double floor,
  double cardH,
) {
  if (n < 1 || cardH < 1 || stageH < 1) return m;
  final focus = math.max(0.0, (n - 1) * 0.46);
  double hhAt(int i) {
    final t = i - focus;
    final scale = (1 + t * 0.012).clamp(0.8, 1.08).toDouble();
    return cardH * scale * 0.5;
  }

  final span = n - 1;
  const margin = 16.0;
  final room = stageH - margin - floor - hhAt(0) - hhAt(n - 1);
  var step = m.stepY;
  if (span > 0) {
    step = room <= 8 ? math.min(step, 10) : math.min(step, room / span);
  }
  if (step < 0) step = 0;
  var ay = (floor + hhAt(0) - (0 - focus) * step) / stageH;
  for (var i = 1; i < n; i++) {
    final top = stageH * ay + (i - focus) * step - hhAt(i);
    if (top < floor) ay += (floor - top) / stageH;
  }
  return _Metrics(stepX: m.stepX, stepY: step, ax: m.ax, ay: ay);
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

const _palettes = <_Palette>[
  _Palette(
    ink: Color(0xFF041734),
    light: Color(0xFF51B4F5),
    paper: Color(0xFF51B4F5),
    panel: Color(0xFFF26306),
    notch: Color(0xFF48090B),
    ring: Color(0xFF041734),
    dot: Color(0xFFA10A04),
    field: Color(0xFFA10A04),
    sweep: Color(0xFF17365E),
    squares: [
      Color(0xFFF26306),
      Color(0xFF51B4F5),
      Color(0xFF2276C0),
      Color(0xFF041734),
    ],
  ),
  _Palette(
    ink: Color(0xFF050C0E),
    light: Color(0xFFE99320),
    paper: Color(0xFF7DA7A6),
    panel: Color(0xFFBD3F16),
    notch: Color(0xFF050C0E),
    ring: Color(0xFFE99320),
    dot: Color(0xFF132B35),
    field: Color(0xFF1C3B42),
    sweep: Color(0xFF050C0E),
    squares: [
      Color(0xFF4A7983),
      Color(0xFF7DA7A6),
      Color(0xFFBD3F16),
      Color(0xFFE99320),
    ],
  ),
  _Palette(
    ink: Color(0xFF321951),
    light: Color(0xFFFDC005),
    paper: Color(0xFFFDC005),
    panel: Color(0xFF633090),
    notch: Color(0xFF321951),
    ring: Color(0xFFF68318),
    dot: Color(0xFFB22E37),
    field: Color(0xFFB22E37),
    sweep: Color(0xFF313575),
    squares: [
      Color(0xFF633090),
      Color(0xFFF68318),
      Color(0xFFFDC005),
      Color(0xFF321951),
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

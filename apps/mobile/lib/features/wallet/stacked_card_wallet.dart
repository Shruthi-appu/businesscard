import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'business_card.dart';
import 'card_links.dart';

/// How many cards keep their own step. Deeper cards share the last step so
/// the pile stays on screen.
const stackedVisibleDepths = 4;

/// Rounded pastel card: a bold name and a smaller designation.
class BusinessCardWidget extends StatelessWidget {
  const BusinessCardWidget({
    super.key,
    required this.name,
    required this.designation,
    required this.background,
    this.elevation = 6,
  });

  final String name;
  final String designation;
  final Color background;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final role = designation.trim();
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Color(elevation > 6 ? 0x33241C19 : 0x1A241C19),
            blurRadius: elevation > 6 ? 18 : 10,
            offset: Offset(0, elevation > 6 ? 10 : 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 16, 18, 14),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: stackedCardInk,
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          if (role.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xC7241C19),
                fontSize: 18,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where one card sits in the layered pile. Depth 0 is the front card.
class StackedCardFrame {
  const StackedCardFrame({required this.depth, required this.rect});

  final int depth;
  final Rect rect;
}

/// Positions [count] landscape cards in a vertical column.
///
/// Every card shares the same left edge and the same wide size. The front
/// card is on top. Each following card sits under the one above it and
/// covers a small strip of that card's lower edge. Cards past the fourth
/// share the last row and stay inside [width] and [height].
List<StackedCardFrame> layoutStackedCards({
  required int count,
  required int frontIndex,
  required double width,
  required double height,
  required double topInset,
}) {
  if (count <= 0 || width <= 0 || height <= 0) return const [];
  const margin = 8.0;
  const bottomMargin = 16.0;
  final visible = math.min(count, stackedVisibleDepths);
  final availableW = math.max(1.0, width - margin * 2);
  final availableH = math.max(1.0, height - topInset - bottomMargin);
  var cardW = availableW;
  var cardH = cardW / stackedCardAspect;
  var overlap = _cardOverlap(cardH);
  var stackH = _columnHeight(cardH, overlap, visible);
  if (stackH > availableH) {
    cardH = _fittedCardHeight(availableH, visible);
    cardW = math.min(availableW, cardH * stackedCardAspect);
    cardH = cardW / stackedCardAspect;
    overlap = _cardOverlap(cardH);
    stackH = _columnHeight(cardH, overlap, visible);
  }
  final originX = (width - cardW) / 2;
  final originY = topInset + math.max(0.0, availableH - stackH) * 0.04;
  final front = frontIndex.clamp(0, count - 1);
  final frames = <StackedCardFrame>[];
  for (var index = 0; index < count; index++) {
    final depth = (index - front + count) % count;
    final row = math.min(depth, visible - 1);
    frames.add(
      StackedCardFrame(
        depth: depth,
        rect: Rect.fromLTWH(
          originX,
          originY + row * (cardH - overlap),
          cardW,
          cardH,
        ),
      ),
    );
  }
  return frames;
}

/// How much of the card above is covered. Enough to read as an overlap,
/// and short of the name and category.
double _cardOverlap(double cardHeight) {
  return math.min(40.0, math.max(16.0, cardHeight * 0.22));
}

double _columnHeight(double cardHeight, double overlap, int visible) {
  if (visible <= 1) return cardHeight;
  return cardHeight + (visible - 1) * (cardHeight - overlap);
}

/// Card height that keeps [visible] overlapped cards inside [available].
double _fittedCardHeight(double available, int visible) {
  if (visible <= 1) return math.max(1.0, available);
  final proportional = available / (visible - 0.22 * (visible - 1));
  final overlap = _cardOverlap(proportional);
  return (available + (visible - 1) * overlap) / visible;
}

double _ease(double u) {
  final t = u.clamp(0.0, 1.0).toDouble();
  return 1 - math.pow(1 - t, 3).toDouble();
}

/// Landscape cards in a vertical column. A tap on a lower card brings that
/// card to the top. Moving the pointer left or up brings the next card
/// forward. Moving it right or down brings the previous card forward.
/// A tap on the top card pops that card forward and shows its details on
/// the same card. [onOpen] runs as that pop starts. Advancing lifts the
/// foreground card off the pile and brings the next background card into
/// its place.
class StackedBusinessCardWallet extends StatefulWidget {
  const StackedBusinessCardWallet({
    super.key,
    required this.cards,
    required this.reveal,
    required this.topInset,
    required this.tuckCenter,
    required this.tuckWidth,
    required this.tuckHeight,
    this.onOpen,
    this.linkLauncher,
    this.interactive = true,
  });

  final List<BusinessCardData> cards;

  /// 0 keeps every card tucked at [tuckCenter]. 1 is the open pile.
  final double reveal;
  final double topInset;
  final Offset tuckCenter;
  final double tuckWidth;
  final double tuckHeight;
  final ValueChanged<int>? onOpen;
  final CardLinkLauncher? linkLauncher;
  final bool interactive;

  @override
  State<StackedBusinessCardWallet> createState() =>
      _StackedBusinessCardWalletState();
}

class _StackedBusinessCardWalletState extends State<StackedBusinessCardWallet>
    with TickerProviderStateMixin {
  String? _frontId;
  String? _popId;
  int? _advanceFrom;
  int _advanceDir = 1;
  double _dragX = 0;
  double _dragY = 0;
  double _tapTravel = 0;
  var _mutePop = false;
  var _muteShift = false;
  AnimationController? _popController;
  AnimationController? _shiftController;

  AnimationController get _pop => _popController ??= _createPop();

  AnimationController get _shift => _shiftController ??= _createShift();

  AnimationController _createPop() {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _popController = controller;
    controller
      ..addListener(() {
        if (mounted && !_mutePop) setState(() {});
      })
      ..addStatusListener((status) {
        if (_mutePop || status != AnimationStatus.dismissed || _popId == null) {
          return;
        }
        setState(() => _popId = null);
      });
    return controller;
  }

  AnimationController _createShift() {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _shiftController = controller;
    controller
      ..addListener(() {
        if (mounted && !_muteShift && _advanceFrom != null) setState(() {});
      })
      ..addStatusListener((status) {
        if (_muteShift ||
            status != AnimationStatus.completed ||
            _advanceFrom == null) {
          return;
        }
        setState(() => _advanceFrom = null);
      });
    return controller;
  }

  @override
  void initState() {
    super.initState();
    _pop;
    _shift;
  }

  @override
  void reassemble() {
    super.reassemble();
    _pop;
    _shift;
  }

  @override
  void didUpdateWidget(StackedBusinessCardWallet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lost =
        _popId != null && widget.cards.every((card) => card.id != _popId);
    if (_popId != null && (lost || widget.reveal < 1 || !widget.interactive)) {
      _mutePop = true;
      _pop.stop();
      _pop.value = 0;
      _popId = null;
      _mutePop = false;
    }
    if (_advanceFrom != null && (widget.reveal < 1 || !widget.interactive)) {
      _stopShift();
    }
  }

  @override
  void dispose() {
    _popController?.dispose();
    _shiftController?.dispose();
    _popController = null;
    _shiftController = null;
    super.dispose();
  }

  double get _moveT =>
      Curves.easeOutCubic.transform(_pop.value.clamp(0.0, 1.0));

  double get _detailT {
    return const Interval(
      0.18,
      0.78,
      curve: Curves.easeOut,
    ).transform(_pop.value.clamp(0.0, 1.0));
  }

  int get _front {
    final cards = widget.cards;
    if (cards.isEmpty) return 0;
    final index = cards.indexWhere((card) => card.id == _frontId);
    return index < 0 ? 0 : index;
  }

  void _setFront(int index) {
    if (widget.cards.isEmpty) return;
    final next = index.clamp(0, widget.cards.length - 1);
    setState(() => _frontId = widget.cards[next].id);
  }

  void _stopShift() {
    final shift = _shiftController;
    if (_advanceFrom == null && (shift == null || !shift.isAnimating)) return;
    _muteShift = true;
    shift?.stop();
    if (shift != null) shift.value = 1;
    _advanceFrom = null;
    _muteShift = false;
  }

  void _advance(int delta) {
    final count = widget.cards.length;
    if (count <= 1) return;
    _stopShift();
    final from = _front;
    final next = (from + delta + count) % count;
    if (next == from) return;
    _advanceFrom = from;
    _advanceDir = delta >= 0 ? 1 : -1;
    setState(() => _frontId = widget.cards[next].id);
    _shift.forward(from: 0);
  }

  bool get _shifting {
    final from = _advanceFrom;
    return from != null &&
        from >= 0 &&
        from < widget.cards.length &&
        widget.reveal >= 1 &&
        _popId == null;
  }

  double get _shiftT =>
      Curves.easeInOutCubic.transform(_shift.value.clamp(0.0, 1.0));

  /// Moves the foreground card off the pile, and the card behind it into
  /// the foreground. Other cards step between those two positions.
  Rect _shiftRect(int index, Rect start, Rect end) {
    final t = _shiftT;
    final traded = _advanceDir > 0 ? index == _advanceFrom : index == _front;
    if (!traded) return Rect.lerp(start, end, t)!;
    const split = 0.42;
    final lifted = start.shift(
      Offset(start.width * 0.045, -start.height * 0.48),
    );
    if (t < split) {
      final u = Curves.easeOut.transform(t / split);
      return Rect.lerp(start, lifted, u)!;
    }
    final u = Curves.easeOutCubic.transform((t - split) / (1 - split));
    return Rect.lerp(lifted, end, u)!;
  }

  int _paintOrder(int index, List<StackedCardFrame> frames) {
    if (!_shifting) return frames[index].depth;
    if (_advanceDir > 0 && index == _advanceFrom) {
      return _shiftT < 0.42 ? 1000 : -1;
    }
    if (_advanceDir < 0 && index == _front) return 1000;
    return frames[index].depth;
  }

  void _noteDown() => _tapTravel = 0;

  void _noteMove(PointerMoveEvent event) {
    _tapTravel += event.delta.distance;
  }

  /// A press that stays inside the touch slop opens the card. A longer
  /// move is a swipe, handled by the pile.
  void _noteUp(int index, int depth) {
    final travel = _tapTravel;
    _tapTravel = 0;
    if (travel > 18 || _popId != null) return;
    if (depth == 0) {
      _openFront(index);
    } else {
      _setFront(index);
    }
  }

  void _openFront(int index) {
    if (index < 0 || index >= widget.cards.length) return;
    final id = widget.cards[index].id;
    if (_popId == id) return;
    _stopShift();
    setState(() => _popId = id);
    _pop.forward(from: 0);
    widget.onOpen?.call(index);
  }

  void _closePop() {
    if (_popId == null || _pop.status == AnimationStatus.reverse) return;
    _pop.reverse();
  }

  Rect _popRect(double width, double height) {
    const side = 12.0;
    const bottom = 16.0;
    final top = widget.topInset + 4;
    final cardW = math.max(1.0, width - side);
    final cardH = math.max(1.0, height - top - bottom);
    return Rect.fromLTWH((width - cardW) / 2, top, cardW, cardH);
  }

  /// Negative distance or velocity moves to the next card. Positive moves
  /// to the previous card. A short press stays a tap.
  void _finishDrag(double distance, double velocity) {
    if (distance <= -36 || velocity < -250) {
      _advance(1);
    } else if (distance >= 36 || velocity > 250) {
      _advance(-1);
    }
  }

  Rect _tuckRect(int index) {
    final count = widget.cards.length;
    final fromFront = count <= 1 ? 0 : count - 1 - index;
    final stack = math.min(14.0, fromFront * 1.2);
    return Rect.fromCenter(
      center: widget.tuckCenter + Offset(stack * 0.15, stack * 0.35),
      width: widget.tuckWidth,
      height: widget.tuckHeight,
    );
  }

  double _rise(int index) {
    final count = widget.cards.length;
    final reveal = widget.reveal;
    if (count <= 1) return _ease(reveal / 0.42);
    // The card at the back of the pocket leaves first, then the next, so
    // they come out one after another.
    final order = count - 1 - index;
    final step = 0.70 / (count - 1);
    final start = 0.06 + order * step;
    const span = 0.24;
    return _ease((reveal - start) / span);
  }

  Rect _frameRect(StackedCardFrame frame, int index) {
    final rise = _rise(index);
    if (rise >= 1) return frame.rect;
    final tuck = _tuckRect(index);
    return Rect.lerp(tuck, frame.rect, rise)!;
  }

  Rect _shownRect(
    int index,
    List<StackedCardFrame> frames,
    List<StackedCardFrame>? fromFrames,
  ) {
    final end = _frameRect(frames[index], index);
    if (!_shifting || fromFrames == null || widget.reveal < 1) return end;
    return _shiftRect(index, fromFrames[index].rect, frames[index].rect);
  }

  int _shownDepth(int index, List<StackedCardFrame> frames) {
    if (!_shifting) return frames[index].depth;
    final lifting =
        (_advanceDir > 0 && index == _advanceFrom && _shiftT < 0.42) ||
        (_advanceDir < 0 && index == _front);
    if (lifting) return 0;
    return frames[index].depth;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frames = layoutStackedCards(
          count: widget.cards.length,
          frontIndex: _front,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          topInset: widget.topInset,
        );
        final fromFrames = _shifting
            ? layoutStackedCards(
                count: widget.cards.length,
                frontIndex: _advanceFrom!,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                topInset: widget.topInset,
              )
            : null;
        final order =
            [for (var index = 0; index < frames.length; index++) index]..sort((
              a,
              b,
            ) {
              if (_shifting) {
                return _paintOrder(a, frames).compareTo(_paintOrder(b, frames));
              }
              final top = frames[a].rect.top.compareTo(frames[b].rect.top);
              if (top != 0) return top;
              return frames[b].depth.compareTo(frames[a].depth);
            });
        final open = widget.reveal >= 1;
        final canDrag = open && widget.interactive && _popId == null;
        final poppedAt = _popId == null
            ? -1
            : widget.cards.indexWhere((card) => card.id == _popId);
        return GestureDetector(
          key: const ValueKey('stacked-card-wallet'),
          dragStartBehavior: DragStartBehavior.down,
          behavior: open && widget.interactive
              ? HitTestBehavior.translucent
              : HitTestBehavior.deferToChild,
          onHorizontalDragUpdate: canDrag
              ? (details) => _dragX += details.delta.dx
              : null,
          onHorizontalDragEnd: canDrag
              ? (details) {
                  _finishDrag(_dragX, details.primaryVelocity ?? 0);
                  _dragX = 0;
                }
              : null,
          onHorizontalDragCancel: canDrag ? () => _dragX = 0 : null,
          onVerticalDragUpdate: canDrag
              ? (details) => _dragY += details.delta.dy
              : null,
          onVerticalDragEnd: canDrag
              ? (details) {
                  _finishDrag(_dragY, details.primaryVelocity ?? 0);
                  _dragY = 0;
                }
              : null,
          onVerticalDragCancel: canDrag ? () => _dragY = 0 : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final index in order)
                if (index != poppedAt)
                  _placedCard(
                    index: index,
                    rect: _shownRect(index, frames, fromFrames),
                    depth: _shownDepth(index, frames),
                    animate: open && !_shifting,
                    popped: false,
                    stageWidth: constraints.maxWidth,
                    stageHeight: constraints.maxHeight,
                  ),
              if (poppedAt >= 0)
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey('card-pop-scrim'),
                    onTap: _closePop,
                    child: ColoredBox(
                      color: Color.fromRGBO(
                        15,
                        15,
                        15,
                        0.42 * _pop.value.clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
              if (poppedAt >= 0)
                _placedCard(
                  index: poppedAt,
                  rect: _frameRect(frames[poppedAt], poppedAt),
                  depth: 0,
                  animate: false,
                  popped: true,
                  stageWidth: constraints.maxWidth,
                  stageHeight: constraints.maxHeight,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _placedCard({
    required int index,
    required Rect rect,
    required int depth,
    required bool animate,
    required bool popped,
    required double stageWidth,
    required double stageHeight,
  }) {
    final card = widget.cards[index];
    final open = widget.reveal >= 1 && widget.interactive;
    final shown = popped
        ? Rect.lerp(rect, _popRect(stageWidth, stageHeight), _moveT)!
        : rect;
    final dim = !popped && _popId != null
        ? (1 - 0.5 * _pop.value).clamp(0.5, 1.0)
        : 1.0;
    final scale = popped ? 1 + 0.04 * math.sin(math.pi * _moveT) : 1.0;
    final face = Transform.scale(
      scale: scale,
      child: popped
          ? _openedFace(card)
          : Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: open ? (_) => _noteDown() : null,
              onPointerMove: open ? _noteMove : null,
              onPointerUp: open ? (_) => _noteUp(index, depth) : null,
              child: BusinessCardWidget(
                name: card.name,
                designation: card.designation,
                background: card.background,
                elevation: depth == 0 ? 10 : 3,
              ),
            ),
    );
    final child = IgnorePointer(
      ignoring: !open,
      child: Opacity(
        opacity: dim,
        child: KeyedSubtree(key: ValueKey(card.id), child: face),
      ),
    );
    if (!animate) {
      return Positioned(
        left: shown.left,
        top: shown.top,
        width: shown.width,
        height: shown.height,
        child: child,
      );
    }
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      left: shown.left,
      top: shown.top,
      width: shown.width,
      height: shown.height,
      child: child,
    );
  }

  Widget _openedFace(BusinessCardData card) {
    final lines = [
      for (final detail in card.details)
        if (detail.value.trim().isNotEmpty) detail,
    ];
    final role = card.designation.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: card.background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0x40241C19),
            blurRadius: 16 + 14 * _moveT,
            offset: Offset(0, 8 + 8 * _moveT),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        card.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: stackedCardInk,
                          fontSize: 28,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('card-pop-close'),
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    onPressed: _closePop,
                    icon: const Icon(Icons.close, color: stackedCardInk),
                  ),
                ],
              ),
              Expanded(
                child: Opacity(
                  opacity: _detailT,
                  child: ListView(
                    primary: false,
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    children: [
                      if (lines.isEmpty && role.isNotEmpty)
                        Text(
                          role,
                          style: const TextStyle(
                            color: Color(0xC7241C19),
                            fontSize: 18,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      for (final line in lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CardFactRow(
                            field: line.field,
                            value: line.value,
                            extra: line.extra,
                            launcher: widget.linkLauncher,
                            valueStyle: const TextStyle(
                              color: stackedCardInk,
                              fontSize: 16,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                            extraStyle: const TextStyle(
                              color: Color(0xA3241C19),
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

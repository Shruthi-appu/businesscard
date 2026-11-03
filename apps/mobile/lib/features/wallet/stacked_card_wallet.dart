import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'business_card.dart';

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
/// A tap on the top card calls [onOpen].
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
  final bool interactive;

  @override
  State<StackedBusinessCardWallet> createState() =>
      _StackedBusinessCardWalletState();
}

class _StackedBusinessCardWalletState extends State<StackedBusinessCardWallet> {
  String? _frontId;
  double _dragX = 0;
  double _dragY = 0;

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

  void _advance(int delta) {
    final count = widget.cards.length;
    if (count == 0) return;
    _setFront((_front + delta + count) % count);
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
        final order =
            [for (var index = 0; index < frames.length; index++) index]
              ..sort((a, b) {
                final top = frames[a].rect.top.compareTo(frames[b].rect.top);
                if (top != 0) return top;
                return frames[b].depth.compareTo(frames[a].depth);
              });
        final open = widget.reveal >= 1;
        return GestureDetector(
          key: const ValueKey('stacked-card-wallet'),
          dragStartBehavior: DragStartBehavior.down,
          behavior: open && widget.interactive
              ? HitTestBehavior.translucent
              : HitTestBehavior.deferToChild,
          onHorizontalDragUpdate: open && widget.interactive
              ? (details) => _dragX += details.delta.dx
              : null,
          onHorizontalDragEnd: open && widget.interactive
              ? (details) {
                  _finishDrag(_dragX, details.primaryVelocity ?? 0);
                  _dragX = 0;
                }
              : null,
          onHorizontalDragCancel: open && widget.interactive
              ? () => _dragX = 0
              : null,
          onVerticalDragUpdate: open && widget.interactive
              ? (details) => _dragY += details.delta.dy
              : null,
          onVerticalDragEnd: open && widget.interactive
              ? (details) {
                  _finishDrag(_dragY, details.primaryVelocity ?? 0);
                  _dragY = 0;
                }
              : null,
          onVerticalDragCancel: open && widget.interactive
              ? () => _dragY = 0
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final index in order)
                _placedCard(
                  index: index,
                  rect: _frameRect(frames[index], index),
                  depth: frames[index].depth,
                  animate: open,
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
  }) {
    final card = widget.cards[index];
    final open = widget.reveal >= 1 && widget.interactive;
    final child = IgnorePointer(
      ignoring: !open,
      child: GestureDetector(
        key: ValueKey(card.id),
        behavior: HitTestBehavior.opaque,
        onTap: open
            ? () {
                if (depth == 0) {
                  widget.onOpen?.call(index);
                } else {
                  _setFront(index);
                }
              }
            : null,
        child: BusinessCardWidget(
          name: card.name,
          designation: card.designation,
          background: card.background,
          elevation: depth == 0 ? 10 : 3,
        ),
      ),
    );
    if (!animate) {
      return Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: child,
      );
    }
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: child,
    );
  }
}

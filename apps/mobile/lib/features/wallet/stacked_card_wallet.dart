import 'dart:math' as math;

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
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
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
              fontSize: 20,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          if (role.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xC7241C19),
                fontSize: 13.5,
                height: 1.2,
                fontWeight: FontWeight.w500,
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

/// Positions [count] landscape cards in a pile.
///
/// The front card is the largest and sits lowest and furthest left. Each
/// card behind it is smaller, higher, and further right. The steps shrink
/// toward the back, so the gaps are not equal. Cards past the fourth share
/// the last step and stay inside [width] and [height].
List<StackedCardFrame> layoutStackedCards({
  required int count,
  required int frontIndex,
  required double width,
  required double height,
  required double topInset,
}) {
  if (count <= 0 || width <= 0 || height <= 0) return const [];
  const margin = 18.0;
  const bottomMargin = 20.0;
  const maxDxFrac = 0.40;
  const maxDyFrac = 0.62;
  const scaleDrop = 0.14;
  final last = math.min(count - 1, stackedVisibleDepths - 1);
  final tLast = _depthT(last);
  final scaleLast = 1 - tLast * scaleDrop;
  final clusterWFactor = tLast * maxDxFrac + scaleLast;
  final clusterHFactor = tLast * maxDyFrac + 1;
  final availableW = math.max(1.0, width - margin * 2);
  final availableH = math.max(1.0, height - topInset - bottomMargin);
  var cardW = availableW / math.max(0.01, clusterWFactor);
  var cardH = cardW / stackedCardAspect;
  if (cardH * clusterHFactor > availableH) {
    cardH = availableH / clusterHFactor;
    cardW = cardH * stackedCardAspect;
  }
  final clusterW = cardW * clusterWFactor;
  final clusterH = cardH * clusterHFactor;
  final originX = (width - clusterW) / 2;
  final clusterTop = topInset + (availableH - clusterH) * 0.18;
  final frontTop = clusterTop + cardH * tLast * maxDyFrac;
  final front = frontIndex.clamp(0, count - 1);
  return [
    for (var index = 0; index < count; index++)
      () {
        final depth = (index - front + count) % count;
        final shown = math.min(depth, last);
        final t = _depthT(shown);
        final scale = 1 - t * scaleDrop;
        final rect = Rect.fromLTWH(
          originX + t * maxDxFrac * cardW,
          frontTop - t * maxDyFrac * cardH,
          cardW * scale,
          cardH * scale,
        );
        return StackedCardFrame(depth: depth, rect: rect);
      }(),
  ];
}

/// 0 at the front, 1 at the furthest visible step. The curve is steeper
/// near the front, so successive gaps get smaller.
double _depthT(int shown) {
  if (shown <= 0 || stackedVisibleDepths <= 1) return 0;
  final u = shown / (stackedVisibleDepths - 1);
  return 1 - math.pow(1 - u, 1.35).toDouble();
}

double _ease(double u) {
  final t = u.clamp(0.0, 1.0).toDouble();
  return 1 - math.pow(1 - t, 3).toDouble();
}

/// Layered horizontal cards. A tap on a card behind the front brings that
/// card forward. A horizontal swipe moves to the next or previous card.
/// A tap on the front card calls [onOpen].
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
  double _drag = 0;

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
    _setFront((_front + delta) % count);
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
    if (count <= 1) return _ease(reveal / 0.36);
    final fromFront = count - 1 - index;
    final start = 0.06 + fromFront * (0.58 / (count - 1));
    return _ease((reveal - start) / 0.34);
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
        final order = [
          for (var index = 0; index < frames.length; index++) index,
        ]..sort((a, b) => frames[b].depth.compareTo(frames[a].depth));
        final open = widget.reveal >= 1;
        return GestureDetector(
          key: const ValueKey('stacked-card-wallet'),
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: open && widget.interactive
              ? (details) => _drag += details.delta.dx
              : null,
          onHorizontalDragEnd: open && widget.interactive
              ? (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (_drag <= -36 || velocity < -250) {
                    _advance(1);
                  } else if (_drag >= 36 || velocity > 250) {
                    _advance(-1);
                  }
                  _drag = 0;
                }
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
    final child = GestureDetector(
      key: ValueKey(card.id),
      behavior: HitTestBehavior.opaque,
      onTap: widget.interactive && widget.reveal >= 1
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

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WalletPass {
  const WalletPass({
    required this.label,
    this.detail,
    this.favourite = false,
    this.onOpen,
  });

  final String label;
  final String? detail;
  final bool favourite;
  final VoidCallback? onOpen;
}

/// Portrait cards in the Template 4 stack.
///
/// Mobile card size from that sheet: width min(200px, 54vw), aspect 1 / 1.7.
/// Cards are tucked in the wallet, then rise into a link stack. Each card
/// leaves its top 18% showing above the one in front. Tap the wallet to
/// open or close the stack.
class WalletSleeveStack extends StatefulWidget {
  const WalletSleeveStack({
    super.key,
    required this.passes,
    required this.onAdd,
    required this.onScan,
  });

  final List<WalletPass> passes;
  final VoidCallback onAdd;
  final VoidCallback onScan;

  @override
  State<WalletSleeveStack> createState() => _WalletSleeveStackState();
}

class _WalletSleeveStackState extends State<WalletSleeveStack>
    with SingleTickerProviderStateMixin {
  static const _walletRed = Color(0xFFDD1331);
  static const _headerShare = 0.18;

  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: _duration(widget.passes.length),
    );
    if (widget.passes.isEmpty) {
      _motion.value = 1;
    } else {
      _motion.forward();
    }
  }

  @override
  void didUpdateWidget(covariant WalletSleeveStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.passes.length == oldWidget.passes.length) return;
    _motion.duration = _duration(widget.passes.length);
    if (widget.passes.isEmpty) {
      _motion.value = 1;
    } else {
      _motion.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Duration _duration(int count) => Duration(milliseconds: 640 + count * 90);

  void _toggle() {
    if (widget.passes.isEmpty) return;
    if (_motion.status == AnimationStatus.completed || _motion.value == 1) {
      _motion.reverse();
    } else {
      _motion.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Scan a card',
              onPressed: widget.onScan,
              icon: const Icon(CupertinoIcons.camera, size: 26),
            ),
            IconButton(
              tooltip: 'Add a card',
              onPressed: widget.onAdd,
              icon: const Icon(CupertinoIcons.add, size: 30),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final deck = _deck(constraints.maxWidth, widget.passes.length);
            return SizedBox(
              height: deck.height,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: deck.sleeveHeight * 0.08,
                        child: Center(
                          child: Container(
                            width: deck.sleeveWidth * 0.92,
                            height: deck.sleeveHeight * 0.78,
                            decoration: BoxDecoration(
                              color: _walletRed,
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                      for (var index = 0; index < widget.passes.length; index++)
                        _placedCard(index, deck),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _toggle,
                            child: Image.asset(
                              'assets/wallet_sleeve.png',
                              width: deck.sleeveWidth,
                              fit: BoxFit.contain,
                              semanticLabel: 'Wallet',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _placedCard(int index, _Deck deck) {
    final count = widget.passes.length;
    final t = _rise(index, count);
    final restTop = index * deck.peek;
    final tucked = deck.mouth - deck.peek * 0.2;
    final top = tucked + (restTop - tucked) * t;
    final pass = widget.passes[index];
    return Positioned(
      top: top,
      left: (deck.width - deck.cardWidth) / 2,
      width: deck.cardWidth,
      height: deck.cardHeight,
      child: Opacity(
        opacity: (0.2 + 0.8 * t).clamp(0, 1),
        child: Transform.scale(
          scale: 0.94 + 0.06 * t,
          alignment: Alignment.topCenter,
          child: _PassFace(
            key: ValueKey('wallet-pass-$index'),
            pass: pass,
            headerShare: _headerShare,
          ),
        ),
      ),
    );
  }

  /// Staggered 0–1 progress so each card eases out after the one above it.
  double _rise(int index, int count) {
    final start = index / (count + 1);
    final end = (0.55 + index / (count + 2)).clamp(start + 0.08, 1.0);
    final raw = _motion.value;
    if (raw <= start) return 0;
    if (raw >= end) return 1;
    return Curves.easeOutCubic.transform((raw - start) / (end - start));
  }

  _Deck _deck(double width, int count) {
    final viewport = MediaQuery.sizeOf(context).width;
    final cardWidth = math.min(200.0, math.min(width, viewport * 0.54));
    final cardHeight = cardWidth * 1.7;
    final peek = cardHeight * _headerShare;
    final sleeveWidth = math.min(
      width,
      math.max(cardWidth * 1.18, cardWidth + 28),
    );
    final sleeveHeight = sleeveWidth * (428 / 338);
    final stackHeight = count == 0 ? 0.0 : peek * (count - 1) + cardHeight;
    final overlap = count == 0
        ? 0.0
        : math.min(sleeveHeight * 0.42, cardHeight * 0.45);
    return _Deck(
      width: width,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      peek: peek,
      sleeveWidth: sleeveWidth,
      sleeveHeight: sleeveHeight,
      stackHeight: stackHeight,
      overlap: overlap,
    );
  }
}

class _Deck {
  const _Deck({
    required this.width,
    required this.cardWidth,
    required this.cardHeight,
    required this.peek,
    required this.sleeveWidth,
    required this.sleeveHeight,
    required this.stackHeight,
    required this.overlap,
  });

  final double width;
  final double cardWidth;
  final double cardHeight;
  final double peek;
  final double sleeveWidth;
  final double sleeveHeight;
  final double stackHeight;
  final double overlap;

  double get height => stackHeight + sleeveHeight - overlap;
  double get mouth => stackHeight - overlap;
}

class _PassFace extends StatelessWidget {
  const _PassFace({super.key, required this.pass, required this.headerShare});

  final WalletPass pass;
  final double headerShare;

  @override
  Widget build(BuildContext context) {
    final face = LayoutBuilder(
      builder: (context, constraints) {
        final header = constraints.maxHeight * headerShare;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: header,
                    color: const Color(0xFFDD1331),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      pass.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF4F1EA),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pass.detail != null && pass.detail!.isNotEmpty)
                            Text(
                              pass.detail!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0F0F0F),
                                fontSize: 15,
                              ),
                            ),
                          if (pass.favourite)
                            const Text(
                              'Favourite',
                              style: TextStyle(
                                color: Color(0xFF9E2E2E),
                                fontWeight: FontWeight.w600,
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
      },
    );
    if (pass.onOpen == null) return face;
    return GestureDetector(onTap: pass.onOpen, child: face);
  }
}

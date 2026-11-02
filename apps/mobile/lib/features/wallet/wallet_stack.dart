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

/// Cards rise out of the leather sleeve, then sit in an Apple Wallet stack.
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
  static const _cardHeight = 168.0;
  static const _peek = 62.0;
  static const _sleeveWidth = 210.0;

  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    final count = widget.passes.length;
    _motion = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 780 + count * 160),
    );
    if (count == 0) {
      _motion.value = 1;
    } else {
      _motion.forward();
    }
  }

  @override
  void didUpdateWidget(covariant WalletSleeveStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.passes.length != oldWidget.passes.length && widget.passes.isNotEmpty) {
      _motion.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.passes.length;
    final stackHeight = count == 0 ? 0.0 : _peek * (count - 1) + _cardHeight;
    final sleeveHeight = _sleeveWidth * (428 / 338);
    final height = stackHeight + sleeveHeight * 0.72;

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
        SizedBox(
          height: height,
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = 0; index < count; index++)
                    _placedCard(index, count, stackHeight),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(
                      child: Image.asset(
                        'assets/wallet_sleeve.png',
                        width: _sleeveWidth,
                        fit: BoxFit.contain,
                        semanticLabel: 'Wallet',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _placedCard(int index, int count, double stackHeight) {
    final t = _rise(index, count);
    final restTop = index * _peek;
    final tucked = stackHeight - _cardHeight * 0.2;
    final top = tucked + (restTop - tucked) * t;
    final pass = widget.passes[index];
    return Positioned(
      top: top,
      left: 28,
      right: 28,
      height: _cardHeight,
      child: Opacity(
        opacity: (0.15 + 0.85 * t).clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 18),
          child: _PassFace(
            pass: pass,
            color: _passColors[index % _passColors.length],
          ),
        ),
      ),
    );
  }

  /// Staggered 0–1 progress so each card eases out after the one above it.
  double _rise(int index, int count) {
    final start = index / (count + 1);
    final end = (0.62 + index / (count + 2)).clamp(start + 0.08, 1.0);
    final raw = _motion.value;
    if (raw <= start) return 0;
    if (raw >= end) return 1;
    return Curves.easeOutCubic.transform((raw - start) / (end - start));
  }
}

const _passColors = <Color>[
  Color(0xFF1C1C1E),
  Color(0xFF0F6E56),
  Color(0xFF7A2E2E),
  Color(0xFF1E3A5F),
  Color(0xFF4A3F2F),
  Color(0xFF5C3D2E),
];

class _PassFace extends StatelessWidget {
  const _PassFace({required this.pass, required this.color});

  final WalletPass pass;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final face = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pass.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF7FFFB),
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (pass.detail != null && pass.detail!.isNotEmpty)
            Text(
              pass.detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xE6F7FFFB), fontSize: 15),
            ),
          if (pass.favourite)
            const Text('Favourite', style: TextStyle(color: Color(0xFFF3EEE4))),
        ],
      ),
    );
    if (pass.onOpen == null) return face;
    return GestureDetector(onTap: pass.onOpen, child: face);
  }
}

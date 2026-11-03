import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softxu/features/wallet/wallet_stack.dart';

void main() {
  testWidgets('cards rise out of the wallet into a portrait link stack', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalletSleeveStack(
            passes: const [
              WalletPass(label: 'Ada'),
              WalletPass(label: 'Grace'),
            ],
            onAdd: _noop,
            onScan: _noop,
          ),
        ),
      ),
    );

    final start = tester
        .getTopLeft(find.byKey(const ValueKey('wallet-pass-0')))
        .dy;
    await tester.pumpAndSettle();
    final first = tester.getRect(find.byKey(const ValueKey('wallet-pass-0')));
    final second = tester.getRect(find.byKey(const ValueKey('wallet-pass-1')));

    expect(first.top, lessThan(start - 40));
    expect(first.width, closeTo(200, 0.5));
    expect(first.height / first.width, closeTo(1.7, 0.01));
    expect(second.top - first.top, closeTo(first.height * 0.18, 1));
    expect(second.left, first.left);
  });
}

void _noop() {}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softxu/features/wallet/test_cards.dart';
import 'package:softxu/features/wallet/wallet_stack.dart';

void main() {
  testWidgets('cards wait in the wallet, then deal into a vertical stack', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CardsStage(
            onAdd: _noop,
            onScan: _noop,
            onDesign: _noop,
            passes: [
              WalletPass(label: 'Ada'),
              WalletPass(label: 'Grace'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tuckedAda = tester.getCenter(find.text('Ada'));
    final tuckedGrace = tester.getCenter(find.text('Grace'));
    expect((tuckedAda.dy - tuckedGrace.dy).abs(), lessThan(24));
    expect(find.text('Open wallet'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('wallet-pocket'))).width,
      closeTo(230, 1),
    );

    await tester.tap(find.text('Open wallet'));
    await tester.pumpAndSettle();

    final ada = tester.getCenter(find.text('Ada'));
    final grace = tester.getCenter(find.text('Grace'));
    final card = tester.getSize(find.byKey(const ValueKey('wallet-pass-0')));
    expect(grace.dy, greaterThan(ada.dy + 12));
    expect(card.width, closeTo(200, 1));
    expect(card.height / card.width, closeTo(1.7, 0.02));
    expect(find.text('Close wallet'), findsOneWidget);
  });

  testWidgets('twenty test cards deal out of the pocket', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardsStage(
            onAdd: _noop,
            onScan: _noop,
            onDesign: _noop,
            passes: testWalletPasses,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(testWalletPasses, hasLength(20));
    expect(find.text('Open wallet'), findsOneWidget);
    final tucked = tester.getCenter(find.text('Meera Iyer'));
    expect(
      (tucked.dy - tester.getCenter(find.text('Jonah Brooks')).dy).abs(),
      lessThan(24),
    );

    await tester.tap(find.text('Open wallet'));
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('Jonah Brooks')).dy,
      greaterThan(tester.getCenter(find.text('Meera Iyer')).dy + 12),
    );
    expect(find.text('Close wallet'), findsOneWidget);
  });
}

void _noop() {}

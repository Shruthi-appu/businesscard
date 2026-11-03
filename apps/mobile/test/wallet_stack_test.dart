import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

void _noop() {}

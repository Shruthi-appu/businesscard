import 'package:flutter/gestures.dart';
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
              WalletPass(label: 'Ada', detail: 'Studio'),
              WalletPass(label: 'Grace', detail: 'Design'),
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
    final cardBox = tester.getRect(find.byKey(const ValueKey('wallet-pass-0')));
    expect(grace.dy, greaterThan(ada.dy + 12));
    expect(cardBox.width, closeTo(200, 1));
    expect(cardBox.height / cardBox.width, closeTo(1.7, 0.02));
    expect(tester.getTopLeft(find.text('Ada')).dy, lessThan(cardBox.top + 48));
    expect(
      tester.getTopLeft(find.text('Studio')).dy,
      greaterThan(tester.getTopLeft(find.text('Ada')).dy),
    );
    expect(find.text('Close wallet'), findsOneWidget);

    final resting = tester.getCenter(find.text('Grace'));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: resting);
    await pointer.moveTo(resting);
    await tester.pumpAndSettle();
    expect(
      resting.dy - tester.getCenter(find.text('Grace')).dy,
      greaterThan(80),
    );
    await pointer.removePointer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grace'));
    await tester.pumpAndSettle();
    final open = find.byKey(const ValueKey('open-card'));
    expect(open, findsOneWidget);
    expect(
      find.descendant(of: open, matching: find.text('Grace')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: open, matching: find.text('Design')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: open, matching: find.text('Name')),
      findsNothing,
    );
    expect(
      find.descendant(of: open, matching: find.text('Business category')),
      findsNothing,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-card')), findsNothing);
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
    final meera = tester.getRect(find.byKey(const ValueKey('wallet-pass-0')));
    expect(
      tester.getTopLeft(find.text('Meera Iyer')).dy,
      lessThan(meera.top + 48),
    );
    expect(
      tester.getTopLeft(find.text('Studio lead')).dy,
      greaterThan(tester.getTopLeft(find.text('Meera Iyer')).dy),
    );

    final resting = tester.getCenter(find.text('Meera Iyer'));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: resting);
    await pointer.moveTo(resting);
    await tester.pumpAndSettle();
    expect(
      resting.dy - tester.getCenter(find.text('Meera Iyer')).dy,
      greaterThan(80),
    );
    await pointer.removePointer();
    expect(find.text('Close wallet'), findsOneWidget);
  });

  testWidgets('account actions stay behind the side menu', (tester) async {
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
            menu: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Account',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('Export my data'),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'I understand this schedules deletion and signs me out.',
                      ),
                    ),
                    Switch(value: false, onChanged: (_) {}),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Delete account'),
              ],
            ),
            passes: const [WalletPass(label: 'Ada', detail: 'Studio')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add+'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Design'), findsOneWidget);
    expect(find.text('Export my data'), findsNothing);
    expect(find.text('Delete account'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('wallet-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Export my data'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    expect(
      find.text('I understand this schedules deletion and signs me out.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

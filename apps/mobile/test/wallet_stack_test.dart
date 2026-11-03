import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softxu/features/wallet/test_cards.dart';
import 'package:softxu/features/wallet/wallet_stack.dart';

void main() {
  testWidgets('cards wait in the wallet, then deal into a layered pile', (
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
    final pocketWidth = tester
        .getSize(find.byKey(const ValueKey('wallet-pocket')))
        .width;
    expect(pocketWidth, closeTo(366, 1));
    _expectHeaderRow(tester);

    await tester.tap(find.text('Open wallet'));
    await tester.pumpAndSettle();

    final adaBox = tester.getRect(find.byKey(const ValueKey('wallet-pass-0')));
    final graceBox = tester.getRect(
      find.byKey(const ValueKey('wallet-pass-1')),
    );
    expect(graceBox.top, lessThan(adaBox.top - 8));
    expect(graceBox.left, greaterThan(adaBox.left + 8));
    expect(adaBox.width, greaterThan(graceBox.width + 4));
    expect(adaBox.height, greaterThan(graceBox.height + 2));
    expect(adaBox.width / adaBox.height, closeTo(2.05, 0.08));
    expect(adaBox.left, greaterThanOrEqualTo(12));
    expect(graceBox.right, lessThanOrEqualTo(390));
    expect(adaBox.bottom, lessThanOrEqualTo(844));
    expect(tester.getTopLeft(find.text('Ada')).dy, lessThan(adaBox.top + 48));
    expect(
      tester.getTopLeft(find.text('Studio')).dy,
      greaterThan(tester.getTopLeft(find.text('Ada')).dy),
    );
    expect(find.text('Close wallet'), findsOneWidget);

    final before = tester.getRect(find.byKey(const ValueKey('wallet-pass-1')));
    final resting = tester.getCenter(find.text('Grace'));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: resting);
    await pointer.moveTo(resting);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('wallet-pass-1'))).height,
      closeTo(before.height, 1),
    );
    await pointer.removePointer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grace'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsNothing);
    final graceFront = tester.getRect(
      find.byKey(const ValueKey('wallet-pass-1')),
    );
    final adaBack = tester.getRect(find.byKey(const ValueKey('wallet-pass-0')));
    expect(graceFront.width, greaterThan(adaBack.width));
    expect(adaBack.top, lessThan(graceFront.top));
    expect(adaBack.left, greaterThan(graceFront.left));

    await tester.tap(find.text('Grace'));
    await tester.pumpAndSettle();
    expect(find.text('Design'), findsWidgets);
    expect(find.text('Name'), findsNothing);
    expect(find.text('Business category'), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('wallet-pass-1'))).height,
      closeTo(graceFront.height, 1),
    );

    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsNothing);
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();
    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('Name'), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('one click opens the card detail', (tester) async {
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
    await tester.tap(find.text('Open wallet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();
    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('Name'), findsNothing);
    expect(find.text('Business category'), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Close wallet'), findsNothing);
  });

  testWidgets('an open sample card shows values and icons without titles', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final card = testCards.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardsStage(
            onAdd: _noop,
            onScan: _noop,
            onDesign: _noop,
            passes: [card.toPass()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(card.name));
    await tester.pumpAndSettle();
    expect(find.text(card.name), findsWidgets);
    expect(find.text(card.category), findsOneWidget);
    expect(find.text(card.address), findsOneWidget);
    expect(find.text(card.whatsapp), findsOneWidget);
    expect(find.text(card.website), findsOneWidget);
    expect(find.text('Name'), findsNothing);
    expect(find.text('Business category'), findsNothing);
    expect(find.text('Address'), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Website'), findsNothing);
    expect(find.byKey(const ValueKey('card-link-whatsapp')), findsOneWidget);
    expect(find.byKey(const ValueKey('card-link-location')), findsOneWidget);
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
      lessThan(tester.getCenter(find.text('Meera Iyer')).dy - 8),
    );
    _expectLayeredPile(tester, const [0, 1, 2, 3]);
    final meera = tester.getRect(find.byKey(const ValueKey('wallet-pass-0')));
    expect(
      tester.getTopLeft(find.text('Meera Iyer')).dy,
      lessThan(meera.top + 48),
    );
    expect(
      tester.getTopLeft(find.text('Studio lead')).dy,
      greaterThan(tester.getTopLeft(find.text('Meera Iyer')).dy),
    );
    final meeraCard = find.byKey(const ValueKey('wallet-pass-0'));
    final beforeCard = tester.getRect(meeraCard);
    final resting = tester.getCenter(find.text('Meera Iyer'));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: resting);
    await pointer.moveTo(resting);
    await tester.pumpAndSettle();
    expect(tester.getRect(meeraCard).height, closeTo(beforeCard.height, 1));
    await pointer.removePointer();
    await tester.pumpAndSettle();
    expect(find.text('Close wallet'), findsOneWidget);
  });

  testWidgets('a horizontal swipe brings the next card forward', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var added = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardsStage(
            onAdd: () => added = true,
            onScan: _noop,
            onDesign: _noop,
            passes: const [
              WalletPass(label: 'Ada', detail: 'Studio'),
              WalletPass(label: 'Grace', detail: 'Design'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open wallet'));
    await tester.pumpAndSettle();

    final front = find.byKey(const ValueKey('wallet-pass-0'));
    final next = find.byKey(const ValueKey('wallet-pass-1'));
    final beforeFront = tester.getRect(front);
    final beforeNext = tester.getRect(next);
    expect(beforeFront.width, greaterThan(beforeNext.width));
    await tester.fling(
      find.byKey(const ValueKey('stacked-card-wallet')),
      const Offset(-240, 0),
      900,
    );
    await tester.pumpAndSettle();
    final afterFront = tester.getRect(front);
    final afterNext = tester.getRect(next);
    expect(afterNext.width, greaterThan(afterFront.width));
    expect(afterNext.top, greaterThan(afterFront.top + 8));
    expect(afterFront.left, greaterThan(afterNext.left + 8));
    expect(afterNext.height, closeTo(beforeFront.height, 12));
    expect(find.byKey(const ValueKey('open-card')), findsNothing);

    final gesture = await tester.startGesture(afterNext.center);
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getRect(next).width,
      greaterThan(tester.getRect(front).width),
    );

    await tester.tap(find.text('Add+'));
    await tester.pump();
    expect(added, isTrue);
    await tester.tap(find.text('Scan'));
    await tester.tap(find.widgetWithText(InkWell, 'Design'));
    await tester.tap(find.text('Close wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Open wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account actions stay behind the side menu', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final menuHandle = WalletMenuHandle();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(leading: WalletMenuButton(onPressed: menuHandle.open)),
          body: CardsStage(
            onAdd: _noop,
            onScan: _noop,
            onDesign: _noop,
            menuHandle: menuHandle,
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

    final menu = tester.getRect(find.byKey(const ValueKey('wallet-menu')));
    final add = tester.getRect(find.widgetWithText(InkWell, 'Add+'));
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(const ValueKey('wallet-menu')),
      ),
      findsOneWidget,
    );
    expect(menu.center.dx, lessThan(80));
    expect(menu.width, greaterThanOrEqualTo(44));
    expect(menu.height, greaterThanOrEqualTo(44));
    expect(menu.overlaps(add), isFalse);
    _expectHeaderRow(tester);

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

/// IncardIt sits on the left. Add, Scan, and Design share that row.
void _expectHeaderRow(WidgetTester tester) {
  final title = tester.getRect(find.text('IncardIt'));
  final add = tester.getRect(find.widgetWithText(InkWell, 'Add+'));
  final scan = tester.getRect(find.widgetWithText(InkWell, 'Scan'));
  final design = tester.getRect(find.widgetWithText(InkWell, 'Design'));
  expect(title.left, lessThan(24));
  expect(title.right, lessThanOrEqualTo(add.left + 0.5));
  expect(add.right, lessThanOrEqualTo(scan.left + 0.5));
  expect(scan.right, lessThanOrEqualTo(design.left + 0.5));
  expect((add.center.dy - title.center.dy).abs(), lessThan(16));
  expect((scan.center.dy - add.center.dy).abs(), lessThan(2));
  expect((design.center.dy - scan.center.dy).abs(), lessThan(2));
  expect((design.top - add.top).abs(), lessThan(2));
  expect(design.bottom - add.top, lessThan(add.height + 4));
}

/// Front card is largest and lowest. Each card behind is higher, further
/// right, and the gaps shrink.
void _expectLayeredPile(WidgetTester tester, List<int> indexes) {
  final rects = [
    for (final index in indexes)
      tester.getRect(find.byKey(ValueKey('wallet-pass-$index'))),
  ];
  final stage = tester.getSize(find.byType(CardsStage));
  for (var i = 0; i < rects.length - 1; i++) {
    expect(rects[i + 1].top, lessThan(rects[i].top - 6));
    expect(rects[i + 1].left, greaterThan(rects[i].left + 6));
    expect(rects[i].width, greaterThan(rects[i + 1].width + 2));
  }
  if (rects.length >= 4) {
    final firstGap = rects[1].left - rects[0].left;
    final secondGap = rects[2].left - rects[1].left;
    final thirdGap = rects[3].left - rects[2].left;
    expect(firstGap, greaterThan(secondGap + 2));
    expect(secondGap, greaterThan(thirdGap + 2));
  }
  for (final rect in rects) {
    expect(rect.left, greaterThanOrEqualTo(-1));
    expect(rect.top, greaterThanOrEqualTo(-1));
    expect(rect.right, lessThanOrEqualTo(stage.width + 1));
    expect(rect.bottom, lessThanOrEqualTo(stage.height + 1));
    expect(rect.width / rect.height, closeTo(2.05, 0.08));
  }
}

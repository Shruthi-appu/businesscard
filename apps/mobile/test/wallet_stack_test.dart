import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softxu/features/wallet/test_cards.dart';
import 'package:softxu/features/wallet/wallet_stack.dart';

void main() {
  testWidgets('cards wait in the wallet, then deal into a horizontal row', (
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

    final adaCard = find.byKey(const ValueKey('wallet-pass-0'));
    final graceCard = find.byKey(const ValueKey('wallet-pass-1'));
    final adaBox = tester.getRect(adaCard);
    final graceBox = tester.getRect(graceCard);
    expect((adaBox.top - graceBox.top).abs(), lessThan(1));
    expect((adaBox.height - graceBox.height).abs(), lessThan(1));
    expect(graceBox.width / graceBox.height, closeTo(1.72, 0.03));
    expect(graceBox.center.dx, greaterThan(adaBox.center.dx + 40));
    expect(graceBox.left, greaterThan(adaBox.left + 28));
    expect(graceBox.left, lessThan(adaBox.right - 8));
    expect((graceBox.left - adaBox.left) / graceBox.width, closeTo(0.24, 0.02));
    expect(adaBox.left, greaterThanOrEqualTo(12));
    expect(graceBox.right, lessThanOrEqualTo(378));
    expect(adaBox.left, closeTo(16, 2));
    expect(graceBox.right, closeTo(374, 2));
    expect(graceBox.width, lessThan(pocketWidth));
    expect(tester.getTopLeft(find.text('Ada')).dy, lessThan(adaBox.top + 40));
    expect(
      tester.getTopLeft(find.text('Studio')).dy,
      greaterThan(tester.getTopLeft(find.text('Ada')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Studio')).dy,
      lessThan(adaBox.top + 56),
    );
    expect(find.text('Close wallet'), findsOneWidget);

    final beforeCard = tester.getRect(graceCard);
    final beforeText = tester.getTopLeft(find.text('Grace')).dy;
    final adaTop = tester.getRect(adaCard).top;
    final resting = tester.getCenter(graceCard);
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: resting);
    await pointer.moveTo(resting);
    await tester.pumpAndSettle();
    final afterCard = tester.getRect(graceCard);
    final afterText = tester.getTopLeft(find.text('Grace')).dy;
    expect(beforeCard.top - afterCard.top, closeTo(16, 2));
    expect(afterCard.height, closeTo(beforeCard.height, 1));
    expect(afterCard.width, closeTo(beforeCard.width, 1));
    expect((tester.getRect(adaCard).top - adaTop).abs(), lessThan(1));
    expect(beforeText - afterText, closeTo(16, 3));
    expect(afterText, lessThan(afterCard.top + 40));
    await pointer.removePointer();
    await tester.pumpAndSettle();

    final graceRest = tester.getRect(graceCard);
    final graceTextRest = tester.getTopLeft(find.text('Grace')).dy;
    await tester.tap(find.text('Grace'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-card')), findsNothing);
    final graceHalf = tester.getRect(graceCard);
    final graceText = tester.getTopLeft(find.text('Grace')).dy;
    expect(graceRest.top - graceHalf.top, closeTo(16, 2));
    expect(graceHalf.height, closeTo(graceRest.height, 1));
    expect(graceTextRest - graceText, closeTo(16, 3));
    expect(graceText, lessThan(graceHalf.top + 40));

    await tester.tapAt(Offset(graceHalf.center.dx, graceHalf.top + 28));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-card')), findsNothing);
    expect(find.text('Close'), findsNothing);
    expect(find.text('Grace'), findsOneWidget);

    final adaRest = tester.getRect(adaCard);
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-card')), findsNothing);
    final adaHalf = tester.getRect(adaCard);
    expect(adaRest.top - adaHalf.top, closeTo(16, 2));
    expect(adaHalf.height, closeTo(adaRest.height, 1));
    expect(
      (tester.getRect(graceCard).top - graceRest.top).abs(),
      lessThan(1.5),
    );
  });

  testWidgets('one click only half-opens even when it delivers two taps', (
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
    await tester.tap(find.text('Open wallet'));
    await tester.pumpAndSettle();

    final adaCard = find.byKey(const ValueKey('wallet-pass-0'));
    final before = tester.getRect(adaCard);
    final graceBefore = tester.getTopLeft(find.text('Grace')).dy;
    await tester.tap(find.text('Ada'));
    await tester.tap(find.text('Ada'));
    await tester.pump();
    expect(find.byKey(const ValueKey('open-card')), findsNothing);
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byKey(const ValueKey('open-card')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-card')), findsNothing);

    final half = tester.getRect(adaCard);
    expect(before.top - half.top, closeTo(16, 2));
    expect(half.height, closeTo(before.height, 1));
    expect(tester.getTopLeft(find.text('Ada')).dy, lessThan(half.top + 40));
    expect(
      tester.getTopLeft(find.text('Studio')).dy,
      greaterThan(tester.getTopLeft(find.text('Ada')).dy),
    );
    expect(
      (tester.getTopLeft(find.text('Grace')).dy - graceBefore).abs(),
      lessThan(2),
    );

    await tester.tapAt(Offset(half.center.dx, half.top + 28));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-card')), findsNothing);
    expect(find.text('Close'), findsNothing);
    expect(tester.getRect(adaCard).height, closeTo(half.height, 1));
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
    expect(find.byKey(const ValueKey('open-card')), findsNothing);
    await tester.tap(find.text(card.name));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-card')), findsNothing);
    expect(find.text('Close'), findsNothing);
    expect(find.text(card.name), findsOneWidget);
    expect(find.text(card.category), findsOneWidget);
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

    final meera = tester.getRect(find.byKey(const ValueKey('wallet-pass-0')));
    final jonah = tester.getRect(find.byKey(const ValueKey('wallet-pass-19')));
    expect((meera.top - jonah.top).abs(), lessThan(1));
    expect((meera.height - jonah.height).abs(), lessThan(1));
    expect(jonah.center.dx, greaterThan(meera.center.dx + 400));
    expect(jonah.right, closeTo(374, 2));
    expect(jonah.width / jonah.height, closeTo(1.72, 0.03));
    final firstVisible = tester.getRect(
      find.byKey(const ValueKey('wallet-pass-16')),
    );
    expect(firstVisible.left, closeTo(16, 2));
    for (var i = 16; i < 19; i++) {
      final left = tester.getRect(find.byKey(ValueKey('wallet-pass-$i')));
      final right = tester.getRect(
        find.byKey(ValueKey('wallet-pass-${i + 1}')),
      );
      expect((left.top - right.top).abs(), lessThan(1));
      expect((right.left - left.left) / jonah.width, closeTo(0.24, 0.02));
      expect(right.left, lessThan(left.right - 8));
    }
    expect(
      tester.getTopLeft(find.text('Jonah Brooks')).dy,
      lessThan(jonah.top + 40),
    );
    expect(
      tester.getTopLeft(find.text(testCards.last.category)).dy,
      greaterThan(tester.getTopLeft(find.text('Jonah Brooks')).dy),
    );

    final jonahCard = find.byKey(const ValueKey('wallet-pass-19'));
    final beforeCard = tester.getRect(jonahCard);
    final beforeText = tester.getTopLeft(find.text('Jonah Brooks')).dy;
    final resting = tester.getCenter(jonahCard);
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: resting);
    await pointer.moveTo(resting);
    await tester.pumpAndSettle();
    final afterCard = tester.getRect(jonahCard);
    final afterText = tester.getTopLeft(find.text('Jonah Brooks')).dy;
    expect(beforeCard.top - afterCard.top, closeTo(16, 2));
    expect(afterCard.height, closeTo(beforeCard.height, 1));
    expect(beforeText - afterText, closeTo(16, 3));
    expect(afterText, lessThan(afterCard.top + 40));
    await pointer.removePointer();
    await tester.pumpAndSettle();
    expect(find.text('Close wallet'), findsOneWidget);
  });

  testWidgets('a wheel scroll or horizontal drag shifts the open row', (
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

    final card = find.byKey(const ValueKey('wallet-pass-0'));
    final before = tester.getCenter(card);
    final beforeHeight = tester.getSize(card).height;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(CardsStage)),
        scrollDelta: const Offset(0, 140),
      ),
    );
    await tester.pumpAndSettle();
    final scrolled = tester.getCenter(card);
    expect(scrolled.dx, greaterThan(before.dx + 40));
    expect((scrolled.dy - before.dy).abs(), lessThan(1));

    final gesture = await tester.startGesture(scrolled);
    await gesture.moveBy(const Offset(-110, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(card).dx, lessThan(scrolled.dx - 30));
    expect(tester.getSize(card).height, closeTo(beforeHeight, 1));
    expect(find.byKey(const ValueKey('open-card')), findsNothing);

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

  testWidgets('a wide window centers the same overlapping row', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
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
              WalletPass(label: 'Jonah', detail: 'Lead'),
              WalletPass(label: 'Meera', detail: 'Brand'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open wallet'));
    await tester.pumpAndSettle();

    final rects = [
      for (var i = 0; i < 4; i++)
        tester.getRect(find.byKey(ValueKey('wallet-pass-$i'))),
    ];
    final step = rects[1].left - rects[0].left;
    expect(step / rects.last.width, closeTo(0.24, 0.02));
    for (var i = 0; i < rects.length; i++) {
      expect((rects[i].top - rects.first.top).abs(), lessThan(1));
      expect((rects[i].height - rects.first.height).abs(), lessThan(1));
      if (i > 0) {
        expect((rects[i].left - rects[i - 1].left - step).abs(), lessThan(1));
        expect(rects[i].left, lessThan(rects[i - 1].right - 8));
      }
    }
    final leftInset = rects.first.left;
    final rightInset = 1200 - rects.last.right;
    expect((leftInset - rightInset).abs(), lessThan(2));
    expect(leftInset, greaterThan(80));
    expect(rects.last.width / rects.last.height, closeTo(1.72, 0.03));
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

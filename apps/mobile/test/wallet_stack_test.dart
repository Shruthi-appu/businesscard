import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softxu/features/wallet/card_fields.dart';
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
    final pocketWidth = tester
        .getSize(find.byKey(const ValueKey('wallet-pocket')))
        .width;
    expect(pocketWidth, closeTo(366, 1));
    _expectHeaderRow(tester);

    await tester.tap(find.text('Open wallet'));
    await tester.pumpAndSettle();

    final ada = tester.getCenter(find.text('Ada'));
    final grace = tester.getCenter(find.text('Grace'));
    final cardBox = tester.getRect(find.byKey(const ValueKey('wallet-pass-0')));
    expect(grace.dy, greaterThan(ada.dy + 12));
    expect(cardBox.width, closeTo(362, 1));
    expect(cardBox.width, lessThanOrEqualTo(pocketWidth + 0.5));
    expect(cardBox.left, greaterThanOrEqualTo(12));
    expect(cardBox.right, lessThanOrEqualTo(378));
    expect(cardBox.height / cardBox.width, closeTo(1.7, 0.02));
    expect(tester.getTopLeft(find.text('Ada')).dy, lessThan(cardBox.top + 48));
    expect(
      tester.getTopLeft(find.text('Studio')).dy,
      greaterThan(tester.getTopLeft(find.text('Ada')).dy),
    );
    _expectCategoryClearOfNextCard(tester, 'Studio', 0);
    expect(find.text('Close wallet'), findsOneWidget);

    final graceCard = find.byKey(const ValueKey('wallet-pass-1'));
    final beforeCard = tester.getRect(graceCard);
    final beforeText = tester.getTopLeft(find.text('Grace')).dy;
    final resting = tester.getCenter(find.text('Grace'));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: resting);
    await pointer.moveTo(resting);
    await tester.pumpAndSettle();
    final afterCard = tester.getRect(graceCard);
    final afterText = tester.getTopLeft(find.text('Grace')).dy;
    expect((afterCard.top - beforeCard.top).abs(), lessThan(12));
    expect(
      afterCard.height,
      closeTo(beforeCard.height * 1.5, beforeCard.height * 0.12),
    );
    expect((afterText - beforeText).abs(), lessThan(40));
    expect(afterText, lessThan(afterCard.top + 56));
    await pointer.removePointer();
    await tester.pumpAndSettle();

    final graceRest = tester.getRect(graceCard);
    final graceTextRest = tester.getTopLeft(find.text('Grace')).dy;
    await tester.tap(find.text('Grace'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-card')), findsNothing);
    final graceHalf = tester.getRect(graceCard);
    final graceText = tester.getTopLeft(find.text('Grace')).dy;
    expect((graceHalf.top - graceRest.top).abs(), lessThan(12));
    expect(
      graceHalf.height,
      closeTo(graceRest.height * 1.5, graceRest.height * 0.12),
    );
    expect((graceText - graceTextRest).abs(), lessThan(40));
    expect(graceText, lessThan(graceHalf.top + 56));

    await tester.tapAt(Offset(graceHalf.center.dx, graceHalf.top + 28));
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

    final adaCard = find.byKey(const ValueKey('wallet-pass-0'));
    final adaRest = tester.getRect(adaCard);
    final graceBeforeSlide = tester.getTopLeft(find.text('Grace')).dy;
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-card')), findsNothing);
    final adaHalf = tester.getRect(adaCard);
    expect((adaHalf.top - adaRest.top).abs(), lessThan(12));
    expect(
      adaHalf.height,
      closeTo(adaRest.height * 1.5, adaRest.height * 0.12),
    );
    expect(
      tester.getTopLeft(find.text('Grace')).dy,
      greaterThan(graceBeforeSlide + 12),
    );
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

    final open = find.byKey(const ValueKey('open-card'));
    expect(open, findsOneWidget);
    for (final title in const [
      'Name',
      'Business category',
      'Address',
      'Location',
      'WhatsApp',
      'Facebook',
      'Instagram',
      'QR code',
      'Website',
    ]) {
      expect(
        _inOpen(open, find.text(title, skipOffstage: false)),
        findsNothing,
      );
    }
    for (final value in [
      card.name,
      card.category,
      card.address,
      card.location,
      card.whatsapp,
      card.facebook,
      card.instagram,
      card.qr,
      card.website,
    ]) {
      expect(
        _inOpen(open, find.text(value, skipOffstage: false)),
        findsOneWidget,
      );
    }
    expect(
      _inOpen(
        open,
        find.textContaining('google.com/maps', skipOffstage: false),
      ),
      findsOneWidget,
    );
    expect(
      _inOpen(open, find.byIcon(cardNameIcon, skipOffstage: false)),
      findsOneWidget,
    );
    expect(
      _inOpen(open, find.byIcon(cardCategoryIcon, skipOffstage: false)),
      findsOneWidget,
    );
    expect(
      _inOpen(open, find.byIcon(cardAddressIcon, skipOffstage: false)),
      findsOneWidget,
    );
    expect(
      _inOpen(open, find.byIcon(cardLocationIcon, skipOffstage: false)),
      findsOneWidget,
    );
    expect(
      _inOpen(open, find.byIcon(cardWhatsappIcon, skipOffstage: false)),
      findsOneWidget,
    );
    expect(
      _inOpen(open, find.byIcon(Icons.facebook, skipOffstage: false)),
      findsOneWidget,
    );
    expect(
      _inOpen(open, find.byType(InstagramMark, skipOffstage: false)),
      findsOneWidget,
    );
    expect(
      _inOpen(open, find.byIcon(cardQrIcon, skipOffstage: false)),
      findsOneWidget,
    );
    expect(
      _inOpen(open, find.byIcon(cardWebsiteIcon, skipOffstage: false)),
      findsOneWidget,
    );
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
    for (var i = 0; i < testCards.length - 1; i++) {
      _expectCategoryClearOfNextCard(tester, testCards[i].category, i);
    }
    final lastDetail = tester.getRect(find.text(testCards.last.category));
    expect(lastDetail.top, greaterThanOrEqualTo(0));
    expect(lastDetail.bottom, lessThanOrEqualTo(844));

    final meeraCard = find.byKey(const ValueKey('wallet-pass-0'));
    final beforeCard = tester.getRect(meeraCard);
    final beforeText = tester.getTopLeft(find.text('Meera Iyer')).dy;
    final resting = tester.getCenter(find.text('Meera Iyer'));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: resting);
    await pointer.moveTo(resting);
    await tester.pumpAndSettle();
    final afterCard = tester.getRect(meeraCard);
    final afterText = tester.getTopLeft(find.text('Meera Iyer')).dy;
    expect((afterCard.top - beforeCard.top).abs(), lessThan(12));
    expect(
      afterCard.height,
      closeTo(beforeCard.height * 1.5, beforeCard.height * 0.12),
    );
    expect((afterText - beforeText).abs(), lessThan(48));
    expect(afterText, lessThan(afterCard.top + 56));
    await pointer.removePointer();
    await tester.pumpAndSettle();
    expect(find.text('Close wallet'), findsOneWidget);
  });

  testWidgets('a vertical scroll or drag shifts the open fan', (tester) async {
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
    expect(scrolled.dy, greaterThan(before.dy + 40));

    final gesture = await tester.startGesture(scrolled);
    await gesture.moveBy(const Offset(0, -110));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(card).dy, lessThan(scrolled.dy - 30));
    expect(tester.getSize(card).height, closeTo(beforeHeight, 12));
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

Finder _inOpen(Finder open, Finder matching) {
  return find.descendant(of: open, matching: matching, skipOffstage: false);
}

/// The category line sits above the next card, so both it and the name show.
void _expectCategoryClearOfNextCard(
  WidgetTester tester,
  String category,
  int index,
) {
  final text = tester.getRect(find.text(category));
  final card = _paintedCard(tester, index);
  final next = _paintedCard(tester, index + 1);
  final stageBottom =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  expect(next.overlaps(text), isFalse, reason: category);
  expect(text.bottom, lessThanOrEqualTo(next.top + 0.5), reason: category);
  expect(
    next.top,
    greaterThanOrEqualTo(card.top + (text.bottom - card.top) - 0.5),
  );
  expect(text.top, greaterThanOrEqualTo(0), reason: category);
  expect(text.bottom, lessThanOrEqualTo(stageBottom + 0.5), reason: category);
}

Rect _paintedCard(WidgetTester tester, int index) {
  final card = find.byKey(ValueKey('wallet-pass-$index'));
  final transform = find.descendant(of: card, matching: find.byType(Transform));
  final render = tester.renderObject<RenderTransform>(transform);
  final child = render.child!;
  return MatrixUtils.transformRect(
    child.getTransformTo(null),
    Offset.zero & child.size,
  );
}

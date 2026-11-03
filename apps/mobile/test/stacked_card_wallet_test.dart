import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softxu/features/wallet/business_card.dart';
import 'package:softxu/features/wallet/stacked_card_wallet.dart';

void main() {
  testWidgets('tap, swipe, add, and remove keep the vertical column', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    var cards = _sample();
    var opened = '';
    await tester.pumpWidget(
      _host(cards, onOpen: (index) => opened = cards[index].name),
    );
    await tester.pumpAndSettle();

    final front = tester.getRect(find.byKey(const ValueKey('card-arjun')));
    final meera = tester.getRect(find.byKey(const ValueKey('card-meera')));
    final rohan = tester.getRect(find.byKey(const ValueKey('card-rohan')));
    final ananya = tester.getRect(find.byKey(const ValueKey('card-ananya')));
    expect((meera.left - front.left).abs(), lessThan(2));
    expect((rohan.left - front.left).abs(), lessThan(2));
    expect((ananya.left - front.left).abs(), lessThan(2));
    expect(meera.top, lessThan(front.bottom - 12));
    expect(rohan.top, lessThan(meera.bottom - 12));
    expect(ananya.top, lessThan(rohan.bottom - 12));
    expect(front.left, lessThan(14));
    expect(front.right, greaterThan(370));
    expect((front.width - meera.width).abs(), lessThan(2));
    expect((meera.width - rohan.width).abs(), lessThan(2));
    expect(ananya.right, lessThanOrEqualTo(390));
    expect(ananya.top, greaterThanOrEqualTo(0));
    expect(front.bottom, lessThanOrEqualTo(844));
    expect(front.width / front.height, closeTo(2.05, 0.08));
    final nameStyle = tester.widget<Text>(find.text('Arjun Menon')).style!;
    final roleStyle = tester.widget<Text>(find.text('Lawyer')).style!;
    expect(nameStyle.fontSize, greaterThanOrEqualTo(28));
    expect(roleStyle.fontSize, greaterThanOrEqualTo(18));
    expect(nameStyle.fontSize!, greaterThan(roleStyle.fontSize!));

    await tester.tap(find.text('Meera Iyer'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    final meeraFront = tester.getRect(find.byKey(const ValueKey('card-meera')));
    final rohanUnder = tester.getRect(find.byKey(const ValueKey('card-rohan')));
    final arjunBack = tester.getRect(find.byKey(const ValueKey('card-arjun')));
    expect((meeraFront.left - rohanUnder.left).abs(), lessThan(2));
    expect((meeraFront.left - arjunBack.left).abs(), lessThan(2));
    expect(rohanUnder.top, lessThan(meeraFront.bottom - 12));
    expect(arjunBack.top, greaterThan(meeraFront.bottom));

    await tester.tap(find.text('Meera Iyer'));
    await tester.pumpAndSettle();
    expect(opened, 'Meera Iyer');

    await tester.fling(
      find.byKey(const ValueKey('stacked-card-wallet')),
      const Offset(-220, 0),
      900,
    );
    await tester.pumpAndSettle();
    final rohanFront = tester.getRect(find.byKey(const ValueKey('card-rohan')));
    final ananyaUnder = tester.getRect(find.byKey(const ValueKey('card-ananya')));
    final meeraBelow = tester.getRect(find.byKey(const ValueKey('card-meera')));
    expect((rohanFront.left - ananyaUnder.left).abs(), lessThan(2));
    expect((rohanFront.left - meeraBelow.left).abs(), lessThan(2));
    expect(ananyaUnder.top, lessThan(rohanFront.bottom - 12));
    expect(meeraBelow.top, greaterThan(rohanFront.top));

    cards = [
      ...cards,
      const BusinessCardData(
        id: 'card-kabir',
        name: 'Kabir Shah',
        designation: 'Chef',
        background: Color(0xFFE8F3FD),
      ),
    ];
    await tester.pumpWidget(
      _host(cards, onOpen: (index) => opened = cards[index].name),
    );
    await tester.pumpAndSettle();
    final kabir = tester.getRect(find.byKey(const ValueKey('card-kabir')));
    final rohanNow = tester.getRect(find.byKey(const ValueKey('card-rohan')));
    expect((kabir.left - rohanNow.left).abs(), lessThan(2));
    expect(kabir.top, greaterThan(rohanNow.bottom - 1));
    expect(kabir.right, lessThanOrEqualTo(390));

    cards = [
      for (final card in cards)
        if (card.id != 'card-rohan') card,
    ];
    await tester.pumpWidget(
      _host(cards, onOpen: (index) => opened = cards[index].name),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rohan Desai'), findsNothing);
    final nextFront = tester.getRect(find.byKey(const ValueKey('card-arjun')));
    final behind = tester.getRect(find.byKey(const ValueKey('card-meera')));
    expect((nextFront.left - behind.left).abs(), lessThan(2));
    expect(behind.top, lessThan(nextFront.bottom - 12));
  });

  testWidgets('moving the pointer up brings the next card forward', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_host(_sample(), onOpen: (_) {}));
    await tester.pumpAndSettle();

    final arjun = find.byKey(const ValueKey('card-arjun'));
    final meera = find.byKey(const ValueKey('card-meera'));
    expect(tester.getRect(arjun).top, lessThan(tester.getRect(meera).top));

    final nudge = await tester.startGesture(tester.getCenter(arjun));
    await nudge.moveBy(const Offset(0, -12));
    await nudge.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(arjun).top, lessThan(tester.getRect(meera).top));

    final lift = await tester.startGesture(tester.getCenter(arjun));
    await lift.moveBy(const Offset(0, -80));
    await lift.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(meera).top, lessThan(tester.getRect(arjun).top));
    expect(
      (tester.getRect(meera).left - tester.getRect(arjun).left).abs(),
      lessThan(2),
    );
  });

  testWidgets('the pile fits a narrow phone and a wide phone', (tester) async {
    for (final size in const [Size(320, 700), Size(430, 932)]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(_host(_sample(), onOpen: (_) {}));
      await tester.pumpAndSettle();
      for (final id in const [
        'card-arjun',
        'card-meera',
        'card-rohan',
        'card-ananya',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(id)));
        expect(
          rect.left,
          greaterThanOrEqualTo(-1),
          reason: '$id ${size.width}',
        );
        expect(rect.top, greaterThanOrEqualTo(-1), reason: id);
        expect(rect.right, lessThanOrEqualTo(size.width + 1), reason: id);
        expect(rect.bottom, lessThanOrEqualTo(size.height + 1), reason: id);
        expect(rect.width / rect.height, closeTo(2.05, 0.08), reason: id);
      }
    }
  });
}

List<BusinessCardData> _sample() {
  return const [
    BusinessCardData(
      id: 'card-arjun',
      name: 'Arjun Menon',
      designation: 'Lawyer',
      background: Color(0xFFE4D8F6),
    ),
    BusinessCardData(
      id: 'card-meera',
      name: 'Meera Iyer',
      designation: 'Studio Lead',
      background: Color(0xFFF9D5E2),
    ),
    BusinessCardData(
      id: 'card-rohan',
      name: 'Rohan Desai',
      designation: 'Architect',
      background: Color(0xFFD5F3E6),
    ),
    BusinessCardData(
      id: 'card-ananya',
      name: 'Ananya Rao',
      designation: 'Designer',
      background: Color(0xFFFFF6CC),
    ),
  ];
}

Widget _host(
  List<BusinessCardData> cards, {
  required ValueChanged<int> onOpen,
}) {
  return MaterialApp(
    home: Scaffold(
      body: StackedBusinessCardWallet(
        cards: cards,
        reveal: 1,
        topInset: 24,
        tuckCenter: const Offset(180, 500),
        tuckWidth: 280,
        tuckHeight: 170,
        onOpen: onOpen,
      ),
    ),
  );
}

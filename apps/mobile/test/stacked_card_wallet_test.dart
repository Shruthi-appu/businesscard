import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softxu/features/wallet/business_card.dart';
import 'package:softxu/features/wallet/stacked_card_wallet.dart';

void main() {
  testWidgets('tap, swipe, add, and remove keep the layered pile', (
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
    expect(meera.top, lessThan(front.top - 8));
    expect(rohan.top, lessThan(meera.top - 6));
    expect(ananya.top, lessThan(rohan.top - 4));
    expect(meera.left, greaterThan(front.left + 8));
    expect(rohan.left, greaterThan(meera.left + 4));
    expect(ananya.left, greaterThan(rohan.left + 2));
    expect(front.width, greaterThan(meera.width));
    expect(meera.width, greaterThan(rohan.width));
    final firstGap = meera.left - front.left;
    final secondGap = rohan.left - meera.left;
    final thirdGap = ananya.left - rohan.left;
    expect(firstGap, greaterThan(secondGap + 2));
    expect(secondGap, greaterThan(thirdGap + 2));
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
    expect(
      tester.getRect(find.byKey(const ValueKey('card-meera'))).width,
      greaterThan(
        tester.getRect(find.byKey(const ValueKey('card-arjun'))).width,
      ),
    );

    await tester.tap(find.text('Meera Iyer'));
    await tester.pumpAndSettle();
    expect(opened, 'Meera Iyer');

    await tester.fling(
      find.byKey(const ValueKey('stacked-card-wallet')),
      const Offset(-220, 0),
      900,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('card-rohan'))).width,
      greaterThan(
        tester.getRect(find.byKey(const ValueKey('card-meera'))).width,
      ),
    );

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
    expect(kabir.top, lessThan(rohanNow.top));
    expect(kabir.left, greaterThan(rohanNow.left));
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
    expect(nextFront.width, greaterThan(behind.width));
    expect(behind.top, lessThan(nextFront.top));
    expect(behind.left, greaterThan(nextFront.left));
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softxu/features/wallet/card_fields.dart';
import 'package:softxu/features/wallet/card_links.dart';
import 'package:softxu/features/wallet/sample_card_screen.dart';
import 'package:softxu/features/wallet/test_cards.dart';
import 'package:softxu/features/wallet/wallet_stack.dart';

void main() {
  test('each stored fact opens the matching app or site', () {
    final card = testCards.first;

    expect(linkForFact(field: 'name', value: card.name), isNull);
    expect(linkForFact(field: 'category', value: card.category), isNull);
    expect(
      linkForFact(field: 'name', value: 'https://ada.example').toString(),
      'https://ada.example',
    );

    final map = linkForFact(
      field: 'location',
      value: card.location,
      extra: locationUrl(card.location),
    )!;
    expect(map.scheme, 'https');
    expect(map.host, contains('google.'));
    expect(map.path, contains('maps'));
    expect(map.queryParameters['query'], card.location);

    final address = linkForFact(field: 'address', value: card.address)!;
    expect(address.host, contains('google.'));
    expect(address.queryParameters['query'], card.address);

    expect(
      linkForFact(field: 'whatsapp', value: card.whatsapp).toString(),
      'https://wa.me/919000010001',
    );
    expect(
      linkForFact(
        field: 'whatsapp',
        value: 'https://wa.me/919000010099',
      ).toString(),
      'https://wa.me/919000010099',
    );
    expect(
      linkForFact(field: 'facebook', value: card.facebook).toString(),
      card.facebook,
    );
    expect(
      linkForFact(field: 'facebook', value: '@analytical').toString(),
      'https://www.facebook.com/analytical',
    );
    expect(
      linkForFact(field: 'instagram', value: card.instagram).toString(),
      card.instagram,
    );
    expect(
      linkForFact(field: 'instagram', value: 'analytical').toString(),
      'https://www.instagram.com/analytical',
    );
    expect(
      linkForFact(field: 'website', value: card.website).toString(),
      card.website,
    );
    expect(linkForFact(field: 'qr', value: card.qr).toString(), card.qr);
    expect(
      linkForFact(field: 'phone', value: '+91 90000 10001').toString(),
      'tel:+919000010001',
    );
    expect(
      linkForFact(field: 'email', value: 'ada@example.com').toString(),
      'mailto:ada@example.com',
    );
  });

  testWidgets(
    'tapping WhatsApp or the map on an open card launches that link',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final card = testCards.first;
      final launched = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardsStage(
              onAdd: () {},
              onScan: () {},
              onDesign: () {},
              openLink: (url) async => launched.add(url),
              passes: [card.toPass()],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open wallet'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wallet-pass-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open-card')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('wallet-pass-0')));
      await tester.pumpAndSettle();

      final open = find.byKey(const ValueKey('open-card'));
      expect(open, findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('Location'), findsNothing);
      expect(
        find.descendant(of: open, matching: find.text(card.whatsapp)),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('card-link-location')));
      await tester.pump();
      await tester.tap(
        find.descendant(of: open, matching: find.text(card.name)),
      );
      await tester.pump();
      await _reveal(tester, const ValueKey('card-link-whatsapp'));
      await tester.tap(find.byKey(const ValueKey('card-link-whatsapp')));
      await tester.pump();

      expect(find.byKey(const ValueKey('open-card')), findsOneWidget);
      expect(launched, hasLength(2));
      expect(launched[0].host, contains('google.'));
      expect(launched[0].path, contains('maps'));
      expect(launched[0].queryParameters['query'], card.location);
      expect(launched[1].toString(), 'https://wa.me/919000010001');
      expect(find.byKey(const ValueKey('card-link-name')), findsNothing);
      expect(find.byKey(const ValueKey('card-link-category')), findsNothing);
    },
  );

  testWidgets('a sample card and a saved fact row launch the stored link', (
    tester,
  ) async {
    final card = testCards.first;
    final launched = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SampleCardScreen(
          card: card,
          openLink: (url) async => launched.add(url),
        ),
      ),
    );

    await _reveal(tester, const ValueKey('card-link-whatsapp'));
    await tester.tap(find.byKey(const ValueKey('card-link-whatsapp')));
    await tester.pump();
    await _reveal(tester, const ValueKey('card-link-facebook'));
    await tester.tap(find.byKey(const ValueKey('card-link-facebook')));
    await tester.pump();
    await tester.tap(find.text(card.category));
    await tester.pump();

    expect(launched.map((url) => url.toString()), [
      'https://wa.me/919000010001',
      card.facebook,
    ]);

    launched.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardFactRow(
            field: 'location',
            value: card.location,
            launcher: (url) async => launched.add(url),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('card-link-location')));
    await tester.pump();
    expect(launched.single.queryParameters['query'], card.location);

    launched.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardFactRow(
            field: 'phone',
            value: '+1 415 555 0100',
            launcher: (url) async => launched.add(url),
          ),
        ),
      ),
    );
    await tester.tap(find.text('+1 415 555 0100'));
    await tester.pump();
    expect(launched.single.toString(), 'tel:+14155550100');
  });
}

Future<void> _reveal(WidgetTester tester, ValueKey<String> key) {
  return tester.ensureVisible(find.byKey(key, skipOffstage: false));
}

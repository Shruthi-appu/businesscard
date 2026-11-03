import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softxu/features/wallet/card_fields.dart';
import 'package:softxu/features/wallet/sample_card_screen.dart';
import 'package:softxu/features/wallet/test_cards.dart';

void main() {
  test('each sample card stores every detail', () {
    expect(testCards, hasLength(20));
    for (final card in testCards) {
      expect(card.name, isNotEmpty);
      expect(card.category, isNotEmpty);
      expect(card.address, isNotEmpty);
      expect(card.location, isNotEmpty);
      expect(card.whatsapp, startsWith('+91'));
      expect(card.facebook, contains('facebook.com'));
      expect(card.instagram, contains('instagram.com'));
      expect(card.qr, startsWith('https://'));
      expect(card.website, startsWith('https://'));
      expect(locationUrl(card.location), contains('google.com/maps'));
    }
  });

  testWidgets('a sample card shows WhatsApp, Facebook, and the map', (
    tester,
  ) async {
    final card = testCards.first;
    await tester.pumpWidget(MaterialApp(home: SampleCardScreen(card: card)));
    expect(find.text('Name'), findsOneWidget);
    expect(find.text(card.name), findsWidgets);
    expect(find.text('Business category'), findsOneWidget);
    expect(find.text(card.category), findsOneWidget);
    expect(find.text('Address'), findsOneWidget);
    expect(find.text(card.address), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text(card.location), findsOneWidget);
    expect(find.textContaining('google.com/maps'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text(card.whatsapp), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text(card.facebook), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text(card.instagram), findsOneWidget);
    expect(find.text('QR code'), findsOneWidget);
    expect(find.text(card.qr), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text(card.website), findsOneWidget);
  });
}

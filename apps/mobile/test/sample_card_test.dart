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
    expect(find.text('Name'), findsNothing);
    expect(find.text(card.name), findsWidgets);
    expect(find.text('Business category'), findsNothing);
    expect(find.text(card.category), findsOneWidget);
    expect(find.text('Address'), findsNothing);
    expect(find.text(card.address), findsOneWidget);
    expect(find.text('Location'), findsNothing);
    expect(find.text(card.location), findsOneWidget);
    expect(find.textContaining('google.com/maps'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text(card.whatsapp), findsOneWidget);
    expect(find.text('Facebook'), findsNothing);
    expect(find.text(card.facebook), findsOneWidget);
    expect(find.text('Instagram'), findsNothing);
    expect(find.text(card.instagram), findsOneWidget);
    expect(find.text('QR code'), findsNothing);
    expect(find.text(card.qr), findsOneWidget);
    expect(find.text('Website'), findsNothing);
    expect(find.text(card.website), findsOneWidget);
    expect(find.byIcon(cardNameIcon), findsOneWidget);
    expect(find.byIcon(cardCategoryIcon), findsOneWidget);
    expect(find.byIcon(cardAddressIcon), findsOneWidget);
    expect(find.byIcon(cardLocationIcon), findsOneWidget);
    expect(find.byIcon(cardWhatsappIcon), findsOneWidget);
    expect(find.byIcon(Icons.facebook), findsOneWidget);
    expect(find.byType(InstagramMark), findsOneWidget);
    expect(find.byIcon(cardQrIcon), findsOneWidget);
    expect(find.byIcon(cardWebsiteIcon), findsOneWidget);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:softxu/app.dart';
import 'package:softxu/core/providers.dart';
import 'package:softxu/features/wallet/card_fields.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('card write keeps each filled detail', () {
    String? error;
    final draft = buildCardWrite(
      name: 'Ada Lovelace',
      category: 'Engines',
      address: '12 Engine Court',
      location: 'Koramangala',
      whatsapp: '+14155550100',
      facebook: '@analytical',
      instagram: 'analytical',
      qr: 'softxu.test/ada',
      website: 'analytical.example',
      onError: (message) => error = message,
    );

    expect(error, isNull);
    expect(draft, isNotNull);
    final body = draft!.createBody;
    expect(body['title'], 'Ada Lovelace');
    expect(body['contacts'], [
      {'kind': 'name', 'value': 'Ada Lovelace', 'isPrimary': true},
      {
        'kind': 'phone',
        'value': '+14155550100',
        'label': 'whatsapp',
        'whatsappState': 'yes',
      },
      {'kind': 'designation', 'label': 'category', 'value': 'Engines'},
      {'kind': 'website', 'value': 'https://analytical.example'},
    ]);
    expect(body['addresses'], [
      {'formattedAddress': '12 Engine Court'},
    ]);
    expect(body['socials'], [
      {
        'platform': 'location',
        'url': 'https://www.google.com/maps/search/?api=1&query=Koramangala',
      },
      {'platform': 'facebook', 'url': 'https://www.facebook.com/analytical'},
      {'platform': 'instagram', 'url': 'https://www.instagram.com/analytical'},
      {'platform': 'qr', 'url': 'https://softxu.test/ada'},
    ]);
  });

  test('a place saved as a map search reads back as the place', () {
    final details = readCardDetails({
      'contacts': [
        {
          'kind': 'phone',
          'value': '+14155550100',
          'label': 'whatsapp',
          'whatsappState': 'yes',
        },
        {'kind': 'phone', 'value': '+14155550199', 'whatsappState': 'unknown'},
        {'kind': 'designation', 'label': 'category', 'value': 'Engines'},
      ],
      'addresses': [
        {'formattedAddress': '12 Engine Court'},
      ],
      'socials': [
        {
          'platform': 'location',
          'url': 'https://www.google.com/maps/search/?api=1&query=Koramangala',
        },
      ],
    });

    expect(details.whatsapp, '+14155550100');
    expect(details.phone, '+14155550199');
    expect(details.category, 'Engines');
    expect(details.address, '12 Engine Court');
    expect(details.location, 'Koramangala');
  });

  test('a website needs a real link', () {
    String? error;
    final draft = buildCardWrite(
      name: 'Ada Lovelace',
      website: 'not a website',
      onError: (message) => error = message,
    );
    expect(draft, isNull);
    expect(error, 'Enter an http or https website.');
  });

  testWidgets('add card shows an icon for each detail and saves them', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? created;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientProvider.overrideWithValue(
            _Client((method, url, body) async {
              if (url.path == '/v1/auth/login') {
                return _json({
                  'tokenType': 'Bearer',
                  'accessToken': 'access-token',
                  'expiresIn': 900,
                  'refreshToken': 'refresh-token',
                  'user': {
                    'id': '00000000-0000-4000-8000-000000000001',
                    'email': 'ada@example.com',
                    'displayName': 'Ada Lovelace',
                    'role': 'user',
                  },
                });
              }
              if (url.path == '/v1/me') {
                return _json({
                  'id': '00000000-0000-4000-8000-000000000001',
                  'email': 'ada@example.com',
                  'phoneE164': null,
                  'displayName': 'Ada Lovelace',
                  'locale': null,
                  'countryCode': null,
                  'role': 'user',
                  'status': 'active',
                });
              }
              if (url.path == '/v1/cards' && method == 'GET') {
                return _json({'items': [], 'nextCursor': null});
              }
              if (url.path == '/v1/cards' && method == 'POST') {
                created = jsonDecode(body) as Map<String, dynamic>;
                return _json({
                  'id': '00000000-0000-4000-8000-000000000010',
                  ...created!,
                }, 201);
              }
              if (url.path ==
                  '/v1/cards/00000000-0000-4000-8000-000000000010') {
                return _json({
                  'id': '00000000-0000-4000-8000-000000000010',
                  'walletEntryId': '00000000-0000-4000-8000-000000000011',
                  'title': 'Ada Lovelace',
                  'versionId': '00000000-0000-4000-8000-000000000012',
                  'isFavourite': false,
                  'contacts': created?['contacts'] ?? [],
                  'addresses': created?['addresses'] ?? [],
                  'socials': created?['socials'] ?? [],
                  'tags': [],
                  'duplicateWarnings': [],
                });
              }
              return _json({
                'title': 'missing',
                'status': 404,
                'code': 'not_found',
              }, 404);
            }),
          ),
        ],
        child: const SoftxuApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'ada@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'correct-horse',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add+'));
    await tester.pumpAndSettle();

    expect(find.byIcon(cardNameIcon), findsOneWidget);
    expect(find.byIcon(cardCategoryIcon), findsOneWidget);
    expect(find.byIcon(cardAddressIcon), findsOneWidget);
    expect(find.byIcon(cardLocationIcon), findsOneWidget);
    expect(find.byIcon(cardWhatsappIcon), findsOneWidget);
    expect(find.byIcon(Icons.facebook), findsOneWidget);
    expect(find.byType(InstagramMark), findsOneWidget);
    expect(find.byIcon(cardQrIcon), findsOneWidget);
    expect(find.byIcon(cardWebsiteIcon), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save card'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Ada Lovelace',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Business category'),
      'Engines',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Address'),
      '12 Engine Court',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Location'),
      'Koramangala',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'WhatsApp'),
      '+14155550100',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Facebook'),
      '@analytical',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Instagram'),
      'analytical',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'QR code'),
      'softxu.test/ada',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Website'),
      'analytical.example',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save card'));
    await tester.pumpAndSettle();

    expect(created?['title'], 'Ada Lovelace');
    expect(find.text('Engines'), findsWidgets);
    expect(find.text('12 Engine Court'), findsWidgets);
    expect(find.text('Koramangala'), findsWidgets);
    expect(find.text('+14155550100'), findsWidgets);
    expect(find.text('https://www.facebook.com/analytical'), findsWidgets);
    expect(find.text('https://www.instagram.com/analytical'), findsWidgets);
    expect(find.text('https://softxu.test/ada'), findsWidgets);
    expect(find.text('https://analytical.example'), findsWidgets);
  });
}

http.Response _json(Object body, [int status = 200]) {
  return http.Response(jsonEncode(body), status);
}

class _Client extends http.BaseClient {
  _Client(this.handler);

  final Future<http.Response> Function(String method, Uri url, String body)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final response = await handler(
      request.method,
      request.url,
      utf8.decode(bytes),
    );
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

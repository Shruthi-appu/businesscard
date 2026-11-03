import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:softxu/app.dart';
import 'package:softxu/core/providers.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('wallet opens add, scan, and a card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [httpClientProvider.overrideWithValue(_client())],
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

    expect(find.text('Add+'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Design'), findsOneWidget);
    expect(find.text('IncardIt'), findsOneWidget);
    expect(find.text('Export my data'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsWidgets);

    await tester.tap(find.text('Open wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();
    expect(find.text('Share a link'), findsOneWidget);
    expect(find.text('Exchange in person'), findsOneWidget);
    expect(find.text('Edit card'), findsOneWidget);

    await tester.tap(find.text('Show QR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('https://softxu.test/exchange/session'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.ensureVisible(find.text('Scan'));
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read the sample card'));
    await tester.pumpAndSettle();
    expect(find.text('Check the fields'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
  });
}

http.Response _json(Object body, [int status = 200]) {
  return http.Response(jsonEncode(body), status);
}

_Client _client() {
  var completes = 0;
  return _Client((method, url, body) async {
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
      return _json({
        'items': [
          {
            'id': '00000000-0000-4000-8000-000000000010',
            'walletEntryId': '00000000-0000-4000-8000-000000000011',
            'title': 'Ada Lovelace',
            'cardType': 'manual',
            'source': 'manual',
            'isFavourite': false,
            'headline': 'Ada Lovelace',
            'company': 'Analytical Engines',
            'savedAt': '2026-11-02T00:00:00.000Z',
          },
        ],
        'nextCursor': null,
      });
    }
    if (url.path == '/v1/cards/00000000-0000-4000-8000-000000000010' &&
        method == 'GET') {
      return _json({
        'id': '00000000-0000-4000-8000-000000000010',
        'walletEntryId': '00000000-0000-4000-8000-000000000011',
        'title': 'Ada Lovelace',
        'versionId': '00000000-0000-4000-8000-000000000012',
        'isFavourite': false,
        'contacts': [
          {
            'id': '00000000-0000-4000-8000-000000000013',
            'kind': 'name',
            'value': 'Ada Lovelace',
          },
          {
            'id': '00000000-0000-4000-8000-000000000014',
            'kind': 'email',
            'value': 'ada@example.com',
          },
        ],
        'addresses': [],
        'socials': [],
        'tags': [],
        'duplicateWarnings': [],
      });
    }
    if (url.path == '/v1/exchange-sessions' && method == 'POST') {
      return _json({
        'id': '00000000-0000-4000-8000-000000000020',
        'url': 'https://softxu.test/exchange/session',
        'qrPngBase64': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        'expiresAt': '2099-01-01T00:00:00.000Z',
        'status': 'open',
        'mode': 'one_way',
      }, 201);
    }
    if (url.path == '/v1/scans' && method == 'POST') {
      return _json({
        'id': 'scan-1',
        'status': 'queued',
        'draftVersion': 0,
        'draft': null,
      }, 201);
    }
    if (url.path == '/v1/scans/scan-1/upload-url') {
      return _json({
        'assetId': 'asset-1',
        'method': 'POST',
        'uploadUrl': 'http://local/upload',
      });
    }
    if (url.path.startsWith('/v1/scans/scan-1/objects/')) {
      return _json({'stored': true});
    }
    if (url.path == '/v1/scans/scan-1/complete') {
      completes += 1;
      return _json({
        'id': 'scan-1',
        'status': completes == 2 ? 'needs_review' : 'queued',
        'draftVersion': 1,
        'draft': completes == 2
            ? [
                {'kind': 'name', 'value': 'Ada Lovelace'},
                {'kind': 'email', 'value': 'ada@analytical.example'},
              ]
            : null,
      });
    }
    return _json({'title': 'missing', 'status': 404, 'code': 'not_found'}, 404);
  });
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

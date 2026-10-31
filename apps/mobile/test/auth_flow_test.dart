import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:softxu/app.dart';
import 'package:softxu/core/auth_api.dart';
import 'package:softxu/core/providers.dart';
import 'package:softxu/features/wallet/wallet_cache.dart';
import 'package:softxu/features/wallet/wallet_controller.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('register shows a validation error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientProvider.overrideWithValue(
            _FakeClient((method, url, body) async {
              return http.Response(
                jsonEncode({
                  'type': 'about:blank',
                  'title': 'Validation failed',
                  'status': 400,
                  'code': 'validation_error',
                  'errors': [
                    {'field': 'password', 'message': 'Too short'},
                  ],
                }),
                400,
              );
            }),
          ),
        ],
        child: const SoftxuApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Display name'), 'Ada');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'ada@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Validation failed'), findsOneWidget);
    expect(find.textContaining('Too short'), findsOneWidget);
  });

  testWidgets('register opens an empty wallet and stores tokens', (tester) async {
    final backing = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(backing);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientProvider.overrideWithValue(_scriptedSuccess()),
        ],
        child: const SoftxuApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Display name'), 'Ada Lovelace');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'ada@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct-horse');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Signed in as Ada Lovelace'), findsOneWidget);
    expect(find.text('No cards yet'), findsOneWidget);
    expect(backing['access_token'], 'access-token');
    expect(backing['refresh_token'], 'refresh-token');
  });

  testWidgets('login shows a network failure', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientProvider.overrideWithValue(
            _FakeClient((method, url, body) async {
              throw http.ClientException('offline');
            }),
          ),
        ],
        child: const SoftxuApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'ada@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct-horse');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining("couldn't reach Softxu"), findsOneWidget);
  });

  testWidgets('wallet shows permission denied', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientProvider.overrideWithValue(
            _FakeClient((method, url, body) async {
              if (url.path == '/v1/auth/login') {
                return _authResponse(status: 200);
              }
              return http.Response(
                jsonEncode({
                  'type': 'about:blank',
                  'title': 'Account is not active',
                  'status': 403,
                  'code': 'forbidden',
                }),
                403,
              );
            }),
          ),
        ],
        child: const SoftxuApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'ada@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct-horse');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('do not have access'), findsOneWidget);
  });

  testWidgets('wallet shows cards saved on this device when the list fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletCacheProvider.overrideWithValue(
            WalletCacheStore(
              memory: {
                '00000000-0000-4000-8000-000000000001': const WalletSnapshot(
                  displayName: 'Ada Lovelace',
                  titles: ['Cached card'],
                ),
              },
            ),
          ),
          httpClientProvider.overrideWithValue(
            _FakeClient((method, url, body) async {
              if (url.path == '/v1/auth/login') return _authResponse(status: 200);
              if (url.path == '/v1/me') {
                return http.Response(
                  jsonEncode({
                    'id': '00000000-0000-4000-8000-000000000001',
                    'email': 'ada@example.com',
                    'phoneE164': null,
                    'displayName': 'Ada Lovelace',
                    'locale': null,
                    'countryCode': null,
                    'role': 'user',
                    'status': 'active',
                  }),
                  200,
                );
              }
              throw http.ClientException('offline');
            }),
          ),
        ],
        child: const SoftxuApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'ada@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct-horse');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Saved on this device. These cards may be out of date.'), findsOneWidget);
    expect(find.textContaining('Cached card'), findsWidgets);
  });
}

http.Response _authResponse({int status = 201}) {
  return http.Response(
    jsonEncode({
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
    }),
    status,
  );
}

_FakeClient _scriptedSuccess() {
  return _FakeClient((method, url, body) async {
    if (url.path == '/v1/auth/register') return _authResponse();
    if (url.path == '/v1/me') {
      return http.Response(
        jsonEncode({
          'id': '00000000-0000-4000-8000-000000000001',
          'email': 'ada@example.com',
          'phoneE164': null,
          'displayName': 'Ada Lovelace',
          'locale': null,
          'countryCode': null,
          'role': 'user',
          'status': 'active',
        }),
        200,
      );
    }
    if (url.path == '/v1/cards') {
      return http.Response(jsonEncode({'items': [], 'nextCursor': null}), 200);
    }
    return http.Response('{}', 404);
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);

  final Future<http.Response> Function(String method, Uri url, String body) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final response = await handler(request.method, request.url, utf8.decode(bytes));
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

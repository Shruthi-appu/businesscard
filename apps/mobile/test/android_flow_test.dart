import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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

  testWidgets('Android register opens the wallet on a phone', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final errors = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.exception);
      previous?.call(details);
    };
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [httpClientProvider.overrideWithValue(_scriptedSuccess())],
          child: const SoftxuApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(CupertinoApp), findsNothing);

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Display name'), 'Ada Lovelace');
      await tester.enterText(_field('Email'), 'ada@example.com');
      await tester.enterText(_field('Password'), 'correct-horse');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Signed in as Ada Lovelace'), findsOneWidget);
      expect(find.text('IncardIt'), findsOneWidget);
      expect(find.text('Open wallet'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      final menu = tester.getRect(find.byKey(const ValueKey('wallet-menu')));
      final signOut = tester.getRect(find.text('Sign out'));
      final bar = tester.getRect(find.byType(AppBar));
      final title = tester.getRect(find.text('IncardIt'));
      final add = tester.getRect(find.widgetWithText(InkWell, 'Add+'));
      final scan = tester.getRect(find.widgetWithText(InkWell, 'Scan'));
      final design = tester.getRect(find.widgetWithText(InkWell, 'Design'));
      expect(bar.contains(menu.center), isTrue);
      expect(menu.center.dx, lessThan(bar.center.dx));
      expect(menu.right, lessThan(signOut.left));
      expect(menu.shortestSide, greaterThanOrEqualTo(44));
      expect(title.left, lessThan(add.left));
      expect(add.left, lessThan(scan.left));
      expect(scan.left, lessThan(design.left));
      expect((add.center.dy - title.center.dy).abs(), lessThan(20));

      final pocketWidth = tester
          .getSize(find.byKey(const ValueKey('wallet-pocket')))
          .width;
      expect(pocketWidth, closeTo(366, 1));

      await tester.tap(find.text('Open wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Close wallet'), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet-pass-0')), findsOneWidget);
      final card = tester.getRect(find.byKey(const ValueKey('wallet-pass-0')));
      expect(card.width, closeTo(362, 1));
      expect(card.width, lessThanOrEqualTo(pocketWidth + 0.5));
      expect(find.byKey(const ValueKey('open-card')), findsNothing);
      expect(errors, isEmpty);

      await tester.tap(find.byKey(const ValueKey('wallet-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Export my data'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Export my data'), findsNothing);
      expect(find.text('IncardIt'), findsOneWidget);

      await tester.tap(find.text('Add+'));
      await tester.pumpAndSettle();
      expect(find.text('Add a card'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('IncardIt'), findsOneWidget);
      expect(errors, isEmpty);
    } finally {
      FlutterError.onError = previous;
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Finder _field(String label) {
  return find.widgetWithText(TextField, label);
}

http.Response _authResponse() {
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
    201,
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

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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

  testWidgets('iPhone register opens an empty wallet', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [httpClientProvider.overrideWithValue(_scriptedSuccess())],
          child: const SoftxuApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoApp), findsOneWidget);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Display name'), 'Ada Lovelace');
      await tester.enterText(_field('Email'), 'ada@example.com');
      await tester.enterText(_field('Password'), 'correct-horse');
      await tester.tap(find.widgetWithText(CupertinoButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Signed in as Ada Lovelace'), findsOneWidget);
      expect(find.text('IncardIt'), findsOneWidget);
      expect(find.text('Open wallet'), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iPhone wallet opens at phone size', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
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
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Display name'), 'Ada Lovelace');
      await tester.enterText(_field('Email'), 'ada@example.com');
      await tester.enterText(_field('Password'), 'correct-horse');
      await tester.tap(find.widgetWithText(CupertinoButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Open wallet'), findsOneWidget);
      await tester.tap(find.text('Open wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Close wallet'), findsOneWidget);
      expect(errors, isEmpty);
    } finally {
      FlutterError.onError = previous;
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Finder _field(String placeholder) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is CupertinoTextField && widget.placeholder == placeholder,
  );
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

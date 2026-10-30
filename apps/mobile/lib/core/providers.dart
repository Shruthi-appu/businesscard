import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'auth_api.dart';
import 'token_store.dart';

final apiOriginProvider = Provider<String>((ref) {
  const origin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'http://localhost:3001',
  );
  return origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin;
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(const FlutterSecureStorage()),
);

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(
    client: ref.watch(httpClientProvider),
    baseUrl: ref.watch(apiOriginProvider),
  );
});

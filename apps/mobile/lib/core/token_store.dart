import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredTokens {
  const StoredTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

class TokenStore {
  TokenStore(this.storage);

  final FlutterSecureStorage storage;

  static const accessKey = 'access_token';
  static const refreshKey = 'refresh_token';

  Future<StoredTokens?> read() async {
    final access = await storage.read(key: accessKey);
    final refresh = await storage.read(key: refreshKey);
    if (access == null || refresh == null || access.isEmpty || refresh.isEmpty) {
      return null;
    }
    return StoredTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> write({
    required String accessToken,
    required String refreshToken,
  }) async {
    await storage.write(key: accessKey, value: accessToken);
    await storage.write(key: refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    await storage.delete(key: accessKey);
    await storage.delete(key: refreshKey);
  }
}

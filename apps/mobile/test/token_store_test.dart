import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softxu/core/token_store.dart';

void main() {
  test('writes access and refresh tokens through secure storage', () async {
    final backing = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(backing);
    final store = TokenStore(const FlutterSecureStorage());

    await store.write(accessToken: 'access-1', refreshToken: 'refresh-1');

    expect(backing[TokenStore.accessKey], 'access-1');
    expect(backing[TokenStore.refreshKey], 'refresh-1');
    final read = await store.read();
    expect(read?.accessToken, 'access-1');
    expect(read?.refreshToken, 'refresh-1');

    await store.clear();
    expect(await store.read(), isNull);
    expect(backing.containsKey(TokenStore.accessKey), isFalse);
  });
}

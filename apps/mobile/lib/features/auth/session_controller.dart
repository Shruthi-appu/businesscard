import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_problem.dart';
import '../../core/auth_api.dart';
import '../../core/providers.dart';
import '../../core/token_store.dart';

class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    StoredTokens? stored;
    try {
      stored = await ref
          .read(tokenStoreProvider)
          .read()
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
    if (stored == null) return null;
    try {
      final session = await ref
          .read(authApiProvider)
          .refresh(stored.refreshToken)
          .timeout(const Duration(seconds: 6));
      await ref
          .read(tokenStoreProvider)
          .write(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
          );
      return session;
    } on TimeoutException {
      return sessionFromStored(stored);
    } on ApiProblem catch (error) {
      if (error.isNetwork) return sessionFromStored(stored);
      await ref.read(tokenStoreProvider).clear();
      return null;
    } catch (_) {
      return sessionFromStored(stored);
    }
  }

  Future<ApiProblem?> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _open(
      () => ref
          .read(authApiProvider)
          .register(email: email, password: password, displayName: displayName),
    );
  }

  Future<ApiProblem?> login({required String email, required String password}) {
    return _open(
      () => ref.read(authApiProvider).login(email: email, password: password),
    );
  }

  Future<ApiProblem?> logout() async {
    final stored = await ref.read(tokenStoreProvider).read();
    try {
      if (stored != null) {
        await ref.read(authApiProvider).logout(stored.refreshToken);
      }
    } on ApiProblem catch (error) {
      if (error.isNetwork) return error;
    }
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
    return null;
  }

  Future<ApiProblem?> _open(Future<Session> Function() action) async {
    try {
      final session = await action();
      await ref
          .read(tokenStoreProvider)
          .write(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
          );
      state = AsyncData(session);
      return null;
    } on ApiProblem catch (error) {
      return error;
    }
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, Session?>(
  SessionController.new,
);

/// Keeps a signed-in wallet available when refresh cannot reach the API.
Session? sessionFromStored(StoredTokens stored) {
  final parts = stored.accessToken.split('.');
  if (parts.length < 2) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return null;
    final userId = payload['sub'];
    if (userId is! String || userId.isEmpty) return null;
    final email = payload['email'] as String?;
    return Session(
      accessToken: stored.accessToken,
      refreshToken: stored.refreshToken,
      displayName: 'Member',
      email: email,
      role: payload['role'] as String? ?? 'user',
      userId: userId,
    );
  } catch (_) {
    return null;
  }
}

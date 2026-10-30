import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_problem.dart';
import '../../core/auth_api.dart';
import '../../core/providers.dart';

class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final stored = await ref.read(tokenStoreProvider).read();
    if (stored == null) return null;
    try {
      final session = await ref.read(authApiProvider).refresh(stored.refreshToken);
      await ref.read(tokenStoreProvider).write(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      return session;
    } on ApiProblem catch (error) {
      if (error.isNetwork) rethrow;
      await ref.read(tokenStoreProvider).clear();
      return null;
    }
  }

  Future<ApiProblem?> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _open(
      () => ref.read(authApiProvider).register(
        email: email,
        password: password,
        displayName: displayName,
      ),
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
      await ref.read(tokenStoreProvider).write(
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

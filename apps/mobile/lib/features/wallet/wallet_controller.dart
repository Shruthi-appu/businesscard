import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_problem.dart';
import '../../core/auth_api.dart';
import '../../core/providers.dart';
import '../auth/session_controller.dart';
import 'wallet_cache.dart';

final walletCacheProvider = Provider<WalletCacheStore>((ref) => WalletCacheStore());

sealed class WalletLoad {
  const WalletLoad();
}

class WalletReady extends WalletLoad {
  const WalletReady(this.snapshot, {this.fromCache = false});

  final WalletSnapshot snapshot;
  final bool fromCache;
}

class WalletDenied extends WalletLoad {
  const WalletDenied();
}

class WalletOffline extends WalletLoad {
  const WalletOffline();
}

final walletProvider = FutureProvider.autoDispose<WalletLoad>((ref) async {
  final session = ref.watch(sessionProvider).asData?.value;
  if (session == null) return const WalletDenied();
  try {
    final snapshot = await ref.read(authApiProvider).loadWallet(session.accessToken);
    await ref.read(walletCacheProvider).save(session.userId, snapshot);
    return WalletReady(snapshot);
  } on ApiProblem catch (error) {
    if (error.isDenied || error.isUnauthenticated) return const WalletDenied();
    if (error.isNetwork) {
      final cached = await ref.read(walletCacheProvider).load(session.userId);
      if (cached != null) return WalletReady(cached, fromCache: true);
    }
    return const WalletOffline();
  }
});

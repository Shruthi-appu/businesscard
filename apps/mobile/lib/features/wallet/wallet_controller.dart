import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_problem.dart';
import '../../core/auth_api.dart';
import '../../core/providers.dart';
import '../auth/session_controller.dart';
import 'wallet_cache.dart';

final walletCacheProvider = Provider<WalletCacheStore>((ref) => WalletCacheStore());

class WalletQuery {
  const WalletQuery({this.text = '', this.filter = 'all'});

  final String text;
  final String filter;
}

class WalletQueryController extends Notifier<WalletQuery> {
  @override
  WalletQuery build() => const WalletQuery();

  void setText(String text) => state = WalletQuery(text: text, filter: state.filter);

  void setFilter(String filter) => state = WalletQuery(text: state.text, filter: filter);
}

final walletQueryProvider = NotifierProvider<WalletQueryController, WalletQuery>(
  WalletQueryController.new,
);

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
  final query = ref.watch(walletQueryProvider);
  try {
    final snapshot = await ref
        .read(authApiProvider)
        .loadWallet(session.accessToken, query: query.text, filter: query.filter);
    if (query.text.isEmpty && query.filter == 'all') {
      await ref.read(walletCacheProvider).save(session.userId, snapshot);
    }
    return WalletReady(snapshot);
  } on ApiProblem catch (error) {
    if (error.isDenied || error.isUnauthenticated) return const WalletDenied();
    if (error.isNetwork && query.text.isEmpty && query.filter == 'all') {
      final cached = await ref.read(walletCacheProvider).load(session.userId);
      if (cached != null) return WalletReady(cached, fromCache: true);
    }
    return const WalletOffline();
  }
});

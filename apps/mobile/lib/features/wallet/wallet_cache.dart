import '../../core/auth_api.dart';

/// In-memory read cache of saved card titles.
///
/// Widget tests override this store. A device file would need a plugin that
/// throws MissingPluginException under `flutter test`, so the default stays
/// in memory and a failed read returns null.
class WalletCacheStore {
  WalletCacheStore({Map<String, WalletSnapshot>? memory}) : _memory = {...?memory};

  final Map<String, WalletSnapshot> _memory;

  Future<void> save(String userId, WalletSnapshot snapshot) async {
    if (userId.isEmpty) return;
    _memory[userId] = snapshot;
  }

  Future<WalletSnapshot?> load(String userId) async {
    if (userId.isEmpty) return null;
    return _memory[userId];
  }
}

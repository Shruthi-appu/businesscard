import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screens.dart';
import '../features/auth/session_controller.dart';
import '../features/wallet/card_detail_screen.dart';
import '../features/wallet/design_screen.dart';
import '../features/wallet/new_card_screen.dart';
import '../features/wallet/scan_screen.dart';
import '../features/wallet/wallet_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final atAuth = location == '/login' || location == '/register';
      if (session.isLoading) return null;
      if (session.hasError) return location == '/wallet' ? null : '/wallet';
      final signedIn = session.asData?.value != null;
      if (!signedIn && !atAuth) return '/login';
      if (signedIn && atAuth) return '/wallet';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
        routes: [
          GoRoute(path: 'new', builder: (context, state) => const NewCardScreen()),
          GoRoute(path: 'scan', builder: (context, state) => const ScanScreen()),
          GoRoute(path: 'create', builder: (context, state) => const DesignScreen()),
          GoRoute(
            path: ':id',
            builder: (context, state) => CardDetailScreen(cardId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});

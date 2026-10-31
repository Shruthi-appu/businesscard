import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_controller.dart';
import 'wallet_controller.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session.isLoading) {
      return const _Message(text: 'Loading your wallet…');
    }
    if (session.hasError) {
      return _Message(
        text: "We couldn't reach Softxu. Check your connection and try again.",
        alert: true,
        action: 'Retry',
        onAction: () => ref.invalidate(sessionProvider),
      );
    }
    final wallet = ref.watch(walletProvider);
    return wallet.when(
      loading: () => const _Message(text: 'Loading your wallet…'),
      error: (_, _) => _Message(
        text: "We couldn't reach Softxu. Check your connection and try again.",
        alert: true,
        action: 'Retry',
        onAction: () => ref.invalidate(walletProvider),
      ),
      data: (load) {
        if (load is WalletDenied) {
          return const _Message(
            text: 'You do not have access to this wallet.',
            alert: true,
          );
        }
        if (load is WalletOffline) {
          return _Message(
            text: "We couldn't reach Softxu. Check your connection and try again.",
            alert: true,
            action: 'Retry',
            onAction: () => ref.invalidate(walletProvider),
          );
        }
        final snapshot = (load as WalletReady).snapshot;
        final name = snapshot.displayName;
        return Scaffold(
          appBar: AppBar(title: const Text('Wallet')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signed in as $name'),
                const SizedBox(height: 24),
                Text(
                  snapshot.empty ? 'No cards yet' : snapshot.titles.first,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.empty
                      ? 'Cards you create or receive will show up here.'
                      : snapshot.titles.join(', '),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () async {
                    final problem = await ref.read(sessionProvider.notifier).logout();
                    if (problem != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(problem.title)),
                      );
                      return;
                    }
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.alert = false,
    this.action,
    this.onAction,
  });

  final String text;
  final bool alert;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = alert ? Theme.of(context).colorScheme.error : null;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center, style: TextStyle(color: color)),
              if (action != null) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: onAction, child: Text(action!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/softxu_controls.dart';
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
        final ready = load as WalletReady;
        final snapshot = ready.snapshot;
        final name = snapshot.displayName;
        Future<void> signOut() async {
          final problem = await ref.read(sessionProvider.notifier).logout();
          if (problem != null && context.mounted) {
            if (iphoneApp) {
              await showCupertinoDialog<void>(
                context: context,
                builder: (dialogContext) => CupertinoAlertDialog(
                  title: Text(problem.title),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            } else {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(problem.title)));
            }
            return;
          }
          if (context.mounted) context.go('/login');
        }

        final body = ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Signed in as $name'),
            if (ready.fromCache) ...[
              const SizedBox(height: 12),
              const Text(
                'Saved on this device. These cards may be out of date.',
              ),
            ],
            const SizedBox(height: 24),
            if (snapshot.empty) ...[
              Text(
                'No cards yet',
                style: iphoneApp
                    ? const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)
                    : Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('Cards you create or receive will show up here.'),
            ] else if (iphoneApp)
              ...snapshot.titles.map(
                (title) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(title, style: const TextStyle(fontSize: 22)),
                ),
              )
            else ...[
              Text(
                snapshot.titles.first,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(snapshot.titles.join(', ')),
            ],
            if (!iphoneApp) ...[
              const SizedBox(height: 24),
              OutlinedButton(onPressed: signOut, child: const Text('Sign out')),
            ],
          ],
        );
        return SoftxuPage(
          title: 'Wallet',
          trailing: iphoneApp
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: signOut,
                  child: const Text('Sign out'),
                )
              : null,
          body: body,
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
    final color = alert
        ? (iphoneApp
              ? CupertinoColors.destructiveRed
              : Theme.of(context).colorScheme.error)
        : null;
    return SoftxuPage(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: color),
              ),
              if (action != null) ...[
                const SizedBox(height: 12),
                SoftxuPrimaryButton(onPressed: onAction, label: action!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

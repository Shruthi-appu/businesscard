import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_problem.dart';
import '../../core/providers.dart';
import '../../ui/softxu_controls.dart';
import '../auth/session_controller.dart';
import 'test_cards.dart';
import 'wallet_controller.dart';
import 'wallet_stack.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session.isLoading) {
      return const _Message(text: 'Loading your wallet…');
    }
    if (session.hasError) {
      return const _SampleWallet();
    }
    final wallet = ref.watch(walletProvider);
    return wallet.when(
      loading: () => const _Message(text: 'Loading your wallet…'),
      error: (_, _) => const _SampleWallet(),
      data: (load) {
        if (load is WalletDenied) {
          return const _SampleWallet(
            notice: 'You do not have access to this wallet.',
          );
        }
        if (load is WalletOffline) {
          return const _SampleWallet();
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

        final lines = snapshot.cards.isEmpty
            ? snapshot.titles
            : snapshot.cards.map((card) => card.label).toList();
        CardsStage stage({Widget? menu}) {
          return CardsStage(
            fromCache: ready.fromCache,
            menu: menu,
            onAdd: () => context.push('/wallet/new'),
            onScan: () => context.push('/wallet/scan'),
            onDesign: () => context.push('/wallet/create'),
            passes: [
              ...samplePasses(),
              for (var index = 0; index < lines.length; index++)
                WalletPass(
                  label: lines[index],
                  detail: index < snapshot.cards.length
                      ? snapshot.cards[index].company
                      : null,
                  favourite:
                      index < snapshot.cards.length &&
                      snapshot.cards[index].isFavourite,
                ),
            ],
          );
        }

        return SoftxuPage(
          title: 'Signed in as $name',
          trailing: iphoneApp
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: signOut,
                  child: const Text('Sign out'),
                )
              : TextButton(onPressed: signOut, child: const Text('Sign out')),
          body: ready.fromCache
              ? stage()
              : _AccountSection(builder: (menu) => stage(menu: menu)),
        );
      },
    );
  }
}

class _SampleWallet extends ConsumerWidget {
  const _SampleWallet({this.notice});

  final String? notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return SoftxuPage(
      title: 'Signed in as Member',
      trailing: iphoneApp
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: signOut,
              child: const Text('Sign out'),
            )
          : TextButton(onPressed: signOut, child: const Text('Sign out')),
      body: CardsStage(
        notice: notice,
        onAdd: () => context.push('/wallet/new'),
        onScan: () => context.push('/wallet/scan'),
        onDesign: () => context.push('/wallet/create'),
        passes: samplePasses(),
      ),
    );
  }
}

class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection({required this.builder});

  final Widget Function(Widget menu) builder;

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  var _confirm = false;
  var _pending = false;
  String? _message;
  var _problem = false;

  @override
  Widget build(BuildContext context) {
    final message = _message == null
        ? null
        : Text(
            _message!,
            key: Key(_problem ? 'account-alert' : 'account-status'),
          );
    return widget.builder(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Account',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SoftxuSecondaryButton(
            onPressed: _pending ? null : _export,
            label: _pending ? 'Working…' : 'Export my data',
          ),
          const SizedBox(height: 28),
          _ConfirmDelete(
            value: _confirm,
            onChanged: (value) => setState(() => _confirm = value),
          ),
          const SizedBox(height: 8),
          SoftxuSecondaryButton(
            onPressed: _pending ? null : _delete,
            label: 'Delete account',
          ),
          ?message,
        ],
      ),
    );
  }

  Future<void> _export() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    if (token == null) return;
    setState(() {
      _pending = true;
      _message = null;
    });
    try {
      final api = ref.read(authApiProvider);
      final created = await api.send(
        'POST',
        '/v1/me/export',
        null,
        token: token,
        headers: {
          'idempotency-key': 'export-${DateTime.now().microsecondsSinceEpoch}',
        },
      );
      final file = await api.readText(
        '/v1/me/exports/${created['id']}/file',
        token: token,
      );
      await Clipboard.setData(ClipboardData(text: file));
      if (mounted) {
        setState(() {
          _problem = false;
          _message = 'Your export downloaded.';
        });
      }
    } on ApiProblem catch (error) {
      if (mounted) {
        setState(() {
          _problem = true;
          _message = error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _delete() async {
    if (!_confirm) {
      setState(() {
        _problem = true;
        _message = 'Confirm that you want to delete this account.';
      });
      return;
    }
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    if (token == null) return;
    setState(() {
      _pending = true;
      _message = null;
    });
    try {
      await ref
          .read(authApiProvider)
          .send(
            'POST',
            '/v1/me/delete',
            {'confirm': true},
            token: token,
            headers: {
              'idempotency-key':
                  'delete-${DateTime.now().microsecondsSinceEpoch}',
            },
          );
      await ref.read(sessionProvider.notifier).logout();
      if (mounted) context.go('/login');
    } on ApiProblem catch (error) {
      if (mounted) {
        setState(() {
          _problem = true;
          _message = error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }
}

class _ConfirmDelete extends StatelessWidget {
  const _ConfirmDelete({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: const Text(
            'I understand this schedules deletion and signs me out.',
          ),
        ),
        if (iphoneApp)
          CupertinoSwitch(value: value, onChanged: onChanged)
        else
          Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SoftxuPage(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

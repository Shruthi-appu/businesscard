import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_problem.dart';
import '../../core/providers.dart';
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

        final query = ref.watch(walletQueryProvider);
        final lines = snapshot.cards.isEmpty
            ? snapshot.titles
            : snapshot.cards.map((card) => card.label).toList();
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
            const SizedBox(height: 16),
            SoftxuPrimaryButton(
              onPressed: () => context.push('/wallet/new'),
              label: 'Add a card',
            ),
            const SizedBox(height: 8),
            SoftxuSecondaryButton(
              onPressed: () => context.push('/wallet/scan'),
              label: 'Scan a card',
            ),
            const SizedBox(height: 8),
            SoftxuSecondaryButton(
              onPressed: () => context.push('/wallet/create'),
              label: 'Design a card',
            ),
            const SizedBox(height: 16),
            _WalletSearch(
              text: query.text,
              onChanged: (value) => ref.read(walletQueryProvider.notifier).setText(value),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final choice in const [
                  ('all', 'All cards'),
                  ('favourites', 'Favourites'),
                  ('manual', 'Typed in'),
                ])
                  SoftxuLink(
                    onPressed: () => ref.read(walletQueryProvider.notifier).setFilter(choice.$1),
                    label: query.filter == choice.$1 ? '${choice.$2} · selected' : choice.$2,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (lines.isEmpty) ...[
              Text(
                query.text.isNotEmpty || query.filter != 'all'
                    ? 'No matching cards'
                    : 'No cards yet',
                style: iphoneApp
                    ? const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)
                    : Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                query.text.isNotEmpty || query.filter != 'all'
                    ? 'Try a different search or show all cards.'
                    : 'Cards you create or receive will show up here.',
              ),
            ] else
              for (var index = 0; index < lines.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CardLine(
                    label: lines[index],
                    detail: index < snapshot.cards.length ? snapshot.cards[index].company : null,
                    favourite:
                        index < snapshot.cards.length && snapshot.cards[index].isFavourite,
                    onOpen: index < snapshot.cards.length && snapshot.cards[index].id.isNotEmpty
                        ? () => context.push('/wallet/${snapshot.cards[index].id}')
                        : null,
                  ),
                ),
            if (!ready.fromCache) ...[
              const SizedBox(height: 8),
              const _AccountSection(),
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

class _WalletSearch extends StatefulWidget {
  const _WalletSearch({required this.text, required this.onChanged});

  final String text;
  final ValueChanged<String> onChanged;

  @override
  State<_WalletSearch> createState() => _WalletSearchState();
}

class _WalletSearchState extends State<_WalletSearch> {
  late final TextEditingController _controller = TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(covariant _WalletSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text) {
      _controller.value = TextEditingValue(text: widget.text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SoftxuField(controller: _controller, label: 'Search', onChanged: widget.onChanged);
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({
    required this.label,
    this.detail,
    this.favourite = false,
    this.onOpen,
  });

  final String label;
  final String? detail;
  final bool favourite;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 22)),
        if (detail != null && detail!.isNotEmpty) Text(detail!),
        if (favourite) const Text('Favourite'),
      ],
    );
    if (onOpen == null) return text;
    return InkWell(onTap: onOpen, child: text);
  }
}

class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SoftxuSecondaryButton(
          onPressed: _pending ? null : _export,
          label: _pending ? 'Working…' : 'Export my data',
        ),
        const SizedBox(height: 8),
        _ConfirmDelete(value: _confirm, onChanged: (value) => setState(() => _confirm = value)),
        SoftxuSecondaryButton(
          onPressed: _pending ? null : _delete,
          label: 'Delete account',
        ),
        if (_message != null)
          Text(_message!, key: Key(_problem ? 'account-alert' : 'account-status')),
      ],
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
        headers: {'idempotency-key': 'export-${DateTime.now().microsecondsSinceEpoch}'},
      );
      final file = await api.readText('/v1/me/exports/${created['id']}/file', token: token);
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
      await ref.read(authApiProvider).send(
        'POST',
        '/v1/me/delete',
        {'confirm': true},
        token: token,
        headers: {'idempotency-key': 'delete-${DateTime.now().microsecondsSinceEpoch}'},
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
        Expanded(child: const Text('I understand this schedules deletion and signs me out.')),
        if (iphoneApp)
          CupertinoSwitch(value: value, onChanged: onChanged)
        else
          Switch(value: value, onChanged: onChanged),
      ],
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

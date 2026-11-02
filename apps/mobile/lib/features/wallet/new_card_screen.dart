import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_problem.dart';
import '../../core/providers.dart';
import '../../ui/softxu_controls.dart';
import '../auth/session_controller.dart';
import 'wallet_controller.dart';

class NewCardScreen extends ConsumerStatefulWidget {
  const NewCardScreen({super.key});

  @override
  ConsumerState<NewCardScreen> createState() => _NewCardScreenState();
}

class _NewCardScreenState extends ConsumerState<NewCardScreen> {
  final _title = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  var _pending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _company.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SoftxuPage(
      title: 'Add a card',
      leading: phaseBack(context),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Type the details. Nothing here is scanned.'),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, key: const Key('form-error')),
          SoftxuField(controller: _title, label: 'Card title'),
          const SizedBox(height: 12),
          SoftxuField(controller: _name, label: 'Name'),
          const SizedBox(height: 12),
          SoftxuField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          SoftxuField(controller: _phone, label: 'Phone', keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          SoftxuField(controller: _company, label: 'Company'),
          const SizedBox(height: 16),
          SoftxuPrimaryButton(
            onPressed: _pending ? null : _save,
            label: _pending ? 'Saving…' : 'Save card',
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    if (token == null) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final contacts = [
        if (_name.text.trim().isNotEmpty)
          {'kind': 'name', 'value': _name.text.trim(), 'isPrimary': true},
        if (_email.text.trim().isNotEmpty) {'kind': 'email', 'value': _email.text.trim()},
        if (_phone.text.trim().isNotEmpty) {'kind': 'phone', 'value': _phone.text.trim()},
        if (_company.text.trim().isNotEmpty)
          {'kind': 'company', 'value': _company.text.trim()},
      ];
      final created = await ref.read(authApiProvider).send(
        'POST',
        '/v1/cards',
        {'title': _title.text.trim(), 'contacts': contacts},
        token: token,
        expected: 201,
      );
      ref.invalidate(walletProvider);
      if (mounted) context.go('/wallet/${created['id']}');
    } on ApiProblem catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }
}

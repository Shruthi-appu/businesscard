import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_problem.dart';
import '../../core/providers.dart';
import '../../ui/softxu_controls.dart';
import '../auth/session_controller.dart';
import 'card_fields.dart';
import 'wallet_controller.dart';

class NewCardScreen extends ConsumerStatefulWidget {
  const NewCardScreen({super.key});

  @override
  ConsumerState<NewCardScreen> createState() => _NewCardScreenState();
}

class _NewCardScreenState extends ConsumerState<NewCardScreen> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _address = TextEditingController();
  final _location = TextEditingController();
  final _whatsapp = TextEditingController();
  final _facebook = TextEditingController();
  final _instagram = TextEditingController();
  final _qr = TextEditingController();
  final _website = TextEditingController();
  var _pending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _address.dispose();
    _location.dispose();
    _whatsapp.dispose();
    _facebook.dispose();
    _instagram.dispose();
    _qr.dispose();
    _website.dispose();
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
          const Text('Save the details you want on this card.'),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, key: const Key('form-error')),
          CardIconField(
            field: 'name',
            controller: _name,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 12),
          CardIconField(field: 'category', controller: _category),
          const SizedBox(height: 12),
          CardIconField(
            field: 'address',
            controller: _address,
            keyboardType: TextInputType.streetAddress,
          ),
          const SizedBox(height: 12),
          CardIconField(field: 'location', controller: _location),
          const SizedBox(height: 12),
          CardIconField(
            field: 'whatsapp',
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          CardIconField(
            field: 'facebook',
            controller: _facebook,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          CardIconField(
            field: 'instagram',
            controller: _instagram,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          CardIconField(
            field: 'qr',
            controller: _qr,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          CardIconField(
            field: 'website',
            controller: _website,
            keyboardType: TextInputType.url,
          ),
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
    final draft = buildCardWrite(
      name: _name.text,
      category: _category.text,
      address: _address.text,
      location: _location.text,
      whatsapp: _whatsapp.text,
      facebook: _facebook.text,
      instagram: _instagram.text,
      qr: _qr.text,
      website: _website.text,
      onError: (message) => setState(() => _error = message),
    );
    if (draft == null) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(authApiProvider)
          .send(
            'POST',
            '/v1/cards',
            draft.createBody,
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

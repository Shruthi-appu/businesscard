import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_problem.dart';
import '../../core/providers.dart';
import '../../ui/softxu_controls.dart';
import '../auth/session_controller.dart';
import 'card_fields.dart';
import 'wallet_controller.dart';

const _samplePng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
const _sampleSha256 = 'c414cd0e204de974f73753c7e28d7638e7b3691bb8b1a2bab6b25bb7fed7ce77';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  var _pending = false;
  String? _error;
  String? _scanId;
  int _version = 0;
  String? _status;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _company.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SoftxuPage(
      title: 'Scan a card',
      leading: phaseBack(context),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'This build uses the mock reader, not a live camera. Reading the sample card fills the same fields a photo would.',
          ),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, key: const Key('form-error')),
          SoftxuPrimaryButton(
            onPressed: _pending ? null : _readSample,
            label: _pending && _status != 'needs_review' ? 'Reading…' : 'Read the sample card',
          ),
          if (_status == 'needs_review') ...[
            const SizedBox(height: 24),
            const Text('Check the fields', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            CardIconField(
              field: 'name',
              controller: _name,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 12),
            SoftxuField(controller: _email, label: 'Email'),
            const SizedBox(height: 12),
            SoftxuField(controller: _phone, label: 'Phone'),
            const SizedBox(height: 12),
            SoftxuField(controller: _company, label: 'Company'),
            const SizedBox(height: 16),
            SoftxuPrimaryButton(
              onPressed: _pending ? null : _confirm,
              label: _pending ? 'Saving…' : 'Save card',
            ),
          ],
          if (_status == 'failed')
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Reading failed. Try the sample card again.'),
            ),
        ],
      ),
    );
  }

  Future<void> _readSample() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    if (token == null) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final api = ref.read(authApiProvider);
      final created = await api.send('POST', '/v1/scans', const {}, token: token, expected: 201);
      final id = created['id'] as String;
      Map<String, dynamic> latest = created;
      for (final side in ['front', 'back']) {
        final upload = await api.send(
          'POST',
          '/v1/scans/$id/upload-url',
          {
            'side': side,
            'mimeType': 'image/png',
            'byteSize': base64Decode(_samplePng).length,
            'checksumSha256': _sampleSha256,
          },
          token: token,
        );
        final assetId = upload['assetId'] as String;
        if (upload['method'] == 'POST') {
          await api.send(
            'POST',
            '/v1/scans/$id/objects/$assetId',
            {'bodyBase64': _samplePng},
            token: token,
          );
        }
        latest = await api.send(
          'POST',
          '/v1/scans/$id/complete',
          {'assetId': assetId, 'side': side},
          token: token,
        );
      }
      if (!mounted) return;
      _apply(id, latest);
    } on ApiProblem catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  void _apply(String id, Map<String, dynamic> body) {
    String value(String kind) {
      final draft = body['draft'];
      if (draft is! List) return '';
      for (final row in draft) {
        if (row is Map && row['kind'] == kind && row['value'] is String) {
          return row['value'] as String;
        }
      }
      return '';
    }

    _scanId = id;
    _version = body['draftVersion'] as int? ?? 0;
    _status = body['status'] as String?;
    _name.text = value('name');
    _email.text = value('email');
    _phone.text = value('phone');
    _company.text = value('company');
  }

  Future<void> _confirm() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    final scanId = _scanId;
    if (token == null || scanId == null) return;
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
      final saved = await ref.read(authApiProvider).send(
        'POST',
        '/v1/scans/$scanId/confirm',
        {'version': _version, 'contacts': contacts},
        token: token,
        expected: 201,
      );
      ref.invalidate(walletProvider);
      if (mounted) context.go('/wallet/${saved['cardId']}');
    } on ApiProblem catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }
}

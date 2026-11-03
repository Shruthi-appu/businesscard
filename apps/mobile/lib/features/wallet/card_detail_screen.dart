import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_problem.dart';
import '../../core/providers.dart';
import '../../ui/softxu_controls.dart';
import '../auth/session_controller.dart';
import 'card_fields.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _Field {
  const _Field({required this.id, required this.label});

  final String id;
  final String label;
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  final _title = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  final _category = TextEditingController();
  final _address = TextEditingController();
  final _location = TextEditingController();
  final _whatsapp = TextEditingController();
  final _facebook = TextEditingController();
  final _instagram = TextEditingController();
  final _qr = TextEditingController();
  final _website = TextEditingController();
  final _tag = TextEditingController();
  final _pin = TextEditingController();
  final _recipient = TextEditingController();
  var _loading = true;
  var _denied = false;
  var _offline = false;
  var _pending = false;
  var _readOnly = false;
  var _favourite = false;
  var _duplicate = false;
  var _sendSms = false;
  String? _error;
  String? _shareUrl;
  String? _shareError;
  String? _walletEntryId;
  String? _versionId;
  List<_Field> _fields = const [];
  Set<String> _selected = {};
  List<String> _tags = const [];
  String _expires = '604800';

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _company.dispose();
    _category.dispose();
    _address.dispose();
    _location.dispose();
    _whatsapp.dispose();
    _facebook.dispose();
    _instagram.dispose();
    _qr.dispose();
    _website.dispose();
    _tag.dispose();
    _pin.dispose();
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    if (token == null) return;
    setState(() {
      _loading = true;
      _offline = false;
      _denied = false;
    });
    try {
      final body = await ref
          .read(authApiProvider)
          .send('GET', '/v1/cards/${widget.cardId}', null, token: token);
      if (!mounted) return;
      _apply(body);
    } on ApiProblem catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _denied = error.isDenied || error.status == 404;
        _offline = !_denied;
      });
    }
  }

  void _apply(Map<String, dynamic> body) {
    final details = readCardDetails(body);
    final fields = <_Field>[];
    final selected = <String>{};
    final contacts = body['contacts'];
    if (contacts is List) {
      for (final row in contacts) {
        if (row is! Map || row['id'] is! String) continue;
        final kind = row['kind'] as String? ?? 'field';
        final value = row['value'] as String? ?? '';
        fields.add(_Field(id: row['id'] as String, label: '$kind: $value'));
        if (kind == 'name' || kind == 'email') {
          selected.add(row['id'] as String);
        }
      }
    }
    final addresses = body['addresses'];
    if (addresses is List) {
      for (final row in addresses) {
        if (row is! Map || row['id'] is! String) continue;
        fields.add(
          _Field(
            id: row['id'] as String,
            label: row['formattedAddress'] as String? ?? 'Address',
          ),
        );
      }
    }
    final socials = body['socials'];
    if (socials is List) {
      for (final row in socials) {
        if (row is! Map || row['id'] is! String) continue;
        final platform = row['platform'] as String? ?? 'link';
        final url = row['url'] as String? ?? '';
        fields.add(_Field(id: row['id'] as String, label: '$platform: $url'));
      }
    }
    final tags = <String>[];
    final rawTags = body['tags'];
    if (rawTags is List) {
      for (final row in rawTags) {
        if (row is Map && row['name'] is String) {
          tags.add(row['name'] as String);
        }
      }
    }
    final warnings = body['duplicateWarnings'];
    setState(() {
      _loading = false;
      _title.text = body['title'] as String? ?? '';
      _name.text = details.name;
      _email.text = details.email;
      _phone.text = details.phone;
      _company.text = details.company;
      _category.text = details.category;
      _address.text = details.address;
      _location.text = details.location;
      _whatsapp.text = details.whatsapp;
      _facebook.text = details.facebook;
      _instagram.text = details.instagram;
      _qr.text = details.qr;
      _website.text = details.website;
      _walletEntryId = body['walletEntryId'] as String?;
      _versionId = body['versionId'] as String?;
      _readOnly = body['readOnly'] == true;
      _favourite = body['isFavourite'] == true;
      _duplicate = warnings is List && warnings.isNotEmpty;
      _fields = fields;
      _selected = selected;
      _tags = tags;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SoftxuPage(
        title: 'Card',
        leading: phaseBack(context),
        body: const Center(child: Text('Loading this card…')),
      );
    }
    if (_offline) {
      return SoftxuPage(
        title: 'Card',
        leading: phaseBack(context),
        body: Center(
          child: SoftxuPrimaryButton(onPressed: _load, label: 'Retry'),
        ),
      );
    }
    if (_denied) {
      return SoftxuPage(
        title: 'Card',
        leading: phaseBack(context),
        body: const Center(child: Text('You do not have access to this card.')),
      );
    }
    return SoftxuPage(
      title: _title.text.isEmpty ? 'Card' : _title.text,
      leading: phaseBack(context),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SoftxuSecondaryButton(
            onPressed: _pending ? null : _toggleFavourite,
            label: _favourite ? 'Remove favourite' : 'Favourite',
          ),
          ..._savedFacts(),
          if (_duplicate) ...[
            const SizedBox(height: 12),
            const Text('This email or phone is already in your wallet.'),
          ],
          if (_readOnly) ...[
            const SizedBox(height: 12),
            const Text(
              "This is a saved copy. It does not change the other person's card.",
            ),
          ] else ...[
            const SizedBox(height: 24),
            const Text(
              'Share a link',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only the fields you check are included. Copy the link now. It is not shown again.',
            ),
            if (_shareError != null) Text(_shareError!),
            for (final field in _fields)
              _CheckRow(
                label: field.label,
                value: _selected.contains(field.id),
                onChanged: (checked) => setState(() {
                  if (checked) {
                    _selected.add(field.id);
                  } else {
                    _selected.remove(field.id);
                  }
                }),
              ),
            _ChoiceRow(
              label: 'Link expires',
              value: _expires,
              options: const {
                '86400': '1 day',
                '604800': '7 days',
                '2592000': '30 days',
              },
              onChanged: (value) => setState(() => _expires = value),
            ),
            SoftxuField(controller: _pin, label: 'PIN (optional)'),
            const SizedBox(height: 12),
            SoftxuField(
              controller: _recipient,
              label: 'Phone for a text (optional)',
            ),
            _CheckRow(
              label: 'Send the link by the mock text sender',
              value: _sendSms,
              onChanged: (value) => setState(() => _sendSms = value),
            ),
            SoftxuSecondaryButton(
              onPressed: _pending ? null : _share,
              label: _pending ? 'Creating link…' : 'Create link',
            ),
            if (_shareUrl != null) ...[
              const SizedBox(height: 12),
              SelectableText(_shareUrl!),
              SoftxuLink(onPressed: _copyShare, label: 'Copy link'),
            ],
            const SizedBox(height: 24),
            ExchangePanel(cardId: widget.cardId),
          ],
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_tags.join(', ')),
          ],
          const SizedBox(height: 12),
          SoftxuField(controller: _tag, label: 'Tag'),
          const SizedBox(height: 8),
          SoftxuSecondaryButton(
            onPressed: _pending ? null : _addTag,
            label: 'Add tag',
          ),
          if (!_readOnly) ...[
            const SizedBox(height: 24),
            const Text(
              'Edit card',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            if (_error != null) Text(_error!, key: const Key('form-error')),
            const SizedBox(height: 12),
            SoftxuField(controller: _title, label: 'Card title'),
            const SizedBox(height: 12),
            SoftxuField(controller: _name, label: 'Name'),
            const SizedBox(height: 12),
            SoftxuField(controller: _email, label: 'Email'),
            const SizedBox(height: 12),
            SoftxuField(controller: _phone, label: 'Phone'),
            const SizedBox(height: 12),
            SoftxuField(controller: _company, label: 'Company'),
            const SizedBox(height: 12),
            CardIconField(
              field: 'category',
              controller: _category,
              label: 'Business category',
            ),
            const SizedBox(height: 12),
            CardIconField(
              field: 'address',
              controller: _address,
              label: 'Address',
              keyboardType: TextInputType.streetAddress,
            ),
            const SizedBox(height: 12),
            CardIconField(
              field: 'location',
              controller: _location,
              label: 'Location',
            ),
            const SizedBox(height: 12),
            CardIconField(
              field: 'whatsapp',
              controller: _whatsapp,
              label: 'WhatsApp',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            CardIconField(
              field: 'facebook',
              controller: _facebook,
              label: 'Facebook',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            CardIconField(
              field: 'instagram',
              controller: _instagram,
              label: 'Instagram',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            CardIconField(
              field: 'qr',
              controller: _qr,
              label: 'QR code',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            CardIconField(
              field: 'website',
              controller: _website,
              label: 'Website',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            SoftxuPrimaryButton(
              onPressed: _pending ? null : _save,
              label: _pending ? 'Saving…' : 'Save changes',
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _savedFacts() {
    final rows = <(String, String)>[
      ('name', _name.text.trim()),
      ('category', _category.text.trim()),
      ('address', _address.text.trim()),
      ('location', _location.text.trim()),
      ('whatsapp', _whatsapp.text.trim()),
      ('facebook', _facebook.text.trim()),
      ('instagram', _instagram.text.trim()),
      ('qr', _qr.text.trim()),
      ('website', _website.text.trim()),
    ];
    final filled = rows.where((row) => row.$2.isNotEmpty).toList();
    if (filled.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      for (final row in filled)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardFieldIcon(row.$1),
              const SizedBox(width: 12),
              Expanded(child: Text(row.$2)),
            ],
          ),
        ),
    ];
  }

  Future<void> _toggleFavourite() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    final entry = _walletEntryId;
    if (token == null || entry == null) return;
    setState(() => _pending = true);
    try {
      final body = await ref.read(authApiProvider).send(
        'POST',
        '/v1/wallet/entries/$entry/favourite',
        {'isFavourite': !_favourite},
        token: token,
      );
      if (mounted) setState(() => _favourite = body['isFavourite'] == true);
    } on ApiProblem catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _share() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    final version = _versionId;
    if (token == null || version == null || _selected.isEmpty) {
      setState(() => _shareError = 'Choose at least one field.');
      return;
    }
    setState(() {
      _pending = true;
      _shareError = null;
      _shareUrl = null;
    });
    try {
      final pin = _pin.text.trim();
      final phone = _recipient.text.trim();
      final body = await ref
          .read(authApiProvider)
          .send(
            'POST',
            '/v1/cards/${widget.cardId}/shares',
            {
              'versionId': version,
              'fieldIds': _selected.toList(),
              'expiresInSeconds': int.parse(_expires),
              if (pin.isNotEmpty) 'pin': pin,
              if (phone.isNotEmpty) 'recipientPhone': phone,
              if (_sendSms) 'sendSms': true,
            },
            token: token,
            expected: 201,
          );
      if (mounted) setState(() => _shareUrl = body['url'] as String?);
    } on ApiProblem catch (error) {
      if (mounted) setState(() => _shareError = error.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _copyShare() async {
    final url = _shareUrl;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
  }

  Future<void> _addTag() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    final entry = _walletEntryId;
    final name = _tag.text.trim();
    if (token == null || entry == null || name.isEmpty) return;
    setState(() => _pending = true);
    try {
      final body = await ref
          .read(authApiProvider)
          .send(
            'POST',
            '/v1/wallet/entries/$entry/tags',
            {'name': name},
            token: token,
            expected: 201,
          );
      final added = body['name'] as String? ?? name;
      if (mounted) {
        setState(() {
          if (!_tags.contains(added)) _tags = [..._tags, added];
          _tag.clear();
        });
      }
    } on ApiProblem catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _save() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    if (token == null) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final draft = buildCardWrite(
        name: _name.text,
        title: _title.text,
        email: _email.text,
        phone: _phone.text,
        company: _company.text,
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
      final api = ref.read(authApiProvider);
      await api.send('PATCH', '/v1/cards/${widget.cardId}', {
        'title': draft.title,
      }, token: token);
      final saved = await api.send(
        'POST',
        '/v1/cards/${widget.cardId}/versions',
        {
          'contacts': draft.contacts,
          if (draft.addresses.isNotEmpty) 'addresses': draft.addresses,
          if (draft.socials.isNotEmpty) 'socials': draft.socials,
        },
        token: token,
        expected: 201,
      );
      if (mounted) _apply(saved);
    } on ApiProblem catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }
}

class ExchangePanel extends ConsumerStatefulWidget {
  const ExchangePanel({super.key, required this.cardId});

  final String cardId;

  @override
  ConsumerState<ExchangePanel> createState() => _ExchangePanelState();
}

class _ExchangePanelState extends ConsumerState<ExchangePanel> {
  var _mode = 'one_way';
  var _pending = false;
  String? _error;
  Map<String, dynamic>? _session;
  Timer? _poll;
  Timer? _clock;
  var _remaining = 0;

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final status = session?['status'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exchange in person',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'This QR is a short-lived exchange. It is not the public card QR, and it does not contain the contact details.',
        ),
        if (_error != null) Text(_error!),
        if (session == null) ...[
          _ChoiceRow(
            label: 'Exchange',
            value: _mode,
            options: const {
              'one_way': 'They save my card',
              'mutual': 'We each save a card',
            },
            onChanged: (value) => setState(() => _mode = value),
          ),
          SoftxuSecondaryButton(
            onPressed: _pending ? null : _start,
            label: _pending ? 'Starting…' : 'Show QR',
          ),
        ] else ...[
          if (session['qrPngBase64'] is String)
            Image.memory(
              base64Decode(session['qrPngBase64'] as String),
              height: 180,
            ),
          if (session['url'] is String)
            SelectableText(session['url'] as String),
          if (status == 'open' || status == 'joined')
            Text(
              'Visible for ${_formatRemaining(_remaining)}. Anyone who opens this link can ask to save the card.',
            ),
          if (status == 'accepted' && _mode == 'one_way')
            const Text(
              'They saved your card. Your wallet did not gain a copy.',
            ),
          if (status == 'accepted' && _mode == 'mutual')
            const Text('Exchange saved.'),
          if (status == 'declined')
            const Text('This exchange was stopped. Nothing was saved.'),
          if (status == 'expired')
            const Text(
              'This exchange expired. Nothing was saved. Start again to show a new QR.',
            ),
          if (status == 'open' || status == 'joined')
            SoftxuSecondaryButton(
              onPressed: _pending ? null : _stop,
              label: 'Stop',
            ),
        ],
      ],
    );
  }

  String _formatRemaining(int total) {
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _arm(Map<String, dynamic> session) {
    _poll?.cancel();
    _clock?.cancel();
    final expires = DateTime.tryParse(session['expiresAt'] as String? ?? '');
    void tick() {
      if (!mounted || expires == null) return;
      final left = expires.difference(DateTime.now()).inSeconds;
      setState(() {
        _remaining = left < 0 ? 0 : left;
        if (_remaining == 0) _session = {...?_session, 'status': 'expired'};
      });
    }

    tick();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    final status = session['status'] as String?;
    if (status == 'open' || status == 'joined') {
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    }
  }

  Future<void> _start() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    if (token == null) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final body = await ref
          .read(authApiProvider)
          .send(
            'POST',
            '/v1/exchange-sessions',
            {'cardId': widget.cardId, 'mode': _mode, 'method': 'qr'},
            token: token,
            expected: 201,
            headers: {
              'idempotency-key':
                  'exchange-${widget.cardId}-${DateTime.now().microsecondsSinceEpoch}',
            },
          );
      if (!mounted) return;
      setState(() => _session = body);
      _arm(body);
    } on ApiProblem catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _refresh() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    final current = _session;
    final id = current?['id'];
    if (token == null || current == null || id is! String) return;
    try {
      final next = await ref
          .read(authApiProvider)
          .send('GET', '/v1/exchange-sessions/$id', null, token: token);
      if (!mounted) return;
      final merged = {...current, ...next};
      setState(() => _session = merged);
      final status = merged['status'] as String?;
      if (status == 'joined' && merged['peerConsent'] == 'accepted') {
        await _complete(id);
      }
      if (status != 'open' && status != 'joined') {
        _poll?.cancel();
      }
    } on ApiProblem {
      // Keep the QR on screen if a refresh misses.
    }
  }

  Future<void> _complete(String id) async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    if (token == null) return;
    final body = await ref
        .read(authApiProvider)
        .send(
          'POST',
          '/v1/exchange-sessions/$id/complete',
          null,
          token: token,
          headers: {'idempotency-key': 'exchange-complete-$id'},
        );
    if (!mounted) return;
    setState(() => _session = {...?_session, ...body, 'status': 'accepted'});
    _poll?.cancel();
  }

  Future<void> _stop() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    final id = _session?['id'];
    if (token == null || id is! String) return;
    setState(() => _pending = true);
    try {
      await ref.read(authApiProvider).send(
        'POST',
        '/v1/exchange-sessions/$id/consent',
        {'accept': false},
        token: token,
      );
      if (mounted) {
        setState(() => _session = {...?_session, 'status': 'declined'});
      }
      _poll?.cancel();
    } on ApiProblem catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in options.entries)
                SoftxuLink(
                  onPressed: () => onChanged(entry.key),
                  label: entry.key == value
                      ? '${entry.value} · selected'
                      : entry.value,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        if (iphoneApp)
          CupertinoSwitch(value: value, onChanged: onChanged)
        else
          Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

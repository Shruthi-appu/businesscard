import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_problem.dart';
import '../../core/providers.dart';
import '../../ui/softxu_controls.dart';
import '../auth/session_controller.dart';
import 'card_fields.dart';

class _Template {
  const _Template({required this.key, required this.name, required this.colors, required this.scales});

  final String key;
  final String name;
  final List<String> colors;
  final List<String> scales;
}

class DesignScreen extends ConsumerStatefulWidget {
  const DesignScreen({super.key});

  @override
  ConsumerState<DesignScreen> createState() => _DesignScreenState();
}

class _DesignScreenState extends ConsumerState<DesignScreen> {
  final _title = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _headline = TextEditingController();
  final _subline = TextEditingController();
  final _back = TextEditingController();
  final _slug = TextEditingController();
  var _pending = false;
  var _phonePublic = false;
  String? _error;
  String? _published;
  List<_Template> _templates = const [];
  String _templateKey = 'classic';
  String _color = '#0f6e56';
  String _scale = 'md';

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadTemplates);
  }

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _headline.dispose();
    _subline.dispose();
    _back.dispose();
    _slug.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    if (token == null) return;
    try {
      final body = await ref.read(authApiProvider).send('GET', '/v1/templates', null, token: token);
      final items = body['items'];
      final templates = <_Template>[];
      if (items is List) {
        for (final item in items) {
          if (item is! Map || item['key'] is! String) continue;
          templates.add(
            _Template(
              key: item['key'] as String,
              name: item['name'] as String? ?? item['key'] as String,
              colors: _strings(item['allowedColors']),
              scales: _strings(item['allowedTypeScales']),
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _templates = templates;
        if (templates.isNotEmpty) {
          _templateKey = templates.first.key;
          if (templates.first.colors.isNotEmpty) _color = templates.first.colors.first;
        }
      });
    } on ApiProblem catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  _Template? get _selected {
    for (final template in _templates) {
      if (template.key == _templateKey) return template;
    }
    return _templates.isEmpty ? null : _templates.first;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final colors = selected?.colors ?? const ['#0f6e56'];
    final scales = selected?.scales ?? const ['sm', 'md', 'lg'];
    return SoftxuPage(
      title: 'Design a card',
      leading: phaseBack(context),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Pick a template, then choose what strangers can see.'),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, key: const Key('form-error')),
          if (_published != null)
            Text('Public page: $_published', key: const Key('public-page')),
          if (_templates.isNotEmpty)
            _ChoiceRow(
              label: 'Template',
              value: _templateKey,
              options: {for (final item in _templates) item.key: item.name},
              onChanged: (value) => setState(() {
                _templateKey = value;
                final next = _templates.where((item) => item.key == value).firstOrNull;
                if (next != null && next.colors.isNotEmpty) _color = next.colors.first;
              }),
            ),
          SoftxuField(controller: _title, label: 'Card title'),
          const SizedBox(height: 12),
          CardIconField(
            field: 'name',
            controller: _name,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 12),
          SoftxuField(controller: _email, label: 'Public email'),
          const SizedBox(height: 12),
          SoftxuField(controller: _phone, label: 'Phone'),
          const SizedBox(height: 8),
          _CheckRow(
            label: 'Show the phone on the public card',
            value: _phonePublic,
            onChanged: (value) => setState(() => _phonePublic = value),
          ),
          _ChoiceRow(
            label: 'Colour',
            value: _color,
            options: {for (final color in colors) color: color},
            onChanged: (value) => setState(() => _color = value),
          ),
          _ChoiceRow(
            label: 'Type scale',
            value: _scale,
            options: {for (final scale in scales) scale: scale},
            onChanged: (value) => setState(() => _scale = value),
          ),
          SoftxuField(controller: _headline, label: 'Front line'),
          const SizedBox(height: 12),
          SoftxuField(controller: _subline, label: 'Front detail'),
          const SizedBox(height: 12),
          SoftxuField(controller: _back, label: 'Back note'),
          const SizedBox(height: 12),
          SoftxuField(controller: _slug, label: 'Public link'),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _parseColor(_color),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Color(0xFFF7FFFB)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _headline.text.isEmpty ? (_name.text.isEmpty ? 'Your name' : _name.text) : _headline.text,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                    if (_email.text.isNotEmpty) Text(_email.text),
                    if (_phonePublic && _phone.text.isNotEmpty) Text(_phone.text),
                    if (_back.text.isNotEmpty) Text(_back.text),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SoftxuPrimaryButton(
            onPressed: _pending ? null : _publish,
            label: _pending ? 'Publishing…' : 'Publish',
          ),
        ],
      ),
    );
  }

  Future<void> _publish() async {
    final token = ref.read(sessionProvider).asData?.value?.accessToken;
    if (token == null) return;
    final slug = _slug.text.trim().toLowerCase();
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final api = ref.read(authApiProvider);
      final contacts = [
        if (_name.text.trim().isNotEmpty)
          {'kind': 'name', 'value': _name.text.trim(), 'isPrimary': true, 'isPublic': true},
        if (_email.text.trim().isNotEmpty)
          {'kind': 'email', 'value': _email.text.trim(), 'isPublic': true},
        if (_phone.text.trim().isNotEmpty)
          {'kind': 'phone', 'value': _phone.text.trim(), 'isPublic': _phonePublic},
      ];
      final created = await api.send(
        'POST',
        '/v1/digital-cards',
        {'title': _title.text.trim(), 'templateKey': _templateKey, 'contacts': contacts},
        token: token,
        expected: 201,
      );
      final id = created['id'] as String;
      await api.send(
        'PATCH',
        '/v1/digital-cards/$id/design',
        {
          'color': _color,
          'typeScale': _scale,
          'frontHeadline': _headline.text.trim().isEmpty ? _name.text.trim() : _headline.text.trim(),
          'frontSubline': _subline.text.trim(),
          'backNote': _back.text.trim(),
        },
        token: token,
      );
      await api.send(
        'POST',
        '/v1/digital-cards/$id/publish',
        {'slug': slug, 'visibility': 'public'},
        token: token,
        expected: 201,
      );
      final page = await api.send('GET', '/v1/public/cards/$slug', null);
      final link = page['publicUrl'] as String? ?? '/c/$slug';
      if (mounted) setState(() => _published = link);
    } on ApiProblem catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }
}

Color _parseColor(String value) {
  final hex = value.replaceFirst('#', '');
  if (hex.length != 6) return const Color(0xFF0F6E56);
  return Color(int.parse('FF$hex', radix: 16));
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in options.entries)
                SoftxuLink(
                  onPressed: () => onChanged(entry.key),
                  label: entry.key == value ? '${entry.value} · selected' : entry.value,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (iphoneApp)
            CupertinoSwitch(value: value, onChanged: onChanged)
          else
            Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'card_fields.dart';

/// Opens a card link outside the app. Tests replace this with a callback.
typedef CardLinkLauncher = Future<void> Function(Uri url);

/// Hands [url] to the installed app, or to the browser when that app is absent.
Future<void> launchCardLink(Uri url) {
  return launchUrl(url, mode: LaunchMode.externalApplication);
}

/// Where a card fact should go, when the stored value has a destination.
///
/// Name and business category stay text unless they already hold an http URL.
/// Location and address open the stored map link, or a Google Maps search.
/// WhatsApp opens `https://wa.me` for a number, or the stored link.
/// Facebook, Instagram, the website, and the QR link open their https URLs.
/// Any other fact opens when it already stores an http URL or a phone number.
Uri? linkForFact({
  required String field,
  required String value,
  String? extra,
}) {
  final kind = field.trim().toLowerCase();
  final primary = value.trim();
  final secondary = extra?.trim() ?? '';
  switch (kind) {
    case 'name':
    case 'category':
      return _web(primary) ?? _web(secondary);
    case 'address':
    case 'location':
    case 'map':
    case 'maps':
      return _web(secondary) ??
          _web(primary) ??
          _map(primary) ??
          _map(secondary);
    case 'whatsapp':
      return _whatsApp(primary) ?? _whatsApp(secondary);
    case 'facebook':
      return _profile(primary, 'www.facebook.com') ??
          _profile(secondary, 'www.facebook.com');
    case 'instagram':
      return _profile(primary, 'www.instagram.com') ??
          _profile(secondary, 'www.instagram.com');
    case 'website':
    case 'qr':
    case 'link':
    case 'url':
      return _web(primary) ?? _web(secondary);
    case 'phone':
    case 'tel':
    case 'mobile':
      return _web(primary) ??
          _web(secondary) ??
          _phone(primary) ??
          _phone(secondary);
    case 'email':
      return _web(primary) ??
          _web(secondary) ??
          _mail(primary) ??
          _mail(secondary);
    default:
      return _web(primary) ??
          _web(secondary) ??
          _phone(primary) ??
          _phone(secondary);
  }
}

/// Icon and value for one card fact. The row opens [linkForFact] when it has one.
class CardFactRow extends StatelessWidget {
  const CardFactRow({
    super.key,
    required this.field,
    required this.value,
    this.extra,
    this.iconSize = 22,
    this.gap = 12,
    this.valueStyle,
    this.extraStyle,
    this.launcher,
  });

  final String field;
  final String value;
  final String? extra;
  final double iconSize;
  final double gap;
  final TextStyle? valueStyle;
  final TextStyle? extraStyle;
  final CardLinkLauncher? launcher;

  @override
  Widget build(BuildContext context) {
    final destination = linkForFact(field: field, value: value, extra: extra);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardFieldIcon(field, size: iconSize),
        SizedBox(width: gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: valueStyle),
              if (extra != null && extra!.isNotEmpty)
                Text(
                  extra!,
                  style: extraStyle ?? const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
    if (destination == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: ValueKey('card-link-$field'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final open = launcher ?? launchCardLink;
          unawaited(open(destination));
        },
        child: row,
      ),
    );
  }
}

Uri? _web(String text) {
  if (text.isEmpty) return null;
  final cleaned = httpsUrl(text);
  if (cleaned == null) return null;
  return Uri.tryParse(cleaned);
}

Uri? _map(String text) {
  if (text.isEmpty) return null;
  final url = locationUrl(text);
  if (url == null) return null;
  return Uri.tryParse(url);
}

Uri? _profile(String text, String host) {
  if (text.isEmpty) return null;
  final url = profileUrl(text, host);
  if (url == null) return null;
  return Uri.tryParse(url);
}

Uri? _whatsApp(String text) {
  if (text.isEmpty) return null;
  final web = _web(text);
  if (web != null) return web;
  final loose = text.replaceFirst(RegExp(r'^https?://'), '');
  if (loose.startsWith('wa.me/') || loose.startsWith('api.whatsapp.com/')) {
    return _web('https://$loose');
  }
  final digits = _phoneDigits(text);
  if (digits == null) return null;
  return Uri.parse('https://wa.me/$digits');
}

Uri? _phone(String text) {
  if (text.isEmpty) return null;
  if (text.startsWith('tel:')) return Uri.tryParse(text);
  final digits = _phoneDigits(text);
  if (digits == null) return null;
  final compact = text.replaceAll(RegExp(r'[\s().-]'), '');
  final international = compact.startsWith('+') || compact.startsWith('00');
  return Uri(scheme: 'tel', path: international ? '+$digits' : digits);
}

Uri? _mail(String text) {
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return null;
  return Uri(scheme: 'mailto', path: text);
}

String? _phoneDigits(String text) {
  final compact = text.replaceAll(RegExp(r'[\s().-]'), '');
  if (!RegExp(r'^\+?\d{8,15}$').hasMatch(compact)) return null;
  var digits = compact.replaceAll('+', '');
  if (digits.startsWith('00') && digits.length > 4) {
    digits = digits.substring(2);
  }
  if (digits.length < 8 || digits.length > 15) return null;
  return digits;
}

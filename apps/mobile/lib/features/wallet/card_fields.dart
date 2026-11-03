import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../ui/softxu_controls.dart';

/// Icons for the details a card can store.
const cardNameIcon = CupertinoIcons.person_fill;
const cardCategoryIcon = CupertinoIcons.briefcase_fill;
const cardAddressIcon = CupertinoIcons.location_solid;
const cardLocationIcon = CupertinoIcons.map_fill;
const cardWhatsappIcon = CupertinoIcons.chat_bubble_fill;
const cardQrIcon = CupertinoIcons.qrcode;
const cardWebsiteIcon = CupertinoIcons.globe;

const _whatsappGreen = Color(0xFF25D366);
const _facebookBlue = Color(0xFF1877F2);
const _instagramPink = Color(0xFFE1306C);

class CardFieldIcon extends StatelessWidget {
  const CardFieldIcon(this.field, {super.key, this.size = 22});

  final String field;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Center(child: iconFor(field, size)),
    );
  }
}

Widget iconFor(String field, [double size = 22]) {
  switch (field) {
    case 'name':
      return Icon(cardNameIcon, size: size, semanticLabel: 'Name');
    case 'category':
      return Icon(
        cardCategoryIcon,
        size: size,
        semanticLabel: 'Business category',
      );
    case 'address':
      return Icon(cardAddressIcon, size: size, semanticLabel: 'Address');
    case 'location':
      return Icon(
        cardLocationIcon,
        size: size,
        color: const Color(0xFF1E3A5F),
        semanticLabel: 'Location',
      );
    case 'whatsapp':
      return Icon(
        cardWhatsappIcon,
        size: size,
        color: _whatsappGreen,
        semanticLabel: 'WhatsApp',
      );
    case 'facebook':
      return Icon(
        Icons.facebook,
        size: size,
        color: _facebookBlue,
        semanticLabel: 'Facebook',
      );
    case 'instagram':
      return InstagramMark(size: size);
    case 'qr':
      return Icon(cardQrIcon, size: size, semanticLabel: 'QR code');
    case 'website':
      return Icon(cardWebsiteIcon, size: size, semanticLabel: 'Website');
    default:
      return Icon(CupertinoIcons.circle, size: size);
  }
}

class InstagramMark extends StatelessWidget {
  const InstagramMark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Instagram',
      child: CustomPaint(
        size: Size.square(size),
        painter: const _InstagramPainter(),
      ),
    );
  }
}

class _InstagramPainter extends CustomPainter {
  const _InstagramPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _instagramPink
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08;
    final rect = Rect.fromLTWH(
      stroke.strokeWidth,
      stroke.strokeWidth,
      size.width - stroke.strokeWidth * 2,
      size.height - stroke.strokeWidth * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.28)),
      stroke,
    );
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.22, stroke);
    canvas.drawCircle(
      Offset(size.width * 0.73, size.height * 0.27),
      size.width * 0.055,
      Paint()..color = _instagramPink,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CardIconField extends StatelessWidget {
  const CardIconField({
    super.key,
    required this.field,
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final String field;
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CardFieldIcon(field),
        const SizedBox(width: 10),
        Expanded(
          child: SoftxuField(
            controller: controller,
            label: label,
            keyboardType: keyboardType,
          ),
        ),
      ],
    );
  }
}

class CardWrite {
  const CardWrite({
    required this.title,
    required this.contacts,
    required this.addresses,
    required this.socials,
  });

  final String title;
  final List<Map<String, dynamic>> contacts;
  final List<Map<String, dynamic>> addresses;
  final List<Map<String, dynamic>> socials;

  Map<String, dynamic> get createBody => {
    'title': title,
    'contacts': contacts,
    if (addresses.isNotEmpty) 'addresses': addresses,
    if (socials.isNotEmpty) 'socials': socials,
  };
}

/// Builds the card payload, or a message when a filled field cannot be saved.
CardWrite? buildCardWrite({
  required String name,
  String title = '',
  String email = '',
  String phone = '',
  String company = '',
  String category = '',
  String address = '',
  String location = '',
  String whatsapp = '',
  String facebook = '',
  String instagram = '',
  String qr = '',
  String website = '',
  required void Function(String message) onError,
}) {
  final person = name.trim();
  if (person.isEmpty) {
    onError('Enter a name.');
    return null;
  }
  if (person.length > 300) {
    onError('Name is too long.');
    return null;
  }
  final contacts = <Map<String, dynamic>>[
    {'kind': 'name', 'value': person, 'isPrimary': true},
  ];
  final mail = email.trim();
  if (mail.isNotEmpty) contacts.add({'kind': 'email', 'value': mail});
  final phoneText = phone.trim();
  final whatsAppText = whatsapp.trim();
  if (phoneText.isNotEmpty && phoneText != whatsAppText) {
    contacts.add({'kind': 'phone', 'value': phoneText});
  }
  if (whatsAppText.isNotEmpty) {
    if (whatsAppText.length > 300) {
      onError('WhatsApp number is too long.');
      return null;
    }
    contacts.add({
      'kind': 'phone',
      'value': whatsAppText,
      'label': 'whatsapp',
      'whatsappState': 'yes',
    });
  }
  final business = company.trim();
  if (business.isNotEmpty) contacts.add({'kind': 'company', 'value': business});
  final kind = category.trim();
  if (kind.isNotEmpty) {
    if (kind.length > 300) {
      onError('Business category is too long.');
      return null;
    }
    contacts.add({'kind': 'designation', 'label': 'category', 'value': kind});
  }
  final site = website.trim();
  if (site.isNotEmpty) {
    final url = httpsUrl(site);
    if (url == null || url.length > 300) {
      onError('Enter an http or https website.');
      return null;
    }
    contacts.add({'kind': 'website', 'value': url});
  }

  final addresses = <Map<String, dynamic>>[];
  final street = address.trim();
  if (street.isNotEmpty) {
    if (street.length > 400) {
      onError('Address is too long.');
      return null;
    }
    addresses.add({'formattedAddress': street});
  }

  final socials = <Map<String, dynamic>>[];
  final place = location.trim();
  if (place.isNotEmpty) {
    final url = locationUrl(place);
    if (url == null) {
      onError(
        place.length > 400
            ? 'That location is too long.'
            : 'Enter a place or a map link.',
      );
      return null;
    }
    socials.add({'platform': 'location', 'url': url});
  }
  final facebookUrl = profileUrl(facebook, 'www.facebook.com');
  if (facebook.trim().isNotEmpty) {
    if (facebookUrl == null) {
      onError('Enter a Facebook page or link.');
      return null;
    }
    socials.add({'platform': 'facebook', 'url': facebookUrl});
  }
  final instagramUrl = profileUrl(instagram, 'www.instagram.com');
  if (instagram.trim().isNotEmpty) {
    if (instagramUrl == null) {
      onError('Enter an Instagram name or link.');
      return null;
    }
    socials.add({'platform': 'instagram', 'url': instagramUrl});
  }
  final code = qr.trim();
  if (code.isNotEmpty) {
    final url = httpsUrl(code);
    if (url == null) {
      onError('Enter a link for the QR code.');
      return null;
    }
    socials.add({'platform': 'qr', 'url': url});
  }

  final heading = title.trim().isEmpty ? person : title.trim();
  return CardWrite(
    title: heading.length > 120 ? heading.substring(0, 120) : heading,
    contacts: contacts,
    addresses: addresses,
    socials: socials,
  );
}

class SavedCardDetails {
  const SavedCardDetails({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.company = '',
    this.category = '',
    this.address = '',
    this.location = '',
    this.whatsapp = '',
    this.facebook = '',
    this.instagram = '',
    this.qr = '',
    this.website = '',
  });

  final String name;
  final String email;
  final String phone;
  final String company;
  final String category;
  final String address;
  final String location;
  final String whatsapp;
  final String facebook;
  final String instagram;
  final String qr;
  final String website;
}

SavedCardDetails readCardDetails(Map<String, dynamic> body) {
  String contact(
    String kind, {
    bool whatsapp = false,
    bool plainPhone = false,
    String? label,
  }) {
    final rows = body['contacts'];
    if (rows is! List) return '';
    String? fallback;
    for (final row in rows) {
      if (row is! Map || row['kind'] != kind || row['value'] is! String) {
        continue;
      }
      final value = row['value'] as String;
      final rowLabel = row['label'];
      final isWhatsapp =
          rowLabel == 'whatsapp' || row['whatsappState'] == 'yes';
      if (plainPhone && isWhatsapp) continue;
      if (whatsapp && !isWhatsapp) continue;
      if (label != null && rowLabel == label) return value;
      fallback ??= value;
    }
    return label == null ? (fallback ?? '') : '';
  }

  String social(String platform) {
    final rows = body['socials'];
    if (rows is! List) return '';
    for (final row in rows) {
      if (row is Map && row['platform'] == platform && row['url'] is String) {
        final url = row['url'] as String;
        return platform == 'location' ? friendlyLocation(url) : url;
      }
    }
    return '';
  }

  final addresses = body['addresses'];
  var street = '';
  if (addresses is List) {
    for (final row in addresses) {
      if (row is Map && row['formattedAddress'] is String) {
        street = row['formattedAddress'] as String;
        break;
      }
    }
  }

  return SavedCardDetails(
    name: contact('name'),
    email: contact('email'),
    phone: contact('phone', plainPhone: true),
    company: contact('company'),
    category: contact('designation', label: 'category').isNotEmpty
        ? contact('designation', label: 'category')
        : contact('designation'),
    address: street,
    location: social('location'),
    whatsapp: contact('phone', whatsapp: true),
    facebook: social('facebook'),
    instagram: social('instagram'),
    qr: social('qr'),
    website: contact('website'),
  );
}

/// Place names saved as a map search come back as the name the person typed.
String friendlyLocation(String stored) {
  final uri = Uri.tryParse(stored);
  if (uri == null) return stored;
  final query = uri.queryParameters['query'] ?? uri.queryParameters['q'];
  if (query != null && query.isNotEmpty && uri.host.contains('google.')) {
    return query;
  }
  return stored;
}

String? httpsUrl(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty || !uri.host.contains('.')) return null;
  if (uri.userInfo.isNotEmpty) return null;
  var cleaned = uri.toString();
  final hash = cleaned.indexOf('#');
  if (hash >= 0) {
    cleaned = cleaned.substring(0, hash);
  }
  if (cleaned.length > 500) return null;
  return cleaned;
}

String? profileUrl(String raw, String host) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final handle = text.replaceFirst(RegExp(r'^@+'), '');
  final looksLikeUrl =
      text.contains('://') || text.contains('.') || text.contains('/');
  if (!looksLikeUrl) {
    if (handle.isEmpty || handle.contains(' ')) return null;
    return 'https://$host/$handle';
  }
  return httpsUrl(text);
}

String? locationUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (text.contains('://') || text.startsWith('www.') || text.contains('/')) {
    return httpsUrl(text);
  }
  final url =
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeQueryComponent(text)}';
  if (url.length > 500) return null;
  return url;
}

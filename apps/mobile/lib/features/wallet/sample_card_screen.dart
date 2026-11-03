import 'package:flutter/material.dart';

import '../../ui/softxu_controls.dart';
import 'card_fields.dart';
import 'test_cards.dart';

/// The saved details for one sample card.
class SampleCardScreen extends StatelessWidget {
  const SampleCardScreen({super.key, required this.card});

  final TestCard card;

  @override
  Widget build(BuildContext context) {
    final mapLink = locationUrl(card.location);
    return SoftxuPage(
      title: card.name,
      leading: phaseBack(context),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _fact('name', 'Name', card.name),
          _fact('category', 'Business category', card.category),
          _fact('address', 'Address', card.address),
          _fact('location', 'Location', card.location, extra: mapLink),
          _fact('whatsapp', 'WhatsApp', card.whatsapp),
          _fact('facebook', 'Facebook', card.facebook),
          _fact('instagram', 'Instagram', card.instagram),
          _fact('qr', 'QR code', card.qr),
          _fact('website', 'Website', card.website),
        ],
      ),
    );
  }
}

Widget _fact(String field, String label, String value, {String? extra}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardFieldIcon(field),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF5C5346)),
              ),
              Text(value),
              if (extra != null && extra.isNotEmpty)
                Text(extra, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../../ui/softxu_controls.dart';
import 'card_fields.dart';
import 'card_links.dart';
import 'test_cards.dart';

/// The saved details for one sample card.
class SampleCardScreen extends StatelessWidget {
  const SampleCardScreen({super.key, required this.card, this.openLink});

  final TestCard card;

  /// Opens a fact outside the app. Defaults to [launchCardLink].
  final CardLinkLauncher? openLink;

  @override
  Widget build(BuildContext context) {
    final mapLink = locationUrl(card.location);
    return SoftxuPage(
      title: card.name,
      leading: phaseBack(context),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _fact('name', card.name),
          _fact('category', card.category),
          _fact('address', card.address),
          _fact('location', card.location, extra: mapLink),
          _fact('whatsapp', card.whatsapp),
          _fact('facebook', card.facebook),
          _fact('instagram', card.instagram),
          _fact('qr', card.qr),
          _fact('website', card.website),
        ],
      ),
    );
  }

  Widget _fact(String field, String value, {String? extra}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CardFactRow(
        field: field,
        value: value,
        extra: extra,
        launcher: openLink,
      ),
    );
  }
}

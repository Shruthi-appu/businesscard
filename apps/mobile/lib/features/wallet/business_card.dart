import 'package:flutter/widgets.dart';

/// One business card. The wallet lays these out; this type has no widgets.
class BusinessCardData {
  const BusinessCardData({
    required this.id,
    required this.name,
    required this.designation,
    required this.background,
  });

  final String id;
  final String name;
  final String designation;
  final Color background;
}

/// Lavender, pink, mint, and pale yellow, then the same cycle.
const businessCardBackgrounds = <Color>[
  Color(0xFFE4D8F6),
  Color(0xFFF9D5E2),
  Color(0xFFD5F3E6),
  Color(0xFFFFF6CC),
];

const stackedCardInk = Color(0xFF241C19);

/// Landscape card width divided by height.
const stackedCardAspect = 1.62;

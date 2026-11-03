import 'package:flutter/widgets.dart';

/// One line of detail drawn on an opened card. The field name is for the
/// icon and the link, and it is not shown as a title.
class CardFaceDetail {
  const CardFaceDetail({required this.field, required this.value, this.extra});

  final String field;
  final String value;
  final String? extra;
}

/// One business card. The wallet lays these out; this type has no widgets.
class BusinessCardData {
  const BusinessCardData({
    required this.id,
    required this.name,
    required this.designation,
    required this.background,
    this.details = const [],
  });

  final String id;
  final String name;
  final String designation;
  final Color background;
  final List<CardFaceDetail> details;
}

/// Lavender, pink, mint, and pale yellow, then the same cycle.
const businessCardBackgrounds = <Color>[
  Color(0xFFE4D8F6),
  Color(0xFFF9D5E2),
  Color(0xFFD5F3E6),
  Color(0xFFFFF6CC),
];

const stackedCardInk = Color(0xFF241C19);

/// Wide landscape rectangle: width divided by height.
const stackedCardAspect = 2.05;

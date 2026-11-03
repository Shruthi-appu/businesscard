import 'package:flutter/widgets.dart';

import 'card_fields.dart';
import 'wallet_stack.dart';

/// One sample card, with every detail the add-card form can save.
class TestCard {
  const TestCard({
    required this.name,
    required this.category,
    required this.address,
    required this.location,
    required this.whatsapp,
    required this.facebook,
    required this.instagram,
    required this.qr,
    required this.website,
  });

  final String name;
  final String category;
  final String address;

  /// A place name. The card screen turns this into a Google Maps link.
  final String location;
  final String whatsapp;
  final String facebook;
  final String instagram;
  final String qr;
  final String website;

  WalletPass toPass({VoidCallback? onOpen}) {
    return WalletPass(
      label: name,
      detail: category,
      onOpen: onOpen,
      facts: [
        WalletFact(field: 'name', label: 'Name', value: name),
        WalletFact(
          field: 'category',
          label: 'Business category',
          value: category,
        ),
        WalletFact(field: 'address', label: 'Address', value: address),
        WalletFact(
          field: 'location',
          label: 'Location',
          value: location,
          extra: locationUrl(location),
        ),
        WalletFact(field: 'whatsapp', label: 'WhatsApp', value: whatsapp),
        WalletFact(field: 'facebook', label: 'Facebook', value: facebook),
        WalletFact(field: 'instagram', label: 'Instagram', value: instagram),
        WalletFact(field: 'qr', label: 'QR code', value: qr),
        WalletFact(field: 'website', label: 'Website', value: website),
      ],
    );
  }
}

const testCards = <TestCard>[
  TestCard(
    name: 'Meera Iyer',
    category: 'Studio lead',
    address: '12 Hayes Road, Richmond Town, Bengaluru 560025',
    location: 'Indiranagar, Bengaluru',
    whatsapp: '+91 90000 10001',
    facebook: 'https://www.facebook.com/meera.iyer.studio',
    instagram: 'https://www.instagram.com/meera.iyer.studio',
    qr: 'https://atelier-north.example/card',
    website: 'https://atelier-north.example',
  ),
  TestCard(
    name: 'Rohan Desai',
    category: 'Architect',
    address: '48 Lavelle Road, Bengaluru 560001',
    location: 'Cubbon Park, Bengaluru',
    whatsapp: '+91 90000 10002',
    facebook: 'https://www.facebook.com/rohan.desai.architect',
    instagram: 'https://www.instagram.com/rohan.desai.architect',
    qr: 'https://desai-and-co.example/card',
    website: 'https://desai-and-co.example',
  ),
  TestCard(
    name: 'Ananya Rao',
    category: 'Florist',
    address: '7 Church Street, Bengaluru 560001',
    location: 'Church Street, Bengaluru',
    whatsapp: '+91 90000 10003',
    facebook: 'https://www.facebook.com/bloom.room',
    instagram: 'https://www.instagram.com/bloom.room',
    qr: 'https://bloom-room.example/card',
    website: 'https://bloom-room.example',
  ),
  TestCard(
    name: 'Kabir Shah',
    category: 'Chef',
    address: '22 Walton Road, Mumbai 400001',
    location: 'Colaba, Mumbai',
    whatsapp: '+91 90000 10004',
    facebook: 'https://www.facebook.com/kabir.shah.kitchen',
    instagram: 'https://www.instagram.com/kabir.shah.kitchen',
    qr: 'https://salt-and-rye.example/card',
    website: 'https://salt-and-rye.example',
  ),
  TestCard(
    name: 'Priya Nair',
    category: 'Photographer',
    address: '15 Fort Kochi Beach Road, Kochi 682001',
    location: 'Fort Kochi, Kochi',
    whatsapp: '+91 90000 10005',
    facebook: 'https://www.facebook.com/priya.nair.frames',
    instagram: 'https://www.instagram.com/priya.nair.frames',
    qr: 'https://frame-theory.example/card',
    website: 'https://frame-theory.example',
  ),
  TestCard(
    name: 'Arjun Menon',
    category: 'Lawyer',
    address: '90 Mahatma Gandhi Road, Kochi 682011',
    location: 'MG Road, Kochi',
    whatsapp: '+91 90000 10006',
    facebook: 'https://www.facebook.com/arjun.menon.legal',
    instagram: 'https://www.instagram.com/arjun.menon.legal',
    qr: 'https://menon-legal.example/card',
    website: 'https://menon-legal.example',
  ),
  TestCard(
    name: 'Leela Krishnan',
    category: 'Editor',
    address: '5 College Street, Kolkata 700012',
    location: 'College Street, Kolkata',
    whatsapp: '+91 90000 10007',
    facebook: 'https://www.facebook.com/leela.krishnan.books',
    instagram: 'https://www.instagram.com/leela.krishnan.books',
    qr: 'https://margin-press.example/card',
    website: 'https://margin-press.example',
  ),
  TestCard(
    name: 'Vikram Joshi',
    category: 'Product',
    address: '18 Baner Road, Pune 411045',
    location: 'Baner, Pune',
    whatsapp: '+91 90000 10008',
    facebook: 'https://www.facebook.com/vikram.joshi.product',
    instagram: 'https://www.instagram.com/vikram.joshi.product',
    qr: 'https://northwind-labs.example/card',
    website: 'https://northwind-labs.example',
  ),
  TestCard(
    name: 'Sara Qureshi',
    category: 'Designer',
    address: '33 Banjara Hills, Hyderabad 500034',
    location: 'Banjara Hills, Hyderabad',
    whatsapp: '+91 90000 10009',
    facebook: 'https://www.facebook.com/sara.qureshi.design',
    instagram: 'https://www.instagram.com/sara.qureshi.design',
    qr: 'https://paper-plane.example/card',
    website: 'https://paper-plane.example',
  ),
  TestCard(
    name: 'Nikhil Reddy',
    category: 'Engineer',
    address: '61 Jubilee Hills, Hyderabad 500033',
    location: 'Jubilee Hills, Hyderabad',
    whatsapp: '+91 90000 10010',
    facebook: 'https://www.facebook.com/nikhil.reddy.builds',
    instagram: 'https://www.instagram.com/nikhil.reddy.builds',
    qr: 'https://relay-labs.example/card',
    website: 'https://relay-labs.example',
  ),
  TestCard(
    name: 'Aisha Khan',
    category: 'Baker',
    address: '14 Khan Market, New Delhi 110003',
    location: 'Khan Market, New Delhi',
    whatsapp: '+91 90000 10011',
    facebook: 'https://www.facebook.com/aisha.khan.bakes',
    instagram: 'https://www.instagram.com/aisha.khan.bakes',
    qr: 'https://oven-hour.example/card',
    website: 'https://oven-hour.example',
  ),
  TestCard(
    name: 'Dev Patel',
    category: 'Musician',
    address: '8 Kala Ghoda, Mumbai 400001',
    location: 'Kala Ghoda, Mumbai',
    whatsapp: '+91 90000 10012',
    facebook: 'https://www.facebook.com/dev.patel.music',
    instagram: 'https://www.instagram.com/dev.patel.music',
    qr: 'https://low-room.example/card',
    website: 'https://low-room.example',
  ),
  TestCard(
    name: 'Tara Banerjee',
    category: 'Writer',
    address: '27 Hindustan Park, Kolkata 700029',
    location: 'Hindustan Park, Kolkata',
    whatsapp: '+91 90000 10013',
    facebook: 'https://www.facebook.com/tara.banerjee.pages',
    instagram: 'https://www.instagram.com/tara.banerjee.pages',
    qr: 'https://field-notes.example/card',
    website: 'https://field-notes.example',
  ),
  TestCard(
    name: 'Omar Farooq',
    category: 'Consultant',
    address: '41 Commercial Street, Bengaluru 560001',
    location: 'Commercial Street, Bengaluru',
    whatsapp: '+91 90000 10014',
    facebook: 'https://www.facebook.com/omar.farooq.advisory',
    instagram: 'https://www.instagram.com/omar.farooq.advisory',
    qr: 'https://farooq-advisory.example/card',
    website: 'https://farooq-advisory.example',
  ),
  TestCard(
    name: 'Hana Suzuki',
    category: 'Ceramicist',
    address: '6 Auroville Main Road, Puducherry 605101',
    location: 'Auroville, Puducherry',
    whatsapp: '+91 90000 10015',
    facebook: 'https://www.facebook.com/hana.suzuki.kiln',
    instagram: 'https://www.instagram.com/hana.suzuki.kiln',
    qr: 'https://kiln-street.example/card',
    website: 'https://kiln-street.example',
  ),
  TestCard(
    name: 'Elias Berg',
    category: 'Carpenter',
    address: '19 Jew Town, Kochi 682002',
    location: 'Jew Town, Kochi',
    whatsapp: '+91 90000 10016',
    facebook: 'https://www.facebook.com/elias.berg.workshop',
    instagram: 'https://www.instagram.com/elias.berg.workshop',
    qr: 'https://berg-workshop.example/card',
    website: 'https://berg-workshop.example',
  ),
  TestCard(
    name: 'Noor Ahmed',
    category: 'Teacher',
    address: '52 Fraser Town, Bengaluru 560005',
    location: 'Fraser Town, Bengaluru',
    whatsapp: '+91 90000 10017',
    facebook: 'https://www.facebook.com/noor.ahmed.teaches',
    instagram: 'https://www.instagram.com/noor.ahmed.teaches',
    qr: 'https://harbour-school.example/card',
    website: 'https://harbour-school.example',
  ),
  TestCard(
    name: 'Luis Ortega',
    category: 'Guide',
    address: '11 Mall Road, Manali 175131',
    location: 'Mall Road, Manali',
    whatsapp: '+91 90000 10018',
    facebook: 'https://www.facebook.com/luis.ortega.trails',
    instagram: 'https://www.instagram.com/luis.ortega.trails',
    qr: 'https://ridge-trails.example/card',
    website: 'https://ridge-trails.example',
  ),
  TestCard(
    name: 'Maya Chen',
    category: 'Researcher',
    address: '73 Research Park, Guindy, Chennai 600113',
    location: 'Guindy, Chennai',
    whatsapp: '+91 90000 10019',
    facebook: 'https://www.facebook.com/maya.chen.lab',
    instagram: 'https://www.instagram.com/maya.chen.lab',
    qr: 'https://lantern-lab.example/card',
    website: 'https://lantern-lab.example',
  ),
  TestCard(
    name: 'Jonah Brooks',
    category: 'Printer',
    address: '4 Press House, Fort, Mumbai 400001',
    location: 'Fort, Mumbai',
    whatsapp: '+91 90000 10020',
    facebook: 'https://www.facebook.com/jonah.brooks.type',
    instagram: 'https://www.instagram.com/jonah.brooks.type',
    qr: 'https://brooks-type.example/card',
    website: 'https://brooks-type.example',
  ),
];

/// Fan passes for the sample deck. Opening a card is wired by the wallet screen.
final testWalletPasses = <WalletPass>[
  for (final card in testCards) card.toPass(),
];

List<WalletPass> samplePasses() {
  return [for (final card in testCards) card.toPass()];
}

// HuntInKE — Kenya gazetteer + all option constants.
// Exact port of the website's public/js/ui.js constants (same values, same order).
library;

class Town {
  final String n; // name
  final double lat, lng;
  final bool big; // shown as a chip on the home page hero
  const Town(this.n, this.lat, this.lng, {this.big = false});
}

// Kenya gazetteer — the towns the app browses, targets boosts and searches first.
// big:true = shown as a chip on the home page (same list as the website).
const TOWNS = <Town>[
  Town('Nairobi', -1.2864, 36.8172, big: true),
  Town('Mombasa', -4.0435, 39.6682, big: true),
  Town('Kisumu', -0.0917, 34.7680, big: true),
  Town('Nakuru', -0.3031, 36.0800, big: true),
  Town('Ruiru', -1.2208, 36.9646, big: true),
  Town('Eldoret', 0.5143, 35.2698, big: true),
  Town('Thika', -1.0387, 37.0895, big: true),
  Town('Malindi', -3.2192, 40.1169, big: true),
  Town('Kitale', 1.0150, 35.0067),
  Town('Kakamega', 0.2827, 34.7519, big: true),
  Town('Nyeri', -0.4197, 36.9478, big: true),
  Town('Nanyuki', 0.0166, 37.0723, big: true),
  Town('Meru', -0.0470, 37.6490, big: true),
  Town('Machakos', -1.5177, 37.2634, big: true),
  Town('Kilifi', -3.6350, 39.8499),
  Town('Bungoma', 0.5695, 34.5584),
  Town('Kisii', -0.6773, 34.7796),
  Town('Kericho', -0.3674, 35.2832),
  Town('Embu', -0.5373, 37.4537),
  Town('Chuka', -0.3347, 37.6424),
  Town('Chogoria', -0.3089, 37.6372),
  Town('Karatina', -0.4833, 37.1333),
  Town('Kerugoya', -0.5000, 37.2833),
  Town('Naivasha', -0.7167, 36.4333),
  Town('Gilgil', -0.5167, 36.3333),
  Town('Nyahururu', 0.0333, 36.3667),
  Town('Molo', -0.2472, 35.7319),
  Town('Narok', -1.0868, 35.8703),
  Town('Kajiado', -1.8536, 36.7817),
  Town('Ngong', -1.3561, 36.6564),
  Town('Kikuyu', -1.2459, 36.6667),
  Town('Limuru', -1.1119, 36.6419),
  Town('Juja', -1.1041, 37.0103),
  Town('Athi River', -1.4500, 36.9833),
  Town('Kitengela', -1.4833, 36.9500),
  Town('Ongata Rongai', -1.3900, 36.7167),
  Town('Voi', -3.3969, 38.5598),
  Town('Diani (Ukunda)', -4.2800, 39.5900),
  Town('Lamu', -2.2717, 40.9020),
  Town('Garissa', -0.4528, 39.6456),
  Town('Isiolo', 0.3514, 37.5833),
  Town('Marsabit', 2.3333, 37.9833),
  Town('Lodwar', 3.1197, 35.5973),
  Town('Kapenguria', 1.2333, 35.1167),
  Town('Kabarnet', 0.4919, 35.9306),
  Town('Iten', 0.2833, 35.5167),
  Town('Webuye', 0.6833, 34.7667),
  Town('Bomet', -0.7833, 35.3500),
  Town('Sotik', -0.7833, 35.1333),
  Town('Kapsabet', 0.2033, 35.1039),
  Town('Homa Bay', -0.5273, 34.4571),
  Town('Migori', -1.0642, 34.4732),
  Town('Siaya', 0.0606, 34.2881),
  Town('Wote (Makueni)', -1.7833, 37.6333),
  Town('Mandera', 3.9366, 41.8669),
  Town('Wajir', 1.7481, 40.0574),
  Town('Moyale', 3.5266, 39.0562),
];

const KENYA_CENTER = (lat: -0.0236, lng: 37.9062); // geographic centre of Kenya

const TYPES = [
  'Bedsitter', 'Single Room', 'Studio', '1 Bedroom', '2 Bedroom', '3 Bedroom',
  '4+ Bedroom', 'Bungalow', 'Maisonette'
];
const FURN = ['Furnished', 'Semi-furnished', 'Unfurnished'];
const PERIODS = ['Per Month', 'Per Semester'];
const WATER = ['Included in rent', 'Pay separately', 'Rationed'];
const ELEC = ['Included in rent', 'Own token meter', 'Shared meter', 'Prepaid'];
const WIFI = ['Included in rent', 'Available but paid separately', 'Not available'];
const GARBAGE = ['Included', 'Not included', 'Paid separately'];
const BACKUP = ['None', 'Solar', 'Generator'];
const BATHS = ['1', '2', '3', '4+']; // bathroom COUNT
const TENANTS = ['Anyone', 'Students', 'Family', 'Singles / couples', 'Working professionals'];
const ROADS = ['Tarmac', 'Murram', 'Footpath only'];
const SECURITY = ['Guard', 'Gate lock', 'CCTV'];
const FLOORS = ['Ground', '1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th', '9th', '10th'];
const AVAIL_OPTIONS = ['Available now', 'Within a week', 'Within a month', 'Next month', 'Pick a date…'];
const REPORT_REASONS = [
  'Fake or scam listing', 'Unit is already taken', 'Wrong price or info',
  'Poster is not the landlord', 'Misleading photos', 'Other'
];
const BOOST_AMOUNT_KES = 200;
const BOOST_DAYS = 7;

const QR_STUDENT = [
  'Is it still available?',
  'Can I view it this weekend?',
  'What is the total monthly cost?',
  'Is water included in the rent?',
];
const QR_LANDLORD = [
  'Yes, it is available.',
  'When would you like to come for viewing?',
  'Viewings: Mon–Sat, 8 AM – 6 PM.',
  'Deposit is one month rent.',
];

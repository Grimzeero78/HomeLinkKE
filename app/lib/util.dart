// HuntInKE — shared helpers. Exact port of the website's ui.js helpers
// (kes, timeAgo, distances, WhatsApp links) + image compression to data URLs.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'data.dart';

// 'KES 12,500'
String kes(num? n) => 'KES ${(n ?? 0).round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

// '12.5k' for map price chips
String shortK(num n) {
  final v = n / 1000;
  return '${v >= 10 ? v.round().toString() : v.toStringAsFixed(1).replaceAll('.0', '')}k';
}

String perShort(String? p) =>
    p == null ? 'mo' : p.startsWith('Per Month') ? 'mo' : p.startsWith('Per Semester') ? 'sem' : 'yr';

// "Floors" = how many floors the building has (a compound can be G+20).
String floorLabel(String? f) {
  f = (f ?? '').trim();
  if (f.isEmpty || f == 'Ground' || f == 'Ground floor') return 'Ground only';
  if (RegExp(r'^\d+$').hasMatch(f)) return f == '0' ? 'Ground only' : f;
  return f.replaceAll(RegExp(r' floor$'), '');
}

double distMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLa = (lat2 - lat1) * math.pi / 180, dLo = (lng2 - lng1) * math.pi / 180;
  final s = math.sin(dLa / 2) * math.sin(dLa / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLo / 2) * math.sin(dLo / 2);
  return 2 * r * math.asin(math.sqrt(s));
}

// '350 m', '2.3 km', '14 km'
String fmtDist(num m) {
  if (m < 950) return '${(m / 50).round() * 50} m';
  final km = m / 1000;
  return '${km.toStringAsFixed(km < 9.5 ? 1 : 0).replaceAll('.0', '')} km';
}

Town? nearestTown(double lat, double lng) {
  Town? best;
  var bd = double.infinity;
  for (final t in TOWNS) {
    final d = distMeters(lat, lng, t.lat, t.lng);
    if (d < bd) { bd = d; best = t; }
  }
  return best; // caller decides the distance cut-off (web: 60 km)
}

String timeAgo(int? ts) {
  if (ts == null || ts <= 0) return '';
  final s = math.max(1, (DateTime.now().millisecondsSinceEpoch - ts) / 1000).floor();
  if (s < 60) return 'just now';
  if (s < 3600) return '${(s / 60).floor()}m ago';
  if (s < 86400) return '${(s / 3600).floor()}h ago';
  if (s < 86400 * 7) return '${(s / 86400).floor()}d ago';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

String fmtDate(int? ts) {
  if (ts == null || ts <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String fmtAvail(String? v) {
  if (v == null || v.isEmpty) return 'Now';
  return RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(v) ? v.substring(0, 10) : v;
}

List<String> parseSecurity(String? s) {
  try {
    final v = jsonDecode(s ?? '[]');
    return v is List ? v.map((e) => e.toString()).toList() : <String>[];
  } catch (_) {
    return <String>[];
  }
}

// https://wa.me/254712345678?text=…
String waLink(String? num, [String? text]) {
  var n = (num ?? '').replaceAll(RegExp(r'[\s+-]'), '');
  if (n.startsWith('0')) n = '254${n.substring(1)}';
  var out = 'https://wa.me/$n';
  if (text != null && text.isNotEmpty) out += '?text=${Uri.encodeComponent(text)}';
  return out;
}

// amenity chips for a listing card (same 3-tag rule as the website)
List<String> amenityTags(Map<String, dynamic> l) {
  final t = <String>[];
  if (l['water'] == 'Included in rent') t.add('Water incl.');
  if (l['wifi'] == 'Included in rent') t.add('WiFi');
  if (l['elec'] == 'Included in rent') t.add('Power incl.');
  if (l['ensuite'] == 'Yes' || l['bath'] == 'Ensuite (own)') t.add('Bathroom inside');
  if (l['kitchen'] == 'Yes' || l['kitchen'] == 'Own') t.add('Own kitchen');
  if (l['parking'] == 'Yes') t.add('Parking');
  if (l['backup'] != null && l['backup'] != 'None') t.add('${l['backup']} backup');
  if (parseSecurity(l['security'] as String?).contains('Guard')) t.add('Guard');
  return t.take(3).toList();
}

// ---------- image compression → data URLs (same pipeline as the website) ----------
const IMG_RE = r'^data:image/(png|jpe?g|webp|gif);base64,[A-Za-z0-9+/=]+$';

bool isImg(String? d) =>
    d != null && d.length < 1200000 && RegExp(IMG_RE).hasMatch(d);

Future<String> compressToDataUrl(Uint8List bytes, {int maxKB = 260, int maxDim = 1400, int q = 78}) async {
  var quality = q;
  var dim = maxDim;
  var out = await _one(bytes, dim, quality);
  while (out.lengthInBytes > maxKB * 1000 && quality > 42) {
    quality -= 12;
    out = await _one(bytes, dim, quality);
    if (quality <= 44) dim = (dim * 0.85).round();
  }
  final b64 = base64Encode(out);
  return 'data:image/jpeg;base64,$b64';
}

Future<Uint8List> _one(Uint8List bytes, int dim, int q) async {
  try {
    final r = await FlutterImageCompress.compressWithList(
      bytes, minWidth: dim, minHeight: dim, quality: q, format: CompressFormat.jpeg, keepExif: true,
    );
    return r;
  } catch (_) {
    return bytes; // last resort: original bytes (API size check still applies)
  }
}

// small card thumbnail out of an already-compressed data URL (same as shrinkDataUrl)
Future<String> thumbFrom(Uint8List bytes) async {
  try {
    final r = await FlutterImageCompress.compressWithList(
      bytes, minWidth: 340, minHeight: 340, quality: 60, format: CompressFormat.jpeg,
    );
    return 'data:image/jpeg;base64,${base64Encode(r)}';
  } catch (_) {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }
}

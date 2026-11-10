// HuntInKE — tolerant models. The API returns D1 rows (camelCase listing cols,
// snake_case user cols). Every model keeps its raw map so screens can read any field.
class User {
  final int id;
  final String username, name, role, phone, verifyStatus, verifyNote;
  final bool suspended;
  final int createdAt;
  User({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.phone,
    required this.verifyStatus,
    required this.verifyNote,
    required this.suspended,
    required this.createdAt,
  });

  bool get isLandlord => role == 'LANDLORD';
  bool get isAdmin => role == 'ADMIN';
  bool get verified => verifyStatus == 'APPROVED';

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: (j['id'] as num?)?.toInt() ?? 0,
        username: (j['username'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        role: (j['role'] ?? 'SEEKER').toString(),
        phone: (j['phone'] ?? '').toString(),
        verifyStatus: (j['verify_status'] ?? j['verifyStatus'] ?? 'NONE').toString(),
        verifyNote: (j['verify_note'] ?? j['verifyNote'] ?? '').toString(),
        suspended: j['suspended'] == 1 || j['suspended'] == true,
        createdAt: (j['created_at'] as num? ?? j['createdAt'] as num?)?.toInt() ?? 0,
      );
}

class Photo {
  final int id, idx;
  final String url, thumb;
  Photo({required this.id, required this.idx, required this.url, required this.thumb});
  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
        id: (j['id'] as num?)?.toInt() ?? 0,
        idx: (j['idx'] as num?)?.toInt() ?? 0,
        url: (j['url'] ?? '').toString(),
        thumb: (j['thumb'] ?? '').toString(),
      );
}

class Listing {
  final int id, views, createdAt;
  final String title, ptype, period, town, area, landmark, status, furnishing, floor, road;
  final num rent, deposit, units, unitsVacant;
  final double? lat, lng;
  final String thumb; // card thumbnail (data URL)
  final bool ownerVerified;
  final int? boostedUntil;
  final Map<String, dynamic> raw;

  Listing({
    required this.id,
    required this.title,
    required this.ptype,
    required this.period,
    required this.town,
    required this.area,
    required this.landmark,
    required this.status,
    required this.furnishing,
    required this.floor,
    required this.road,
    required this.rent,
    required this.deposit,
    required this.units,
    required this.unitsVacant,
    required this.lat,
    required this.lng,
    required this.thumb,
    required this.ownerVerified,
    required this.boostedUntil,
    required this.views,
    required this.createdAt,
    required this.raw,
  });

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  bool get available => status != 'TAKEN' && status != 'REMOVED';
  bool get boosted => boostedUntil != null && boostedUntil! > _now();

  // vacancy-first: exactly what the landlord wrote, absolute wording
  int get vacantCount {
    if (raw['unitsVacant'] == null) return status == 'TAKEN' ? 0 : (units <= 0 ? 1 : units.toInt());
    final v = (raw['unitsVacant'] as num).toInt();
    return v < 0 ? 0 : v;
  }

  bool get full => vacantCount <= 0 || status == 'TAKEN';
  int get totalUnits => units <= 0 ? 1 : units.toInt();
  String get vacLabel => full ? 'All occupied' : (vacantCount == 1 ? '1 house vacant' : '$vacantCount houses vacant');
  bool get hasLocation => lat != null && lng != null;

  factory Listing.fromJson(Map<String, dynamic> j) {
    final bu = j['boostedUntil'];
    return Listing(
      id: (j['id'] as num?)?.toInt() ?? 0,
      title: (j['title'] ?? '').toString(),
      ptype: (j['ptype'] ?? '').toString(),
      period: (j['period'] ?? 'Per Month').toString(),
      town: (j['town'] ?? '').toString(),
      area: (j['area'] ?? '').toString(),
      landmark: (j['landmark'] ?? '').toString(),
      status: (j['status'] ?? 'AVAILABLE').toString(),
      furnishing: (j['furnishing'] ?? '').toString(),
      floor: (j['floor'] ?? '').toString(),
      road: (j['road'] ?? '').toString(),
      rent: (j['rent'] as num?) ?? 0,
      deposit: (j['deposit'] as num?) ?? 0,
      units: (j['units'] as num?) ?? 1,
      unitsVacant: (j['unitsVacant'] as num?) ?? 1,
      lat: j['lat'] == null ? null : (j['lat'] as num).toDouble(),
      lng: j['lng'] == null ? null : (j['lng'] as num).toDouble(),
      thumb: (j['thumb'] ?? '').toString(),
      ownerVerified: (j['ownerVerified'] ?? j['ownerVerify'] ?? '') == 'APPROVED',
      boostedUntil: bu is num ? bu.toInt() : (bu == null ? null : int.tryParse(bu.toString())),
      views: (j['views'] as num?)?.toInt() ?? 0,
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      raw: j,
    );
  }
}

class Conv {
  final int id, listingId, unread, lastAt;
  final String otherName, otherPhone, lastMsg, ltitle, lrent, lptype, thumb;
  final bool amLandlord;
  Conv({
    required this.id,
    required this.listingId,
    required this.unread,
    required this.lastAt,
    required this.otherName,
    required this.otherPhone,
    required this.lastMsg,
    required this.ltitle,
    required this.lrent,
    required this.lptype,
    required this.thumb,
    required this.amLandlord,
  });
  factory Conv.fromJson(Map<String, dynamic> j) => Conv(
        id: (j['id'] as num?)?.toInt() ?? 0,
        listingId: (j['listingId'] as num?)?.toInt() ?? 0,
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        lastAt: (j['lastAt'] as num?)?.toInt() ?? 0,
        otherName: (j['otherName'] ?? '').toString(),
        otherPhone: (j['otherPhone'] ?? '').toString(),
        lastMsg: (j['lastMsg'] ?? '').toString(),
        ltitle: (j['ltitle'] ?? '').toString(),
        lrent: (j['lrent'] ?? '0').toString(),
        lptype: (j['lptype'] ?? '').toString(),
        thumb: (j['thumb'] ?? '').toString(),
        amLandlord: j['amLandlord'] == 1 || j['amLandlord'] == true,
      );
}

class Msg {
  final int id, senderId, createdAt;
  final String text;
  final bool deleted, edited, mine, read;

  Msg({
    required this.id,
    required this.senderId,
    required this.createdAt,
    required this.text,
    required this.deleted,
    required this.edited,
    required this.mine,
    required this.read,
  });

  factory Msg.fromJson(Map<String, dynamic> j, int meId) => Msg(
        id: (j['id'] as num?)?.toInt() ?? 0,
        senderId: (j['senderId'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        text: (j['text'] ?? '').toString(),
        deleted: j['deleted'] == 1 || j['deleted'] == true,
        edited: j['edited'] == 1 || j['edited'] == true,
        mine: ((j['senderId'] as num?)?.toInt() ?? 0) == meId,
        read: j['readAt'] != null,
      );
}

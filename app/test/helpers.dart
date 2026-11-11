// Test doubles shared by the widget tests.
// FakeApi overrides every network call so tests run offline and fast.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:huntin_app/api.dart';
import 'package:huntin_app/models.dart';
import 'package:huntin_app/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1x1 transparent PNG (the app's images are data URLs — no network needed)
const tinyPng =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Map<String, dynamic> listingJson(int id,
        {double? lat,
        double? lng,
        String town = 'Nairobi',
        String title = 'Cosy hostel near campus'}) =>
    {
      'id': id,
      'title': title,
      'ptype': 'Bedsitter',
      'period': 'Per Month',
      'town': town,
      'area': 'Kilimani',
      'landmark': 'Near the stage',
      'status': 'AVAILABLE',
      'furnishing': 'Unfurnished',
      'floor': '1st',
      'road': 'Tarmac',
      'rent': 6500,
      'deposit': 6500,
      'units': 4,
      'unitsVacant': 2,
      'lat': lat,
      'lng': lng,
      'thumb': tinyPng,
      'ownerVerified': 'APPROVED',
      'views': 12,
      'createdAt': DateTime.now().millisecondsSinceEpoch - 3600000,
    };

class FakeApi extends Api {
  final Map<int, Map<String, dynamic>> listingsById;
  final List<Map<String, dynamic>> allListings;
  int listingFetches = 0;
  int listingsFetches = 0;

  FakeApi(
      {Map<int, Map<String, dynamic>>? byId, List<Map<String, dynamic>>? all})
      : listingsById = byId ?? {},
        allListings = all ?? [],
        super(null);

  @override
  Future<Map<String, dynamic>> listing(int id) async {
    listingFetches++;
    final l = listingsById[id];
    if (l == null) throw ApiException('Listing not found', 404);
    return {
      'ok': true,
      'listing': l,
      'photos': [
        for (var i = 0; i < 3; i++)
          {'id': i, 'idx': i, 'url': tinyPng, 'thumb': tinyPng}
      ],
      'similar': [],
      'isOwner': false,
    };
  }

  @override
  Future<List<dynamic>> listings(
      {String? q,
      String? town,
      String? area,
      String? ptype,
      String? furnishing,
      num? min,
      num? max,
      String? amenities,
      String? sort,
      String? bt,
      int limit = 60}) async {
    listingsFetches++;
    return List<dynamic>.from(allListings);
  }

  @override
  Future<List<dynamic>> myFavorites() async => [];
  @override
  Future<List<dynamic>> myBoosts() async => [];
  @override
  Future<List<dynamic>> myListings() async => [];
  @override
  Future<List<dynamic>> convs() async => [];
  @override
  Future<Map<String, dynamic>> conv(int id) =>
      Future.value({'ok': true, 'conv': {}, 'messages': []});
  @override
  Future<Map<String, dynamic>> messages(int convId, {int after = 0}) =>
      Future.value({'items': []});
  @override
  Future<int> unread() async => 0;
  @override
  Future<Map<String, dynamic>> settings() async => {'settings': {}};
  @override
  Future<Map<String, dynamic>> me() async => {'user': null};
  @override
  Future<void> view(int id) async {}
}

Future<AppState> readyState(Api api) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final st = AppState();
  await st.boot(); // reads mock prefs, builds its own Api...
  st.api = api; // ...then we swap in the fake (AppState.api is a plain field)
  return st;
}

// Listing models for pure-logic tests
Listing listingFrom(Map<String, dynamic> j) => Listing.fromJson(j);

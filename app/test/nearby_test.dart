// "Houses near you" precision — the 200 m hostel bug. A position saved in a
// PREVIOUS session (or an emulator's factory point) must not silently filter
// the near-you list. Only a FRESH fix counts; stale => town browsing + the
// "Use my location" card comes back.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:huntin_app/screens/home.dart';
import 'package:huntin_app/state.dart';
import 'package:huntin_app/util.dart';
import 'helpers.dart';

Future<AppState> _stWithPos({required int? posTs, double lat = -1.2864, double lng = 36.8172, String town = ''}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (posTs != null) 'hl_lat': lat,
    if (posTs != null) 'hl_lng': lng,
    if (posTs != null) 'hl_pos_ts': posTs,
    'hl_town': town,
  });
  final st = AppState();
  await st.boot();
  // one hostel 200 m north of the saved position, in a DIFFERENT town than
  // the browse-town — the exact scenario the user described
  st.api = FakeApi(all: [listingJson(1, lat: lat + 0.0018, lng: lng, town: 'Chuka')]);
  return st;
}

Widget _host(AppState st) => ChangeNotifierProvider.value(
      value: st,
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  testWidgets('fresh position: the 200 m hostel shows under "Houses near you"',
      (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final st = await _stWithPos(posTs: now, town: 'Nairobi');
    expect(st.posFresh(), isTrue);

    await tester.pumpWidget(_host(st));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('Houses near you'), findsOneWidget);
    expect(find.text('Cosy hostel near campus'), findsOneWidget,
        reason: 'a hostel 200 m away must never read as "no hostel around"');
  });

  testWidgets('stale position (2 h old) + known town: falls back to the town list',
      (tester) async {
    final twoHoursAgo = DateTime.now().millisecondsSinceEpoch - 7200000;
    final st = await _stWithPos(posTs: twoHoursAgo, town: 'Nairobi');
    expect(st.posFresh(), isFalse);

    await tester.pumpWidget(_host(st));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // like the website: without a fresh fix we browse the chosen town instead
    // of showing a wrong "near you" list
    expect(find.text('Houses in Nairobi'), findsOneWidget);
    expect(find.text('Houses near you'), findsNothing);
  });

  testWidgets('stale position + no town: the honest "Use my location" card returns',
      (tester) async {
    final twoHoursAgo = DateTime.now().millisecondsSinceEpoch - 7200000;
    final st = await _stWithPos(posTs: twoHoursAgo, town: '');
    expect(st.posFresh(), isFalse);

    await tester.pumpWidget(_host(st));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('Houses around you'), findsOneWidget);
    expect(find.text('Use my location'), findsOneWidget);
  });

  testWidgets('position without a timestamp (old app version) is treated as stale',
      (tester) async {
    // saved lat/lng but NO hl_pos_ts key
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hl_lat': -1.2864, 'hl_lng': 36.8172, 'hl_town': 'Nairobi',
    });
    final st = AppState();
    await st.boot();
    expect(st.posFresh(), isFalse);
  });

  test('distMeters: 200 m hostel is ~200 m, not kilometres', () {
    // 0.0018 degrees of latitude ~= 200 m
    final d = distMeters(-1.2864, 36.8172, -1.2864 + 0.0018, 36.8172);
    expect(d, greaterThan(180));
    expect(d, lessThan(220));
    // 7 km rule boundary
    final d7 = distMeters(0, 0, 0.063, 0);
    expect(d7, closeTo(7000, 30));
  });

  test('fmtDist rounds like the website', () {
    expect(fmtDist(200), '200 m');
    expect(fmtDist(2300), '2.3 km');
    expect(fmtDist(14000), '14 km');
  });
}

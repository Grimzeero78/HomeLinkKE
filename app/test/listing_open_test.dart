import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:huntin_app/models.dart';
import 'package:huntin_app/screens/listing.dart';
import 'package:huntin_app/state.dart';
import 'helpers.dart';

class _SlowDetailApi extends FakeApi {
  final detailGate = Completer<void>();
  bool detailStarted = false;

  _SlowDetailApi() : super(byId: {1: listingJson(1)});

  @override
  Future<Map<String, dynamic>> listing(int id) async {
    detailStarted = true;
    await detailGate.future;
    return super.listing(id);
  }
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('listing content appears while full details are still loading',
      (tester) async {
    // PHONE SURFACE: on the default 800x600 test surface the 4:3 hero photo
    // fills the whole viewport, so the title sits below the fold (ListView is
    // lazy) — a real phone is tall, so test like one.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _SlowDetailApi();
    final state = await readyState(api);
    final listing = Listing.fromJson(listingJson(1));

    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(home: ListingScreen(1, initialListing: listing)),
    ));
    await tester.pump();

    expect(api.detailStarted, isTrue);
    expect(api.detailGate.isCompleted, isFalse);
    expect(find.text('Cosy hostel near campus'), findsOneWidget);

    api.detailGate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });
}

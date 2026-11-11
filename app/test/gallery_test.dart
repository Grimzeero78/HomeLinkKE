// GALLERY — the exact bug the user reported: "user cant press to see the other
// pictures there is not the side buttons". The arrows AND thumbs must move the
// big photo, the counter must follow, and swiping must work too.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:huntin_app/screens/listing.dart';
import 'package:huntin_app/state.dart';
import 'helpers.dart';

Future<AppState> _st() => readyState(FakeApi(byId: {7: listingJson(7)}));

Widget _host(AppState st) => ChangeNotifierProvider.value(
      value: st,
      child: const MaterialApp(home: ListingScreen(7)),
    );

void main() {
  testWidgets('arrows move the big photo and the counter follows',
      (tester) async {
    final st = await _st();
    await tester.pumpWidget(_host(st));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // 3 photos loaded -> counter shows 1/3 and the arrows exist
    expect(find.text('1/3'), findsOneWidget);
    final arrows = find.byIcon(Icons.arrow_back_ios_new_rounded);
    expect(arrows, findsNWidgets(2)); // left + right

    // RIGHT arrow -> photo 2
    await tester.tap(arrows.at(1));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);

    // RIGHT again -> photo 3
    await tester.tap(arrows.at(1));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);

    // RIGHT wraps back to 1 (website wraps too)
    await tester.tap(arrows.at(1));
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('LEFT arrow wraps backwards', (tester) async {
    final st = await _st();
    await tester.pumpWidget(_host(st));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).at(0));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('tapping a thumbnail jumps to that photo', (tester) async {
    final st = await _st();
    await tester.pumpWidget(_host(st));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // thumbs row: each thumb carries a ValueKey('thumb<i>') — it sits below
    // the fold, so bring it on screen first
    final thumbs = find.byKey(const ValueKey('thumb2'));
    await tester.ensureVisible(thumbs);
    await tester.pumpAndSettle();
    expect(thumbs, findsOneWidget);
    await tester.tap(thumbs);
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('the PageView really lands on the page the arrows chose',
      (tester) async {
    final st = await _st();
    await tester.pumpWidget(_host(st));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).at(1));
    await tester.pumpAndSettle();

    final pv = tester.widget<PageView>(find.byType(PageView));
    expect(pv.controller, isNotNull);
    expect(pv.controller!.page, closeTo(1, 0.01),
        reason: 'the big photo must actually move, not just the counter');
  });

  testWidgets('dragging horizontally flips the photo (swipe still works)',
      (tester) async {
    final st = await _st();
    await tester.pumpWidget(_host(st));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    final galleryCenter = tester.getCenter(find.byType(PageView));
    await tester.dragFrom(galleryCenter, const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 900);
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
  });
}

// BOOT — the app must open on the brand splash (logo + HUNT-IN-KE wordmark)
// and land on the Shell (guest browsing) — never a login wall, never a blank.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huntin_app/main.dart';
import 'helpers.dart';

void main() {
  testWidgets('splash shows logo + name, then the home shell appears',
      (tester) async {
    final st = await readyState(FakeApi());
    await tester.pumpWidget(HuntInApp(state: st));
    await tester.pump(const Duration(milliseconds: 200));

    // brand moment: the wordmark renders as ONE RichText ('HUNT'+'IN'+'KE')
    final word = find.byWidgetPredicate((w) =>
        w is RichText && (w.text as TextSpan).toPlainText() == 'HUNTINKE');
    expect(word, findsOneWidget);

    // ~2.4 s brand hold, then the shell
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Find a house anywhere in Kenya'), findsOneWidget,
        reason: 'guests land straight on Home — no login wall');
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}

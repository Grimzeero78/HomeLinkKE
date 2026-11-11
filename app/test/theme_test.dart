// THEME — the user could not find light/dark: the topbar used a GEAR icon for
// "system" and the cycle was hidden. Now: one tap flips light<->dark (no gear),
// long-press returns to "follow device", and Profile > SETTINGS has an
// Appearance card with three plain choices.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:huntin_app/screens/shell.dart';
import 'package:huntin_app/state.dart';
import 'package:huntin_app/theme.dart';
import 'helpers.dart';

Widget _host(AppState st) => ChangeNotifierProvider<AppState>.value(
      value: st,
      child: Consumer<AppState>(
        builder: (_, __, ___) => MaterialApp(
          theme: huntinTheme(Brightness.light),
          darkTheme: huntinTheme(Brightness.dark),
          themeMode: st.themeMode,
          home: const Shell(),
        ),
      ),
    );

void main() {
  testWidgets('topbar tap flips light -> dark (no gear icon anywhere)',
      (tester) async {
    final st = await readyState(FakeApi());
    st.themeMode = ThemeMode.light;
    await tester.pumpWidget(_host(st));
    await tester.pump(const Duration(milliseconds: 300));

    // light mode shows the moon; tapping it goes dark
    expect(st.themeMode, ThemeMode.light);
    expect(find.byIcon(Icons.settings_outlined), findsNothing,
        reason: 'the gear looked like a settings button — it is gone for good');
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    expect(st.themeMode, ThemeMode.dark);
    expect(find.text('Theme: Dark mode'), findsOneWidget);
  });

  testWidgets('topbar tap flips dark -> light', (tester) async {
    final st = await readyState(FakeApi());
    st.themeMode = ThemeMode.dark;
    await tester.pumpWidget(_host(st));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    expect(st.themeMode, ThemeMode.light);
    expect(find.text('Theme: Light mode'), findsOneWidget);
  });

  testWidgets('Profile > Appearance card switches all three modes',
      (tester) async {
    final st = await readyState(FakeApi());
    st.themeMode = ThemeMode.light;
    await tester.pumpWidget(_host(st));
    await tester.pump(const Duration(milliseconds: 300));

    // go to Profile tab (bottom nav, 5th item)
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsWidgets); // card option (and possibly snack)
    expect(find.text('Follow device'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(st.themeMode, ThemeMode.dark);
    expect(find.text('Theme: Dark'), findsWidgets); // settings row + toast

    await tester.tap(find.text('Follow device'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(st.themeMode, ThemeMode.system);

    await tester.tap(find.text('Light'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(st.themeMode, ThemeMode.light);
  });
}

// Finder.at(i) is Flutter's own API — no helpers needed here.


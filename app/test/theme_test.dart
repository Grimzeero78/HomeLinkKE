// Theme switching is available in the shared top bar, not duplicated in Profile.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:huntin_app/screens/shell.dart';
import 'package:huntin_app/state.dart';
import 'package:huntin_app/theme.dart';
import 'package:huntin_app/widgets.dart';
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

  testWidgets('brand returns to Home and Profile has no duplicate theme controls',
      (tester) async {
    final st = await readyState(FakeApi());
    st.themeMode = ThemeMode.light;
    await tester.pumpWidget(_host(st));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('SETTINGS'), findsNothing);
    expect(find.text('Follow device'), findsNothing);
    expect(find.text('Theme: Light'), findsNothing);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(find.byType(BrandWord));
    await tester.pump(const Duration(milliseconds: 300));
    expect(shellTab.value, 0);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    expect(st.themeMode, ThemeMode.dark);
  });
}

// Finder.at(i) is Flutter's own API — no helpers needed here.

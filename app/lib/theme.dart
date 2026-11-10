// HuntInKE — brand theme, ported 1:1 from the website's public/styles.css
// (:root light vars + html[data-theme=dark] overrides). Pine / ember / cream.
import 'package:flutter/material.dart';

class C {
  // light
  static const pine = Color(0xFF0E5A33);
  static const pineDeep = Color(0xFF0A3D24);
  static const leaf = Color(0xFF1B7A47);
  static const mist = Color(0xFFE5EFE2);
  static const pineInk = Color(0xFF0A3D24);
  static const ember = Color(0xFFE0620F);
  static const emberDeep = Color(0xFFC25208);
  static const emberMist = Color(0xFFFBEADB);
  static const cream = Color(0xFFF6F3EA);
  static const ink = Color(0xFF17251D);
  static const ink2 = Color(0xFF5D685E);
  static const ink3 = Color(0xFF8B9188);
  static const line = Color(0xFFE4DFD0);
  static const card = Color(0xFFFFFFFF);
  static const card2 = Color(0xFFFBFAF5);
  static const soft = Color(0xFFF1F0EA);
  static const soft2 = Color(0xFFE9E6DA);
  static const dangerBg = Color(0xFFFDECEA);
  static const bad = Color(0xFFB3371F);
  static const galBg = Color(0xFFDFE5DF);

  // dark (html[data-theme=dark])
  static const dPine = Color(0xFF1F9D57);
  static const dPineDeep = Color(0xFF0B4326);
  static const dPineAccent = Color(0xFF5FD29A);
  static const dPineInk = Color(0xFF9CE0BB);
  static const dMist = Color(0xFF243022);
  static const dEmberMist = Color(0xFF3C2513);
  static const dCream = Color(0xFF141713);
  static const dInk = Color(0xFFE9E7DC);
  static const dInk2 = Color(0xFFA7B0A3);
  static const dInk3 = Color(0xFF7A8278);
  static const dLine = Color(0xFF2C322B);
  static const dCard = Color(0xFF1D221C);
  static const dCard2 = Color(0xFF232821);
  static const dSoft = Color(0xFF272C25);
  static const dSoft2 = Color(0xFF2D322B);
  static const dDangerBg = Color(0xFF41201A);
  static const dGalBg = Color(0xFF20251F);
}

// Resolved colors for the current brightness — widgets read these so they never
// hard-code light values.
class T {
  final Brightness b;
  const T(this.b);
  bool get dark => b == Brightness.dark;

  Color get pine => dark ? C.dPineAccent : C.pine;
  Color get pineBtn => dark ? C.dPine : C.pine; // solid buttons keep the deep green in dark mode
  Color get pineBtnPressed => dark ? C.dPineDeep : C.pineDeep;
  Color get pineInk => dark ? C.dPineInk : C.pineInk;
  Color get ember => C.ember;
  Color get emberDeep => C.emberDeep;
  Color get emberMist => dark ? C.dEmberMist : C.emberMist;
  Color get bg => dark ? C.dCream : C.cream;
  Color get ink => dark ? C.dInk : C.ink;
  Color get ink2 => dark ? C.dInk2 : C.ink2;
  Color get ink3 => dark ? C.dInk3 : C.ink3;
  Color get line => dark ? C.dLine : C.line;
  Color get card => dark ? C.dCard : C.card;
  Color get card2 => dark ? C.dCard2 : C.card2;
  Color get soft => dark ? C.dSoft : C.soft;
  Color get soft2 => dark ? C.dSoft2 : C.soft2;
  Color get mist => dark ? C.dMist : C.mist;
  Color get dangerBg => dark ? C.dDangerBg : C.dangerBg;
  Color get bad => C.bad;
  Color get galBg => dark ? C.dGalBg : C.galBg;
  Color get heroTop => dark ? const Color(0xFF0D5030) : C.pine;
  Color get heroBottom => dark ? const Color(0xFF093A21) : C.pineDeep;
}

ThemeData huntinTheme(Brightness b) {
  final t = T(b);
  final isDark = b == Brightness.dark;
  final scheme = ColorScheme(
    brightness: b,
    primary: t.pineBtn,
    onPrimary: Colors.white,
    secondary: C.ember,
    onSecondary: Colors.white,
    surface: t.card,
    onSurface: t.ink,
    surfaceContainerHighest: t.soft,
    onSurfaceVariant: t.ink2,
    error: C.bad,
    onError: Colors.white,
    primaryContainer: t.mist,
    onPrimaryContainer: t.pineInk,
    secondaryContainer: t.emberMist,
    onSecondaryContainer: C.emberDeep,
    outline: t.line,
    outlineVariant: t.line,
    surfaceTint: Colors.transparent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg.withValues(alpha: .95),
      surfaceTintColor: Colors.transparent,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: t.pineInk, letterSpacing: -.3),
    ),
    cardTheme: CardThemeData(
      color: t.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.line)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.card,
      isDense: true,
      hintStyle: TextStyle(color: t.ink3, fontSize: 14.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.pine, width: 1.5)),
      labelStyle: TextStyle(color: t.ink2, fontWeight: FontWeight.w600, fontSize: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: t.pineBtn,
        foregroundColor: Colors.white,
        disabledBackgroundColor: t.pineBtn.withValues(alpha: .5),
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.ink,
        side: BorderSide(color: t.line, width: 1.5),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.ember,
        foregroundColor: Colors.white,
        disabledBackgroundColor: C.ember.withValues(alpha: .5),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: t.pine, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? const Color(0xFF0D5030) : t.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: baseChip(scheme, t),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.card,
      indicatorColor: t.mist,
      surfaceTintColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(
          fontSize: 10.5, fontWeight: FontWeight.w700, color: t.ink3)),
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? t.pine : t.ink3)),
    ),
    dividerTheme: DividerThemeData(color: t.line, thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: t.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: t.ink, height: 1.2),
      contentTextStyle: TextStyle(fontSize: 13.5, color: t.ink2, height: 1.5),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.card,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      showDragHandle: true,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.pine : Colors.transparent),
      side: BorderSide(color: t.ink3, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.pine : t.ink3),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : t.ink3),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.pine : t.soft2),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.pine, linearTrackColor: t.soft),
    refreshIndicatorTheme: const RefreshIndicatorThemeData(color: C.ember),
  );
}

ChipThemeData baseChip(ColorScheme scheme, T t) => ChipThemeData(
      backgroundColor: t.card,
      side: BorderSide(color: t.line, width: 1.4),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: t.ink2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      visualDensity: VisualDensity.compact,
    );

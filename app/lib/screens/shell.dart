// HuntInKE — app shell: ONE global topbar on every tab (brand + theme toggle +
// sign in / join — exactly the website's .topbar) + bottom nav styled 1:1 after
// the website's .bottomnav (icon 22 + 10.5px label, pine-accent when active —
// no Material pill) + Home · Search · Map · Chats (unread badge) · Profile,
// plus a floating Post button for landlords.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'chats.dart';
import 'create.dart';
import 'home.dart';
import 'mapview.dart';
import 'profile.dart';
import 'search.dart';
import 'auth.dart';

// lets any screen jump to a tab (e.g. "Open map →" on the home page)
final ValueNotifier<int> shellTab = ValueNotifier<int>(0);

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  bool _mapOpened = false;
  bool _searchOpened = false; // tabs mount on FIRST visit, then stay alive

  @override
  void initState() {
    super.initState();
    shellTab.addListener(_onTabReq);
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTabReq);
    super.dispose();
  }

  void _onTabReq() {
    if (!mounted) return;
    setState(() {
      _tab = shellTab.value;
      if (_tab == 1) _searchOpened = true;
      if (_tab == 2) _mapOpened = true;
    });
    if (shellTab.value == 3) context.read<AppState>().resetUnreadBadge();
  }

  void _go(int i) {
    setState(() {
      _tab = i;
      if (i == 1) _searchOpened = true;
      if (i == 2) _mapOpened = true;
    });
    if (shellTab.value != i) shellTab.value = i;
    if (i == 3) context.read<AppState>().resetUnreadBadge();
  }

  // One tap switches light/dark; long-press follows the device setting.
  Future<void> _toggleTheme() async {
    final st = context.read<AppState>();
    final resolvedDark = switch (st.themeMode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      _ => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    final next = resolvedDark ? ThemeMode.light : ThemeMode.dark;
    await st.setThemeMode(next);
    if (mounted) {
      snack(context,
          next == ThemeMode.dark ? 'Theme: Dark mode' : 'Theme: Light mode');
    }
  }

  Future<void> _themeSystem() async {
    final st = context.read<AppState>();
    await st.setThemeMode(ThemeMode.system);
    if (mounted) snack(context, "Theme: follows this device's setting");
  }

  // ---- the website's .topbar, on every tab ----
  PreferredSizeWidget _topBar(AppState st, bool resolvedDark) {
    final t = T(resolvedDark ? Brightness.dark : Brightness.light);
    // what you SEE decides the icon: moon in light mode, sun in dark mode.
    // No gear — the gear looked like a settings button and did nothing visible.
    final themeIcon =
        resolvedDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined;
    return AppBar(
      titleSpacing: 14,
      title: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _go(0),
        child: Row(children: [
          // web .brand-logo-sm: 25px, radius 7, soft green glow
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                    color: C.pine.withValues(alpha: .45),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                    spreadRadius: -2)
              ],
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset('assets/icon/icon-192.png',
                    width: 25,
                    height: 25,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          ),
          const SizedBox(width: 7),
          const BrandWord(size: 16.5),
        ]),
      ),
      actions: [
        // web .theme-btn: 36x36, radius 11, 1.5px border — on EVERY page
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: _toggleTheme,
            onLongPress: _themeSystem,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: t.line, width: 1.5),
              ),
              child: Icon(themeIcon, size: 18, color: t.ink),
            ),
          ),
        ),
        if (st.user == null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 11)),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AuthScreen())),
              child: const Text('Sign in', style: TextStyle(fontSize: 12.5)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 11)),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AuthScreen())),
              child: const Text('Join', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 11)),
              onPressed: () => _go(4),
              child: Text(
                  (st.user!.name.isNotEmpty ? st.user!.name : st.user!.username)
                      .split(' ')
                      .first,
                  style: const TextStyle(fontSize: 12.5)),
            ),
          ),
      ],
    );
  }

  // ---- the website's .bottomnav, 1:1 ----
  Widget _bottomNav(AppState st, T t) {
    final items = <(int, IconData, IconData, String)>[
      (0, Icons.home_outlined, Icons.home, 'Home'),
      (1, Icons.search_outlined, Icons.search, 'Search'),
      (2, Icons.location_on_outlined, Icons.location_on, 'Map'),
      (
        3,
        Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded,
        'Chats'
      ),
      (4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];
    return Container(
      decoration: BoxDecoration(
          color: t.card, border: Border(top: BorderSide(color: t.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(children: [
            for (final (i, off, on, label) in items)
              Expanded(
                  child: InkWell(
                onTap: () => _go(i),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(clipBehavior: Clip.none, children: [
                        Icon(_tab == i ? on : off,
                            size: 22, color: _tab == i ? t.pine : t.ink3),
                        if (i == 3 && st.unread > 0)
                          Positioned(
                            top: -3,
                            right: -7,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 17),
                              height: 17,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: C.ember,
                                  borderRadius: BorderRadius.circular(99)),
                              child: Text('${st.unread > 9 ? '9+' : st.unread}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      Text(label,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _tab == i ? t.pine : t.ink3)),
                    ]),
              )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final resolvedDark = switch (st.themeMode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      _ => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    final pages = [
      const HomeScreen(),
      // lazy like the map: mounting search eagerly made it fetch 100 listings
      // at every boot before the user ever opened the tab (wasted data).
      _searchOpened ? const SearchScreen() : const SizedBox.shrink(),
      _mapOpened ? const MapScreen() : const SizedBox.shrink(),
      const ChatsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: T(resolvedDark ? Brightness.dark : Brightness.light).bg,
      appBar: _topBar(st, resolvedDark),
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: st.user?.isLandlord == true
          ? FloatingActionButton.extended(
              backgroundColor: C.ember,
              foregroundColor: Colors.white,
              heroTag: 'post',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateScreen())),
              icon: const Icon(Icons.add_home_work_outlined, size: 20),
              label: const Text('Post listing',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      bottomNavigationBar:
          _bottomNav(st, T(resolvedDark ? Brightness.dark : Brightness.light)),
    );
  }
}

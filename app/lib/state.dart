// HuntInKE — app state: session (same token the browser saves), settings,
// the renter's town + position, theme choice, unread badge polling.
// The website keeps hl_token / hl_town / hl_theme in localStorage;
// the app keeps the same keys in SharedPreferences.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';
import 'notifs.dart';

class AppState extends ChangeNotifier {
  late Api api;
  String? token;
  User? user;
  int unread = 0;
  bool ready = false;

  // boost payment details from the server (same values the boost page shows on the web)
  String paybillNumber = '0143374333';
  String paybillName = 'Isaac Bridget';

  // the town the renter is browsing + their GPS position (persisted, like the web)
  String myTown = '';
  double? myLat, myLng;

  ThemeMode themeMode = ThemeMode.system;

  Timer? _unreadTimer;
  SharedPreferences? _prefs;
  int _lastNotifiedUnread = 0;

  SharedPreferences get prefs => _prefs!;

  Future<void> boot() async {
    // LOCAL loads first, then the UI shows immediately — network waits never
    // block the splash (a slow emulator sat up to 40s frozen before this fix).
    try {
      _prefs = await SharedPreferences.getInstance();
      token = _prefs!.getString('hl_token');
      myTown = _prefs!.getString('hl_town') ?? '';
      myLat = _prefs!.getDouble('hl_lat');
      myLng = _prefs!.getDouble('hl_lng');
      switch (_prefs!.getString('hl_theme')) {
        case 'light': themeMode = ThemeMode.light;
        case 'dark': themeMode = ThemeMode.dark;
        default: themeMode = ThemeMode.system;
      }
    } catch (_) {
      // prefs unavailable (rare, e.g. broken emulator) — start with defaults
    }
    api = Api(token);
    ready = true;
    notifyListeners();
    // Everything below is network — runs in the background, UI is already up.
    _loadSettings();
    if (token != null && token!.isNotEmpty) {
      try {
        final r = await api.me();
        user = User.fromJson((r['user'] ?? {}) as Map<String, dynamic>);
        _startUnreadPolling();
      } on ApiException catch (e) {
        if (e.status == 401) {
          token = null;
          try { await _prefs!.remove('hl_token'); } catch (_) {}
        }
      } catch (_) {
        // offline — keep the token and retry next boot
      }
      notifyListeners(); // session restored (or cleared) — refresh the UI
    }
  }

  Future<void> _loadSettings() async {
    try {
      final r = await api.settings();
      final s = (r['settings'] ?? {}) as Map<String, dynamic>;
      if (s['paybill_number'] != null) paybillNumber = s['paybill_number'].toString();
      if (s['paybill_name'] != null) paybillName = s['paybill_name'].toString();
    } catch (_) {}
  }

  Future<void> refreshUser() async {
    if (token == null) return;
    try {
      final r = await api.me();
      user = User.fromJson((r['user'] ?? {}) as Map<String, dynamic>);
      notifyListeners();
    } on ApiException catch (e) {
      if (e.status == 401) await signOut(silent: true);
    } catch (_) {}
  }

  Future<void> signIn(String tok, User u) async {
    token = tok;
    user = u;
    api.token = tok;
    unread = 0;
    _lastNotifiedUnread = 0;
    await _prefs!.setString('hl_token', tok);
    _startUnreadPolling();
    notifyListeners();
  }

  Future<void> signOut({bool silent = false}) async {
    if (!silent) {
      try { await api.logout(); } catch (_) {}
    }
    _unreadTimer?.cancel();
    token = null;
    user = null;
    unread = 0;
    await _prefs!.remove('hl_token');
    notifyListeners();
  }

  Future<void> updateUser(User u) async {
    user = u;
    notifyListeners();
  }

  // ---------- renter town + position ----------
  Future<void> setMyTown(String t) async {
    myTown = t;
    if (t.isEmpty) {
      await _prefs!.remove('hl_town');
    } else {
      await _prefs!.setString('hl_town', t);
    }
    notifyListeners();
  }

  Future<void> setMyPos(double lat, double lng) async {
    myLat = lat;
    myLng = lng;
    await _prefs!.setDouble('hl_lat', lat);
    await _prefs!.setDouble('hl_lng', lng);
    notifyListeners();
  }

  // ---------- theme ----------
  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _prefs!.setString('hl_theme', switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
    notifyListeners();
  }

  // ---------- unread badge + notifications ----------
  void _startUnreadPolling() {
    _unreadTimer?.cancel();
    _unreadTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (token == null) return;
      try {
        final n = await api.unread();
        if (n != unread) {
          unread = n;
          notifyListeners();
          if (n > _lastNotifiedUnread && n > 0) {
            await Notifs.showMessage(
              'New message on HuntInKE',
              'You have $n unread message${n == 1 ? '' : 's'} — open the Chats tab to reply.',
            );
          }
          _lastNotifiedUnread = n;
        }
      } catch (_) {}
    });
  }

  void resetUnreadBadge() {
    if (unread != 0) {
      unread = 0;
      _lastNotifiedUnread = 0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }
}

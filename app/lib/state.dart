// HuntInKE — app state: session (same token the browser saves), settings,
// the renter's town + position, theme choice, unread badge polling.
// The website keeps hl_token / hl_town / hl_theme in localStorage;
// the app keeps the same keys in SharedPreferences.
import 'dart:async';
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
  // myPosTs = when the fix was taken. A position saved LAST SESSION (or an
  // emulator's factory default) silently poisoned "Houses near you" — the 200 m
  // hostel bug. Now stale positions stop counting after 30 minutes.
  String myTown = '';
  double? myLat, myLng;
  int? myPosTs;

  ThemeMode themeMode = ThemeMode.system;

  Timer? _unreadTimer;
  SharedPreferences? _prefs;
  int _lastNotifiedUnread = 0;

  SharedPreferences get prefs => _prefs!;

  Future<void> boot() async {
    // IDEMPOTENT: the root widget and the boot sequence may both call this —
    // the second call must be a no-op, otherwise it rebuilds st.api and any
    // injected/fake client (and an in-flight first boot) gets clobbered.
    if (ready) return;
    // LOCAL loads first, then the UI shows immediately — network waits never
    // block the splash (a slow emulator sat up to 40s frozen before this fix).
    try {
      _prefs = await SharedPreferences.getInstance();
      token = _prefs!.getString('hl_token');
      myTown = _prefs!.getString('hl_town') ?? '';
      myLat = _prefs!.getDouble('hl_lat');
      myLng = _prefs!.getDouble('hl_lng');
      myPosTs = _prefs!.getInt('hl_pos_ts');
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
    myPosTs = DateTime.now().millisecondsSinceEpoch;
    await _prefs!.setDouble('hl_lat', lat);
    await _prefs!.setDouble('hl_lng', lng);
    await _prefs!.setInt('hl_pos_ts', myPosTs!);
    notifyListeners();
  }

  /// true when the saved position exists AND is recent enough to trust for
  /// "Houses near you". A fix older than [maxAge] (default 30 min) is stale —
  /// the app then falls back to town browsing until the user re-locates.
  bool posFresh({Duration maxAge = const Duration(minutes: 30)}) {
    if (myLat == null || myLng == null) return false;
    final ts = myPosTs;
    if (ts == null) return false; // pre-timestamp position: unknown age, don't trust
    return DateTime.now().millisecondsSinceEpoch - ts <= maxAge.inMilliseconds;
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

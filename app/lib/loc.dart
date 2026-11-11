// HuntInKE — one shared "use my location" flow for Home and Map.
// Handles the full journey the same way on every device:
//   1. asks the permission (and opens App Settings if it was permanently blocked)
//   2. if GPS service is OFF: opens the settings switch and AUTO-CONTINUES the
//      moment the user turns it on — no need to press the button again
//   3. shows a progress dialog the whole time (no silent waits, no double-taps)
//   4. fix chain: last known → fresh medium (18s) → fresh low (12s, network —
//      this is the one that usually locks on emulators) → clear error message
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'theme.dart';
import 'widgets.dart';

Future<Position?> huntinGetLocation(BuildContext context) async {
  // Use one permission API for both the permission prompt and position lookup.
  LocationPermission permission;
  try {
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  } catch (e) {
    if (context.mounted) {
      snack(context, 'Could not request location permission: $e', error: true);
    }
    return null;
  }
  if (permission == LocationPermission.deniedForever) {
    if (context.mounted) {
      snack(context,
          'Location is blocked — allow it in Settings, then press again',
          error: true);
      try {
        final opened = await Geolocator.openAppSettings();
        if (!opened && context.mounted) {
          snack(context, 'Could not open app settings', error: true);
        }
      } catch (e) {
        if (context.mounted) {
          snack(context, 'Could not open app settings: $e', error: true);
        }
      }
    }
    return null;
  }
  if (permission != LocationPermission.whileInUse &&
      permission != LocationPermission.always) {
    if (context.mounted) {
      snack(context, 'Location permission denied — pick your town instead',
          error: true);
    }
    return null;
  }

  // 2) GPS service off → open the switch, keep watching, continue automatically
  bool serviceEnabled;
  try {
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
  } catch (e) {
    if (context.mounted) {
      snack(context, 'Could not check location services: $e', error: true);
    }
    return null;
  }
  if (!serviceEnabled) {
    if (context.mounted) {
      snack(context, 'Turn location ON — the app continues by itself');
    }
    try {
      final opened = await Geolocator.openLocationSettings();
      if (!opened) {
        if (context.mounted) {
          snack(context, 'Could not open location settings', error: true);
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        snack(context, 'Could not open location settings: $e', error: true);
      }
      return null;
    }
    final started = DateTime.now();
    while (DateTime.now().difference(started) < const Duration(seconds: 45)) {
      await Future.delayed(const Duration(milliseconds: 1200));
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          serviceEnabled = true;
          break;
        }
      } catch (e) {
        if (context.mounted) {
          snack(context, 'Could not check location services: $e', error: true);
        }
        return null;
      }
    }
    if (!serviceEnabled) {
      if (context.mounted) {
        snack(context, 'Location is still off — pick your town instead',
            error: true);
      }
      return null;
    }
  }

  // 3) progress dialog while we hunt for a fix — the user always sees state
  final nav = Navigator.of(context, rootNavigator: true);
  final dialogRoute = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6)),
          const SizedBox(width: 16),
          Expanded(
              child: Text('Getting your location…',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: T(Theme.of(ctx).brightness).ink))),
        ]),
      ),
    ),
  );
  unawaited(nav.push(dialogRoute));

  Position? fix;
  try {
    // A cached fix can be HOURS old (or an emulator's default position from
    // when the AVD was created) — trusting it blindly is what put people in
    // the wrong town and said "no houses near you" for a hostel 200 m away.
    // So: use the cache only if it is fresh; otherwise hunt a fresh fix and
    // keep the stale cache only as the very last resort.
    Position? last;
    try {
      last = await Geolocator.getLastKnownPosition();
    } catch (_) {}
    if (_freshEnough(last, const Duration(minutes: 10))) fix = last;
    fix ??= await _fresh(LocationAccuracy.medium, const Duration(seconds: 18));
    fix ??= await _fresh(
        LocationAccuracy.low,
        const Duration(
            seconds: 12)); // network — the one that usually locks on emulators
    fix ??= await _fresh(LocationAccuracy.high, const Duration(seconds: 20));
    fix ??= last; // stale but better than nothing
  } finally {
    if (dialogRoute.isActive) nav.removeRoute(dialogRoute);
  }

  if (fix != null) return fix;
  if (context.mounted) {
    snack(context,
        'No GPS fix yet — press again. On a phone: go outside and retry. On an emulator: Extended Controls (⋮) → Location → set a point → Set Location.',
        error: true);
  }
  return null;
}

Future<Position?> _fresh(LocationAccuracy acc, Duration limit) async {
  try {
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: acc, timeLimit: limit);
  } catch (_) {
    return null; // timeout / provider error — try the next chain step
  }
}

bool _freshEnough(Position? p, Duration maxAge) {
  if (p == null) return false;
  try {
    return DateTime.now().difference(p.timestamp) <= maxAge;
  } catch (_) {
    return false;
  }
}

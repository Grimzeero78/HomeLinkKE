// HuntInKE — one shared "use my location" flow for Home and Map.
// Handles the full journey the same way on every device:
//   1. asks the permission (and opens App Settings if it was permanently blocked)
//   2. if GPS service is OFF: opens settings and asks the user to retry after
//      turning it on (never leaves the app polling settings for 45 seconds)
//   3. returns a fresh fix quickly or shows a clear retry message
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'theme.dart';
import 'widgets.dart';

Future<Position?> huntinGetLocation(BuildContext context) async {
  // Use one permission API for both the permission prompt and position lookup.
  LocationPermission permission;
  try {
    permission =
        await Geolocator.checkPermission().timeout(const Duration(seconds: 5));
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission()
          .timeout(const Duration(seconds: 30));
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
        final opened = await Geolocator.openAppSettings()
            .timeout(const Duration(seconds: 5));
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

  // 2) GPS off → open settings and ask the user to retry after enabling it.
  bool serviceEnabled;
  try {
    serviceEnabled = await Geolocator.isLocationServiceEnabled()
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    if (context.mounted) {
      snack(context, 'Could not check location services: $e', error: true);
    }
    return null;
  }
  if (!serviceEnabled) {
    try {
      final opened = await Geolocator.openLocationSettings()
          .timeout(const Duration(seconds: 5));
      if (!opened) {
        if (context.mounted) {
          snack(context,
              'Location is off — turn it on in Settings, then try again',
              error: true);
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        snack(context, 'Could not open location settings: $e', error: true);
      }
      return null;
    }
    if (context.mounted) {
      snack(context,
          'Turn on Location in Settings, then tap “Use my location” again');
    }
    return null;
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
    // A cached fix is useful only when recent; stale emulator/device positions
    // must not silently send renters to the wrong town.
    Position? last;
    try {
      last = await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
    if (_freshEnough(last, const Duration(minutes: 2))) {
      fix = last;
    } else {
      fix = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(const Duration(seconds: 12));
    }
  } on TimeoutException {
    if (context.mounted) {
      snack(context,
          'Could not get your location in time. Check that Location is on, then try again.',
          error: true);
    }
    return null;
  } catch (e) {
    if (context.mounted) {
      snack(context, 'Could not get your location: $e', error: true);
    }
    return null;
  } finally {
    if (dialogRoute.isActive) nav.removeRoute(dialogRoute);
  }

  if (fix != null) return fix;
  if (context.mounted) {
    snack(context, 'No location fix yet — check Location is on and try again.',
        error: true);
  }
  return null;
}

bool _freshEnough(Position? p, Duration maxAge) {
  if (p == null) return false;
  try {
    return DateTime.now().difference(p.timestamp) <= maxAge;
  } catch (_) {
    return false;
  }
}

// HuntInKE — one shared "use my location" flow for Home and Map.
// Handles the full journey the same way on every device:
//   1. asks the permission (and opens App Settings if it was permanently blocked)
//   2. if GPS service is OFF: opens the settings switch and AUTO-CONTINUES the
//      moment the user turns it on — no need to press the button again
//   3. tries the last known fix first (instant on most devices/emulators)
//   4. waits up to 30s for a fresh fix, with a clear message if it never locks
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets.dart';

Future<Position?> huntinGetLocation(BuildContext context) async {
  // 1) permission
  final status = await Permission.locationWhenInUse.request();
  if (status.isPermanentlyDenied) {
    if (context.mounted) {
      snack(context, 'Location is blocked — allow it in Settings, then press again', error: true);
      try { await Geolocator.openAppSettings(); } catch (_) {}
    }
    return null;
  }
  if (!status.isGranted) {
    if (context.mounted) snack(context, 'Location permission denied — pick your town instead', error: true);
    return null;
  }

  Future<bool> servicesOn() async {
    try { return await Geolocator.isLocationServiceEnabled(); } catch (_) { return false; }
  }

  // 2) GPS service off → open the switch, keep watching, continue automatically
  if (!await servicesOn()) {
    if (context.mounted) snack(context, 'Turn location ON — the app continues by itself');
    try { await Geolocator.openLocationSettings(); } catch (_) {}
    final started = DateTime.now();
    while (DateTime.now().difference(started) < const Duration(seconds: 45)) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (await servicesOn()) break;
    }
    if (!await servicesOn()) {
      if (context.mounted) snack(context, 'Location is still off — pick your town instead', error: true);
      return null;
    }
  }

  // 3) last known fix first — instant on most devices
  try {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;
  } catch (_) {}

  // 4) fresh fix
  try {
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 30));
  } on TimeoutException {
    if (context.mounted) {
      snack(context, 'GPS is taking too long — press again, or pick your town below', error: true);
    }
  } catch (_) {
    if (context.mounted) snack(context, 'Could not get your location — pick your town instead', error: true);
  }
  return null;
}

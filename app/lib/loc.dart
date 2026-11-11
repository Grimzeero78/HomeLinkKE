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
import 'package:permission_handler/permission_handler.dart';
import 'theme.dart';
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

  // 3) progress dialog while we hunt for a fix — the user always sees state
  final nav = Navigator.of(context, rootNavigator: true);
  unawaited(showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6)),
          const SizedBox(width: 16),
          Expanded(child: Text('Getting your location…',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: T(Theme.of(ctx).brightness).ink))),
        ]),
      ),
    ),
  ));

  Position? fix;
  try {
    try { fix = await Geolocator.getLastKnownPosition(); } catch (_) {} // instant if cached
    fix ??= await _fresh(LocationAccuracy.medium, const Duration(seconds: 18));
    fix ??= await _fresh(LocationAccuracy.low, const Duration(seconds: 12));
  } finally {
    try { if (nav.canPop()) nav.pop(); } catch (_) {}
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
    return await Geolocator.getCurrentPosition(desiredAccuracy: acc, timeLimit: limit);
  } catch (_) {
    return null; // timeout / provider error — try the next chain step
  }
}

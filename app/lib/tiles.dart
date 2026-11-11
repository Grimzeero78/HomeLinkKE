// HuntInKE — the app's map tile engine, an exact port of the website's
// public/js/maps.js addTiles(): real Google Maps tiles (the same roads style
// the website shows) with CARTO Voyager as the automatic backup.
//
// NO API KEY IS NEEDED — the website's map works with none, and neither does
// the app: both draw the same public map-tile endpoint a browser draws.
// (google_maps_flutter would need a key; flutter_map + tiles does not.)
//
// Three safety nets, mirroring maps.js:
//   1. fallbackUrl       — any single Google tile that fails is retried from
//                          CARTO (flutter_map built-in, per tile).
//   2. error counter     — >= 10 Google tile errors within a 25 s window swaps
//                          the whole map to CARTO (same thresholds as the web,
//                          which also shows a toast — the screens show a snack
//                          through [HuntinTiles.onFallback]).
//   3. one-shot probe    — a hanging request never fires errorTileCallback, so
//                          on open we probe one Google tile with a hard 4 s
//                          cap; if it does not answer, the map starts on CARTO
//                          straight away (cached once per app session).
import 'dart:io' show HttpClient;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Google roads tiles — the exact URL the website's maps.js uses (TILES.googleRoads).
const String kTileGoogle =
    'https://mt{s}.google.com/vt/lyrs=m&hl=en&x={x}&y={y}&z={z}&s=Ga';

/// CARTO Voyager backup — the website's TILES.backupRoads (single subdomain
/// form so [TileLayer.fallbackUrl] never needs {s} substitution).
const String kTileCarto =
    'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

const List<String> kGoogleSubdomains = ['0', '1', '2', '3'];
const List<String> kCartoSubdomains = ['a', 'b', 'c', 'd'];

const String kAttrGoogle = 'Map data © Google';
const String kAttrCarto = '© OpenStreetMap contributors © CARTO';

Future<bool>? _googleProbeP;

/// Can this device reach the Google tile endpoint right now? One probe per
/// app session, 4 s hard cap (a hung request counts as "no").
Future<bool> _probeGoogleTiles() {
  return _googleProbeP ??= () async {
    try {
      final c = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final req = await c.getUrl(Uri.parse(
          'https://mt0.google.com/vt/lyrs=m&hl=en&x=19736&y=16501&z=15&s=Ga'));
      final res = await req.close().timeout(const Duration(seconds: 4));
      final ok = res.statusCode == 200;
      await res
          .drain<void>()
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      c.close(force: true);
      return ok;
    } catch (_) {
      return false;
    }
  }();
}

/// The map tile layer every HuntInKE screen uses — Google roads with a silent
/// CARTO backup, exactly like the website. Start on Google immediately (the
/// website never waits); swap away only if the probe fails or tiles error.
class HuntinTiles extends StatefulWidget {
  const HuntinTiles({super.key, this.maxNativeZoom = 20, this.onFallback});

  /// Top zoom level real tiles exist for (the website streams up to z20 and
  /// over-zooms past it).
  final int maxNativeZoom;

  /// Fires ONCE when the map falls back to CARTO because Google tiles kept
  /// failing — screens use it to show the website's toast as a snack and to
  /// swap the attribution line. A probe failure at open is silent (no callback).
  final void Function()? onFallback;

  @override
  State<HuntinTiles> createState() => _HuntinTilesState();
}

class _HuntinTilesState extends State<HuntinTiles> {
  bool _backup = false;
  bool _notified = false;
  int _errs = 0;
  DateTime _win = DateTime.now();

  @override
  void initState() {
    super.initState();
    _probeGoogleTiles().then((ok) {
      if (!mounted || ok || _backup) return;
      setState(() => _backup = true);
    });
  }

  // maps.js: count tile errors; >= 10 inside a 25 s window => swap to the
  // backup style once. Outside the window the counter restarts.
  void _onTileError(Object error, StackTrace? s) {
    if (_backup || _errs < 0) return;
    final now = DateTime.now();
    if (now.difference(_win).inMilliseconds > 25000) {
      _errs = 1;
      _win = now;
      return;
    }
    _errs++;
    if (_errs >= 10) {
      _backup = true;
      if (mounted) setState(() {});
      if (!_notified) {
        _notified = true;
        widget.onFallback?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_backup) {
      return TileLayer(
        urlTemplate: kTileCarto,
        subdomains: kCartoSubdomains,
        maxNativeZoom: widget.maxNativeZoom,
        keepBuffer: 4,
        panBuffer: 2,
        userAgentPackageName: 'com.huntin.ke',
      );
    }
    return TileLayer(
      urlTemplate: kTileGoogle,
      fallbackUrl: kTileCarto,
      subdomains: kGoogleSubdomains,
      maxNativeZoom: widget.maxNativeZoom,
      keepBuffer: 4,
      panBuffer: 2,
      userAgentPackageName: 'com.huntin.ke',
      errorTileCallback: (tile, error, stackTrace) =>
          _onTileError(error, stackTrace),
    );
  }
}

/// The attribution line matching the active tile source (the website swaps the
/// text when it falls back). Screens rebuild it via the [HuntinTiles.onFallback]
/// callback + a `bool _onBackup` state flag.
Widget huntinAttribution(bool onBackup) => RichAttributionWidget(
      attributions: [
        TextSourceAttribution(onBackup ? kAttrCarto : kAttrGoogle)
      ],
    );

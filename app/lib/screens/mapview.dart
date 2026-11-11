// HuntInKE — Map (exact port of viewMap()): OpenStreetMap tiles with every pinned
// house shown as a price chip, place search (Kenya towns first, Nominatim bounded to
// Kenya as fallback), radius chips (1/3/5/10/25 km / Any), "Use my location", and a
// bottom-sheet list — tap a house to fly to its exact spot. Maps stay light in dark
// mode (same rule as the website).
import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import 'listing.dart';

const MAP_RADIUS = <String, int>{'1': 1000, '3': 3000, '5': 5000, '10': 10000, '25': 25000, '': 0};

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();
  final _q = TextEditingController();
  bool _loading = true;
  List<Listing> _items = [];          // all fetched
  List<Listing> _shown = [];          // after radius filter
  String _rad = '';
  ll.LatLng? _center;                 // filter centre (GPS or searched place)
  final Map<int, double> _dist = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final st = context.read<AppState>();
    try {
      final rows = await st.api.listings(sort: 'new', bt: st.myTown, limit: 100);
      if (!mounted) return;
      _items = rows.map((j) => Listing.fromJson((j as Map).cast<String, dynamic>())).toList();
      if (st.myLat != null) _center = ll.LatLng(st.myLat!, st.myLng!);
      _applyFilter();
      setState(() => _loading = false);
      // fit the map after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
    }
  }

  void _fitAll() {
    final pinned = _shown.where((l) => l.hasLocation).toList();
    if (pinned.isEmpty) return;
    if (_center == null && pinned.isNotEmpty) {
      double minLat = pinned.first.lat!, maxLat = pinned.first.lat!;
      double minLng = pinned.first.lng!, maxLng = pinned.first.lng!;
      for (final l in pinned) {
        minLat = minLat < l.lat! ? minLat : l.lat!;
        maxLat = maxLat > l.lat! ? maxLat : l.lat!;
        minLng = minLng < l.lng! ? minLng : l.lng!;
        maxLng = maxLng > l.lng! ? maxLng : l.lng!;
      }
      try { _map.move(ll.LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2), 10); } catch (_) {}
    }
  }

  void _applyFilter() {
    _dist.clear();
    if (_center == null || _rad.isEmpty) {
      _shown = _items;
      return;
    }
    final lim = MAP_RADIUS[_rad] ?? 0;
    _shown = _items.where((l) {
      if (!l.hasLocation) return false;
      final d = distMeters(_center!.latitude, _center!.longitude, l.lat!, l.lng!);
      _dist[l.id] = d;
      return d <= lim;
    }).toList();
  }

  Future<void> _useMyLocation() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (mounted) snack(context, 'Location permission denied', error: true);
      return;
    }
    try {
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 15));
      final st = context.read<AppState>();
      await st.setMyPos(p.latitude, p.longitude);
      final near = nearestTown(p.latitude, p.longitude);
      if (near != null && distMeters(p.latitude, p.longitude, near.lat, near.lng) < 60000) {
        await st.setMyTown(near.n);
      }
      _center = ll.LatLng(p.latitude, p.longitude);
      _applyFilter();
      try { _map.move(_center!, 15); } catch (_) {}
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) snack(context, 'Could not get your location', error: true);
    }
  }

  Future<void> _doSearch() async {
    final raw = _q.text.trim();
    if (raw.isEmpty) return;
    final low = raw.toLowerCase();
    Town? hit;
    for (final tw in TOWNS) {
      if (tw.n.toLowerCase() == low) { hit = tw; break; }
    }
    hit ??= TOWNS.where((tw) => tw.n.toLowerCase().startsWith(low)).firstOrNull;
    hit ??= TOWNS.where((tw) => tw.n.toLowerCase().contains(low)).firstOrNull;
    if (hit == null) {
      // Nominatim bounded to Kenya (same fallback as the website)
      try {
        final uri = Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&limit=1&accept-language=en&countrycodes=ke&viewbox=33.4%2C5.6%2C42.4%2C-5.0&bounded=1&q=${Uri.encodeComponent(raw)}');
        final r = await _fetchJson(uri);
        if (r is List && r.isNotEmpty) {
          hit = Town(raw, double.parse(r[0]['lat'].toString()), double.parse(r[0]['lon'].toString()));
        }
      } catch (_) {}
    }
    if (!mounted) return;
    if (hit == null) {
      snack(context, 'Place not found — try a town name, estate or road', error: true);
      return;
    }
    _center = ll.LatLng(hit.lat, hit.lng);
    _applyFilter();
    try { _map.move(_center!, 15); } catch (_) {}
    setState(() {});
  }

  Future<dynamic> _fetchJson(Uri uri) async {
    try {
      final client = HttpClient();
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('User-Agent', 'HuntInKE-App/1.0');
      final res = await req.close().timeout(const Duration(seconds: 12));
      final body = await res.transform(utf8.decoder).join();
      client.close();
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  void _openListing(Listing l) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ListingScreen(l.id)));
  }

  void _flyTo(Listing l) {
    if (!l.hasLocation) {
      snack(context, 'This house is not pinned yet — ask the landlord in chat', error: true);
      return;
    }
    try { _map.move(ll.LatLng(l.lat!, l.lng!), 18); } catch (_) {}
  }

  void _showList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .55, maxChildSize: .9,
        builder: (ctx, sc) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(children: [
              Text('${_shown.length} house${_shown.length == 1 ? '' : 's'} on the map',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ]),
          ),
          Expanded(child: ListView.builder(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
            itemCount: _shown.length,
            itemBuilder: (ctx, i) {
              final l = _shown[i];
              final t = T(Theme.of(ctx).brightness);
              final dl = _dist.containsKey(l.id) ? ' · ${fmtDist(_dist[l.id]!)} away' : '';
              return InkWell(
                onTap: () { Navigator.pop(ctx); _flyTo(l); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(10),
                        child: SizedBox(width: 56, height: 56,
                            child: l.thumb.isNotEmpty
                                ? DataImg(l.thumb, cachePx: 112, fit: BoxFit.cover, placeholder: Container(color: t.galBg))
                                : Container(color: t.galBg, child: Icon(Icons.photo_outlined, size: 20, color: t.ink3)))),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('${kes(l.rent)}/${perShort(l.period)}',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: t.pineInk)),
                        if (l.boosted) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.bolt, size: 13, color: C.ember),
                        ],
                      ]),
                      Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.ink)),
                      Text('${l.town}${l.area.isNotEmpty ? ' · ${l.area}' : ''}${l.landmark.isNotEmpty ? ' · ${l.landmark}' : ''}$dl',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: t.ink3)),
                    ])),
                    TextButton(onPressed: () { Navigator.pop(ctx); _openListing(l); }, child: const Text('View')),
                  ]),
                ),
              );
            },
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final st = context.watch<AppState>();
    final start = st.myLat != null
        ? ll.LatLng(st.myLat!, st.myLng!)
        : (TOWNS.where((x) => x.n == st.myTown).firstOrNull != null
            ? ll.LatLng(TOWNS.where((x) => x.n == st.myTown).first.lat, TOWNS.where((x) => x.n == st.myTown).first.lng)
            : ll.LatLng(KENYA_CENTER.lat, KENYA_CENTER.lng));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Map of houses in Kenya')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _q,
              onSubmitted: (_) => _doSearch(),
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(hintText: 'Search a place — e.g. Kilimani, Nanyuki…'),
            )),
            const SizedBox(width: 8),
            SizedBox(height: 44, width: 48, child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 44), padding: EdgeInsets.zero),
              onPressed: _doSearch,
              child: const Icon(Icons.search, size: 19))),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 10), textStyle: const TextStyle(fontSize: 12)),
                onPressed: _useMyLocation,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.location_on_outlined, size: 14), SizedBox(width: 4), Text('Use my location'),
                ]),
              ),
              const SizedBox(width: 7),
              Center(child: Text('Within:', style: TextStyle(fontSize: 11.5, color: t.ink3))),
              const SizedBox(width: 5),
              for (final r in MAP_RADIUS.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () { setState(() => _rad = r); _applyFilter(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: _rad == r ? t.pineBtn : t.card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _rad == r ? t.pineBtn : t.line, width: 1.3),
                      ),
                      child: Text(r.isEmpty ? 'Any' : '$r km',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: _rad == r ? Colors.white : t.ink2)),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 10), textStyle: const TextStyle(fontSize: 12)),
                onPressed: _showList,
                child: Text('${_shown.length} houses', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Stack(children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: start,
                      initialZoom: st.myLat != null ? 15 : (st.myTown.isNotEmpty ? 13 : 7),
                      minZoom: 6,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'ke.huntin.app',
                      ),
                      MarkerLayer(
                        markers: [
                          for (final l in _shown.where((x) => x.hasLocation))
                            Marker(
                              point: ll.LatLng(l.lat!, l.lng!),
                              width: 66, height: 30,
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                onTap: () => _openListing(l),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: l.boosted ? C.ember : t.pineBtn,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white, width: 1.6),
                                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2))],
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  child: Text('${shortK(l.rent)}/${perShort(l.period)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 12, bottom: 18,
                    child: FloatingActionButton.small(
                      backgroundColor: t.card,
                      foregroundColor: t.pine,
                      heroTag: 'map-loc',
                      onPressed: _useMyLocation,
                      child: const Icon(Icons.my_location, size: 20),
                    ),
                  ),
                ],
              ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(children: [
            Icon(Icons.info_outline, size: 13, color: t.ink3),
            const SizedBox(width: 6),
            Expanded(child: Text('Tap a price chip to open the listing. Use the ${_shown.length} houses button for the full list.',
                style: TextStyle(fontSize: 11.5, color: t.ink3))),
          ]),
        ),
      ]),
    );
  }
}

extension _FirstOr<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

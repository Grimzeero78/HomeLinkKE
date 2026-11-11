// HuntInKE — Post / Edit listing wizard (exact port of viewCreate(), 8 steps):
// Basics · Location (searchable town + map pin) · Pricing · Utilities · Inside ·
// Tenants · Availability · Photos (3–8, compressed to data URLs exactly like the web).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../data.dart';
import '../notifs.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';

class CreateScreen extends StatefulWidget {
  final int? editId;
  const CreateScreen({super.key, this.editId});
  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  static const _stepNames = ['Basics', 'Location', 'Pricing', 'Utilities', 'Inside', 'Tenants', 'Availability', 'Photos'];
  int _step = 0;
  bool _busy = false;
  String _error = '';
  bool _loadingExisting = false;

  // ---- the listing draft (same keys the API expects) ----
  final Map<String, dynamic> L = {
    'title': '', 'ptype': 'Bedsitter', 'units': 1, 'unitsVacant': 1,
    'furnishing': 'Unfurnished', 'floor': 'Ground',
    'town': '', 'area': '', 'landmark': '', 'lat': null, 'lng': null, 'road': 'Tarmac',
    'rent': '', 'period': 'Per Month', 'deposit': '', 'fees': 'None', 'negotiable': false, 'terms': '',
    'water': 'Included in rent', 'waterCost': '', 'waterSched': '', 'waterTank': 'No',
    'elec': 'Own token meter', 'elecCost': '', 'wifi': 'Not available', 'wifiCost': '', 'wifiProvider': '',
    'garbage': 'Included', 'backup': 'None',
    'bath': '1', 'ensuite': 'No', 'kitchen': 'No', 'parking': 'No', 'balcony': 'No',
    'tile': 'Tiled', 'ceiling': 'Yes', 'wardrobe': 'No', 'hotShower': 'No',
    'security': <String>[], 'tenantPref': 'Anyone', 'pets': 'No',
    'availableFrom': 'Available now', 'contactPhone': '', 'tags': '',
    'photos': <String>[], 'thumbs': <String>[],
  };

  final _title = TextEditingController(), _area = TextEditingController(), _landmark = TextEditingController(),
      _rent = TextEditingController(), _deposit = TextEditingController(), _fees = TextEditingController(),
      _terms = TextEditingController(), _waterCost = TextEditingController(), _waterSched = TextEditingController(),
      _elecCost = TextEditingController(), _wifiCost = TextEditingController(), _wifiProvider = TextEditingController(),
      _phone = TextEditingController(), _tags = TextEditingController(), _availDate = TextEditingController();

  final MapController _pinMap = MapController();
  ll.LatLng? _pin;
  Town? _townSel;

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) _loadExisting();
  }

  @override
  void dispose() {
    for (final c in [_title, _area, _landmark, _rent, _deposit, _fees, _terms, _waterCost, _waterSched, _elecCost, _wifiCost, _wifiProvider, _phone, _tags, _availDate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    final st = context.read<AppState>();
    try {
      final r = await st.api.listing(widget.editId!);
      if (!mounted) return;
      if (r['isOwner'] != true) {
        setState(() { _error = 'Not your listing.'; _loadingExisting = false; });
        return;
      }
      final l = (r['listing'] as Map).cast<String, dynamic>();
      L.addAll(l);
      _title.text = (l['title'] ?? '').toString();
      _area.text = (l['area'] ?? '').toString();
      _landmark.text = (l['landmark'] ?? '').toString();
      _rent.text = (l['rent'] ?? '').toString();
      _deposit.text = (l['deposit'] ?? '').toString();
      _fees.text = (l['fees'] ?? 'None').toString();
      _terms.text = (l['terms'] ?? '').toString();
      _waterCost.text = (l['waterCost'] ?? '').toString();
      _waterSched.text = (l['waterSched'] ?? '').toString();
      _elecCost.text = (l['elecCost'] ?? '').toString();
      _wifiCost.text = (l['wifiCost'] ?? '').toString();
      _wifiProvider.text = (l['wifiProvider'] ?? '').toString();
      _phone.text = (l['contactPhone'] ?? '').toString();
      _tags.text = (l['tags'] ?? '').toString();
      L['negotiable'] = l['negotiable'] == 1 || l['negotiable'] == true || l['negotiable'] == 'Yes';
      L['security'] = parseSecurity((l['security'] ?? '[]').toString());
      L['photos'] = ((r['photos'] ?? []) as List).map((p) => (p as Map)['url'].toString()).toList();
      L['thumbs'] = ((r['photos'] ?? []) as List).map((p) => (p as Map)['thumb']?.toString() ?? '').toList();
      if (l['lat'] != null && l['lng'] != null) {
        _pin = ll.LatLng((l['lat'] as num).toDouble(), (l['lng'] as num).toDouble());
      }
      final tw = TOWNS.where((x) => x.n == (l['town'] ?? '')).firstOrNull;
      _townSel = tw;
      setState(() => _loadingExisting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('ApiException: ', ''); _loadingExisting = false; });
    }
  }

  // ---- validation per step (same rules as the API) ----
  String? _validate() {
    switch (_step) {
      case 0:
        if (_title.text.trim().length < 4) return 'Title must be at least 4 characters';
        if (_townSel == null) return 'Choose the town';
        return null;
      case 2:
        final rent = num.tryParse(_rent.text.trim());
        if (rent == null || rent < 1) return 'Rent is required';
        return null;
      case 7:
        if ((L['photos'] as List).length < 3) return 'Add at least 3 photos';
        if ((L['photos'] as List).length > 8) return 'Maximum 8 photos';
        return null;
      default:
        return null;
    }
  }

  Future<void> _submit() async {
    final st = context.read<AppState>();
    L['title'] = _title.text.trim();
    L['area'] = _area.text.trim();
    L['landmark'] = _landmark.text.trim();
    L['rent'] = num.tryParse(_rent.text.trim()) ?? 0;
    L['deposit'] = num.tryParse(_deposit.text.trim()) ?? 0;
    L['fees'] = _fees.text.trim().isEmpty ? 'None' : _fees.text.trim();
    L['terms'] = _terms.text.trim();
    L['waterCost'] = _waterCost.text.trim();
    L['waterSched'] = _waterSched.text.trim();
    L['elecCost'] = _elecCost.text.trim();
    L['wifiCost'] = _wifiCost.text.trim();
    L['wifiProvider'] = _wifiProvider.text.trim();
    L['contactPhone'] = _phone.text.trim();
    L['tags'] = _tags.text.trim();
    L['town'] = _townSel?.n ?? '';
    L['negotiable'] = L['negotiable'] == true;
    if (_pin != null) {
      L['lat'] = _pin!.latitude;
      L['lng'] = _pin!.longitude;
    }
    if (_availDate.text.isNotEmpty && L['availableFrom'] == 'Pick a date…') {
      L['availableFrom'] = _availDate.text.trim();
    }
    setState(() { _busy = true; _error = ''; });
    try {
      if (widget.editId != null) {
        await st.api.updateListing(widget.editId!, L);
        if (!mounted) return;
        snack(context, 'Listing updated');
        Notifs.showAccount('Listing updated', '"${L['title']}" was saved successfully.');
      } else {
        await st.api.createListing(L);
        if (!mounted) return;
        snack(context, 'Listing posted!');
        Notifs.showAccount('Listing posted', '"${L['title']}" is now live. Boost it for KES $BOOST_AMOUNT_KES to get seen first.');
      }
      Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('ApiException: ', ''); _busy = false; });
    }
  }

  Future<void> _addPhotos() async {
    final picker = ImagePicker();
    final room = 8 - (L['photos'] as List).length;
    if (room <= 0) { snack(context, 'Maximum 8 photos', error: true); return; }
    final imgs = await picker.pickMultiImage(imageQuality: 70, limit: room);
    if (imgs.isEmpty) return;
    if (mounted) snack(context, 'Processing ${imgs.length} photo${imgs.length == 1 ? '' : 's'}…');
    for (final x in imgs) {
      final bytes = await x.readAsBytes();
      final url = await compressToDataUrl(bytes, maxKB: 700, maxDim: 1200, q: 72);
      final thumb = await thumbFrom(bytes);
      setState(() {
        (L['photos'] as List).add(url);
        (L['thumbs'] as List).add(thumb);
      });
    }
  }

  void _removePhoto(int i) {
    setState(() {
      (L['photos'] as List).removeAt(i);
      (L['thumbs'] as List).removeAt(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final st = context.watch<AppState>();
    if (st.user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in first')));
    }
    if (st.user!.role != 'LANDLORD' && st.user!.role != 'ADMIN') {
      return Scaffold(backgroundColor: t.bg, appBar: AppBar(), body: ListView(children: const [
        EmptyBox(Icons.lock_outline, 'Landlords only',
            'Only landlord accounts can post listings. Create a landlord account to list your rooms.'),
      ]));
    }
    if (_loadingExisting) {
      return Scaffold(backgroundColor: t.bg, appBar: AppBar(), body: ListView(padding: const EdgeInsets.all(14), children: const [Skel(h: 300)]));
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: Text(widget.editId != null ? 'Edit listing' : 'Post a listing')),
      body: Column(children: [
        // step header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Step ${_step + 1} of 8 — ${_stepNames[_step]}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: t.ink)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (_step + 1) / 8, minHeight: 6,
                backgroundColor: t.soft, color: t.pine,
              ),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            children: [
              if (_error.isNotEmpty) ...[
                Notice(Icons.error_outline, _error, kind: 'r'),
                const SizedBox(height: 10),
              ],
              _body(context),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Row(children: [
              if (_step > 0)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => setState(() { _step--; _error = ''; }),
                  child: const Text('Back'),
                )
              else
                Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 9),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          final err = _validate();
                          if (err != null) { setState(() => _error = err); return; }
                          setState(() => _error = '');
                          if (_step < 7) {
                            setState(() => _step++);
                          } else {
                            _submit();
                          }
                        },
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : Text(_step < 7 ? 'Next' : (widget.editId != null ? 'Save changes' : 'Post my listing')),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ---------- step bodies ----------
  Widget _body(BuildContext context) {
    switch (_step) {
      case 0: return _basics(context);
      case 1: return _location(context);
      case 2: return _pricing(context);
      case 3: return _utilities(context);
      case 4: return _inside(context);
      case 5: return _tenants(context);
      case 6: return _availability(context);
      case 7: return _photosStep(context);
      default: return const SizedBox.shrink();
    }
  }

  Widget _lbl(BuildContext context, String s, [String? hint]) {
    final t = T(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 13, 0, 6),
      child: Text(s + (hint == null ? '' : '  ($hint)'),
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.ink2)),
    );
  }

  Widget _seg(BuildContext context, List<String> options, String value, void Function(String) onPick) {
    final t = T(Theme.of(context).brightness);
    return Wrap(spacing: 7, runSpacing: 7, children: [
      for (final o in options)
        GestureDetector(
          onTap: () => onPick(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: value == o ? t.pineBtn : t.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: value == o ? t.pineBtn : t.line, width: 1.4),
            ),
            child: Text(o, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                color: value == o ? Colors.white : t.ink2)),
          ),
        ),
    ]);
  }

  Widget _yn(BuildContext context, String key) => _seg(context, ['Yes', 'No'], (L[key] ?? 'No').toString(),
      (v) => setState(() => L[key] = v));

  Widget _basics(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(context, 'Listing title'),
      TextField(controller: _title, maxLength: 90,
          decoration: const InputDecoration(hintText: 'e.g. Clean bedsitter near Chuka University gate')),
      _lbl(context, 'Property type'),
      _seg(context, TYPES, (L['ptype'] ?? '').toString(), (v) => setState(() => L['ptype'] = v)),
      _lbl(context, 'How many units in the compound?', 'rooms / houses total'),
      SizedBox(
        width: 110,
        child: TextField(
          keyboardType: TextInputType.number,
          onChanged: (v) {
            final n = int.tryParse(v.trim()) ?? 1;
            L['units'] = n < 1 ? 1 : n;
          },
          decoration: InputDecoration(hintText: '${L['units']}'),
        ),
      ),
      _lbl(context, 'Furnishing'),
      _seg(context, FURN, (L['furnishing'] ?? '').toString(), (v) => setState(() => L['furnishing'] = v)),
      _lbl(context, 'How many floors does the building have?'),
      SizedBox(
        height: 44,
        child: DropdownButtonFormField<String>(
          value: (L['floor'] ?? 'Ground').toString(),
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
          items: [for (final f in FLOORS) DropdownMenuItem(value: f, child: Text(f == 'Ground' ? 'Ground only' : f))],
          onChanged: (v) => setState(() => L['floor'] = v),
        ),
      ),
      _lbl(context, 'Search tags', 'renters find you by words like "near JKUAT" — comma separated'),
      TextField(controller: _tags,
          decoration: const InputDecoration(hintText: 'e.g. near JKUAT, behind market, bodaboda stage')),
    ]);
  }

  Widget _location(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(context, 'Town'),
      SizedBox(
        height: 44,
        child: DropdownButtonFormField<Town>(
          value: _townSel,
          isExpanded: true,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
          items: [for (final tw in TOWNS) DropdownMenuItem(value: tw, child: Text(tw.n))],
          onChanged: (v) => setState(() => _townSel = v),
        ),
      ),
      _lbl(context, 'Area / estate'),
      TextField(controller: _area, decoration: const InputDecoration(hintText: 'e.g. Magomano, Kianjai')),
      _lbl(context, 'Nearest landmark'),
      TextField(controller: _landmark, decoration: const InputDecoration(hintText: 'e.g. next to Chuka Law Courts')),
      _lbl(context, 'Road access'),
      _seg(context, ROADS, (L['road'] ?? '').toString(), (v) => setState(() => L['road'] = v)),
      _lbl(context, 'Pin the exact spot on the map', 'renters see this pin and get directions to it'),
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 260,
          child: FlutterMap(
            mapController: _pinMap,
            options: MapOptions(
              initialCenter: _pin ?? (st0(context)),
              initialZoom: _pin != null ? 17 : 12,
              onTap: (tap, p) => setState(() => _pin = p),
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'ke.huntin.app'),
              if (_pin != null)
                MarkerLayer(markers: [
                  Marker(point: _pin!, width: 44, height: 44, child:
                      const Icon(Icons.location_on, size: 44, color: C.bad)),
                ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 7),
      Row(children: [
        Expanded(child: Text(_pin == null
            ? 'Tap the map to drop your pin'
            : 'Pin set — ${_pin!.latitude.toStringAsFixed(5)}, ${_pin!.longitude.toStringAsFixed(5)}',
            style: TextStyle(fontSize: 12, color: t.ink2))),
        if (_pin != null)
          TextButton(onPressed: () => setState(() => _pin = null), child: const Text('Remove pin', style: TextStyle(fontSize: 12))),
      ]),
    ]);
  }

  ll.LatLng st0(BuildContext context) {
    final st = context.read<AppState>();
    if (st.myLat != null) return ll.LatLng(st.myLat!, st.myLng!);
    final tw = _townSel ?? TOWNS.first;
    return ll.LatLng(tw.lat, tw.lng);
  }

  Widget _pricing(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(context, 'Rent (KES)'),
      TextField(controller: _rent, keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 6500')),
      _lbl(context, 'Billing period'),
      _seg(context, PERIODS, (L['period'] ?? '').toString(), (v) => setState(() => L['period'] = v)),
      _lbl(context, 'Deposit (KES)', '0 if none'),
      TextField(controller: _deposit, keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 6500')),
      _lbl(context, 'Move-in fees', 'water deposit, garbage, NONE…'),
      TextField(controller: _fees, decoration: const InputDecoration(hintText: 'e.g. None')),
      _lbl(context, 'Negotiable?'),
      _seg(context, ['Yes', 'No'], L['negotiable'] == true ? 'Yes' : 'No',
          (v) => setState(() => L['negotiable'] = v == 'Yes')),
      _lbl(context, 'Other terms', 'rules, notice period, anything else'),
      TextField(controller: _terms, maxLines: 3,
          decoration: const InputDecoration(hintText: 'e.g. Rent due by 5th of every month')),
    ]);
  }

  Widget _utilities(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(context, 'Water'),
      _seg(context, WATER, (L['water'] ?? '').toString(), (v) => setState(() => L['water'] = v)),
      if (L['water'] == 'Pay separately' || L['water'] == 'Rationed') ...[
        _lbl(context, 'Water cost'),
        TextField(controller: _waterCost, decoration: const InputDecoration(hintText: 'e.g. KES 200 per 20L jerrican')),
      ],
      if (L['water'] == 'Rationed') ...[
        _lbl(context, 'Water schedule'),
        TextField(controller: _waterSched, decoration: const InputDecoration(hintText: 'e.g. Tue & Fri, 6–9 AM')),
      ],
      _lbl(context, 'Storage tank?'),
      _yn(context, 'waterTank'),
      _lbl(context, 'Electricity'),
      _seg(context, ELEC, (L['elec'] ?? '').toString(), (v) => setState(() => L['elec'] = v)),
      if (L['elec'] == 'Shared meter') ...[
        _lbl(context, 'Electricity cost'),
        TextField(controller: _elecCost, decoration: const InputDecoration(hintText: 'e.g. KES 15 per unit')),
      ],
      _lbl(context, 'WiFi'),
      _seg(context, WIFI, (L['wifi'] ?? '').toString(), (v) => setState(() => L['wifi'] = v)),
      if (L['wifi'] == 'Available but paid separately') ...[
        _lbl(context, 'WiFi cost'),
        TextField(controller: _wifiCost, decoration: const InputDecoration(hintText: 'e.g. KES 500 per month')),
        _lbl(context, 'WiFi provider'),
        TextField(controller: _wifiProvider, decoration: const InputDecoration(hintText: 'e.g. Faiba, Safaricom')),
      ],
      _lbl(context, 'Garbage'),
      _seg(context, GARBAGE, (L['garbage'] ?? '').toString(), (v) => setState(() => L['garbage'] = v)),
      _lbl(context, 'Backup power'),
      _seg(context, BACKUP, (L['backup'] ?? '').toString(), (v) => setState(() => L['backup'] = v)),
    ]);
  }

  Widget _inside(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(context, 'Bathrooms'),
      _seg(context, BATHS, (L['bath'] ?? '1').toString(), (v) => setState(() => L['bath'] = v)),
      _lbl(context, 'Bathroom inside (self-contained)?'),
      _yn(context, 'ensuite'),
      _lbl(context, 'Own kitchen?'),
      _yn(context, 'kitchen'),
      _lbl(context, 'Parking?'),
      _yn(context, 'parking'),
      _lbl(context, 'Balcony?'),
      _yn(context, 'balcony'),
      _lbl(context, 'Floor finish'),
      _seg(context, ['Tiled', 'Concrete', 'Slats'], (L['tile'] ?? '').toString(), (v) => setState(() => L['tile'] = v)),
      _lbl(context, 'Ceiling?'),
      _yn(context, 'ceiling'),
      _lbl(context, 'Built-in wardrobes?'),
      _yn(context, 'wardrobe'),
      _lbl(context, 'Hot shower?'),
      _yn(context, 'hotShower'),
    ]);
  }

  Widget _tenants(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(context, 'Security'),
      Wrap(spacing: 7, runSpacing: 7, children: [
        for (final s in SECURITY)
          GestureDetector(
            onTap: () {
              final cur = (L['security'] as List).cast<String>();
              setState(() => cur.contains(s) ? cur.remove(s) : cur.add(s));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (L['security'] as List).contains(s) ? t0(context) : t0card(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: (L['security'] as List).contains(s) ? t0(context) : t0line(context), width: 1.4),
              ),
              child: Text(s, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                  color: (L['security'] as List).contains(s) ? Colors.white : t0ink2(context))),
            ),
          ),
      ]),
      _lbl(context, 'Preferred tenants'),
      _seg(context, TENANTS, (L['tenantPref'] ?? '').toString(), (v) => setState(() => L['tenantPref'] = v)),
      _lbl(context, 'Pets allowed?'),
      _yn(context, 'pets'),
    ]);
  }

  Color t0(BuildContext context) => T(Theme.of(context).brightness).pineBtn;
  Color t0card(BuildContext context) => T(Theme.of(context).brightness).card;
  Color t0line(BuildContext context) => T(Theme.of(context).brightness).line;
  Color t0ink2(BuildContext context) => T(Theme.of(context).brightness).ink2;

  Widget _availability(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(context, 'Units vacant right now', 'this is what renters see — keep it true'),
      SizedBox(
        width: 110,
        child: TextField(
          keyboardType: TextInputType.number,
          onChanged: (v) {
            final n = int.tryParse(v.trim()) ?? 1;
            L['unitsVacant'] = n < 0 ? 0 : (n > 50 ? 50 : n);
          },
          decoration: InputDecoration(hintText: '${L['unitsVacant']}'),
        ),
      ),
      const SizedBox(height: 5),
      Text('0 = all occupied (the listing shows ALL OCCUPIED). Vacancy-first: write only how many are free NOW.',
          style: TextStyle(fontSize: 12, color: T(Theme.of(context).brightness).ink3, height: 1.5)),
      _lbl(context, 'Available from'),
      _seg(context, AVAIL_OPTIONS, (L['availableFrom'] ?? '').toString(), (v) {
        setState(() => L['availableFrom'] = v);
        if (v == 'Pick a date…') _pickDate(context);
      }),
      if (L['availableFrom'] == 'Pick a date…' && _availDate.text.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Date: ${_availDate.text}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      _lbl(context, 'Contact phone on the listing', 'defaults to your WhatsApp number'),
      TextField(controller: _phone, keyboardType: TextInputType.phone,
          decoration: InputDecoration(hintText: context.read<AppState>().user?.phone ?? '0712 345 678')),
    ]);
  }

  Future<void> _pickDate(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() => _availDate.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
  }

  Widget _photosStep(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final photos = (L['photos'] as List).cast<String>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Add 3–8 clear daylight photos. Renters trust photos of the gate, the door, the bathroom and the kitchen.',
          style: TextStyle(fontSize: 13, color: t.ink2, height: 1.5)),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
        itemCount: photos.length + (photos.length < 8 ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == photos.length) {
            return GestureDetector(
              onTap: _addPhotos,
              child: Container(
                decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.line, width: 1.4)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_a_photo_outlined, size: 24, color: t.pine),
                  const SizedBox(height: 5),
                  Text('Add photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.ink2)),
                ]),
              ),
            );
          }
          return Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.expand(
                child: i < (L['thumbs'] as List).length && ((L['thumbs'] as List)[i] as String).isNotEmpty
                    ? DataImg((L['thumbs'] as List)[i] as String, cachePx: 300, fit: BoxFit.cover)
                    : DataImg(photos[i], cachePx: 300, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () => _removePhoto(i),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                  child: const Icon(Icons.close, size: 13, color: Colors.white),
                ),
              ),
            ),
            if (i == 0)
              Positioned(
                left: 4, bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                ),
              ),
          ]);
        },
      ),
      const SizedBox(height: 10),
      Text('Photos are compressed on your phone before upload — posting works even on slow bundles.',
          style: TextStyle(fontSize: 12, color: t.ink3)),
    ]);
  }
}

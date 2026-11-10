// HuntInKE — Search. Exact port of the website's viewSearch():
// · filters: town chips (all Kenya towns), property type, price min/max, amenities, sort
// · THE FIX: typing a town's exact name IS a location search — "chuka" switches the
//   town filter and shows ALL its houses; it never ANDs with the saved town silently.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import 'listing.dart';

class SearchScreen extends StatefulWidget {
  final String? town; // arriving from a home chip = location search
  final String? q;    // arriving from the hero search box
  const SearchScreen({super.key, this.town, this.q});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _q = '';
  String _town = '';
  String _ptype = '';
  String _min = '';
  String _max = '';
  final Set<String> _amenities = {};
  String _sort = 'new';
  bool _filtersOpen = false;
  bool _loading = true;
  String _error = '';
  List<Listing> _items = [];
  final _qCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    if (widget.town != null && widget.town!.isNotEmpty) {
      _town = widget.town!;
      st.setMyTown(_town);
    } else if (widget.q != null && widget.q!.isNotEmpty) {
      _q = widget.q!;
      _qCtrl.text = _q;
    } else {
      // plain Search-tab tap: the saved town preselects (same rule as the web)
      _town = st.myTown;
    }
    _load();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  // typing a town's exact name IS a location search (web goSearch())
  void _goSearch() {
    final typed = _qCtrl.text.trim();
    final t = TOWNS.where((x) => x.n.toLowerCase() == typed.toLowerCase()).firstOrNull;
    if (t != null) {
      _town = t.n;
      _q = '';
      _qCtrl.clear();
      context.read<AppState>().setMyTown(t.n);
    } else {
      _q = typed;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final st = context.read<AppState>();
    try {
      final rows = await st.api.listings(
        q: _q, town: _town, ptype: _ptype,
        min: num.tryParse(_min), max: num.tryParse(_max),
        amenities: _amenities.isEmpty ? null : _amenities.join(','),
        sort: _sort == 'near' ? 'new' : _sort,
        bt: _town.isNotEmpty ? _town : st.myTown,
        limit: 100,
      );
      if (!mounted) return;
      var items = rows.map((j) => Listing.fromJson((j as Map).cast<String, dynamic>())).toList();
      if (_sort == 'near') {
        if (st.myLat == null) {
          snack(context, 'Allow location first — tap "Use my location" on the home page', error: true);
        } else {
          final out = <Listing>[];
          for (final l in items) {
            if (l.hasLocation) {
              final d = distMeters(st.myLat!, st.myLng!, l.lat!, l.lng!);
              if (!_dist.containsKey(l.id)) _dist[l.id] = d;
              out.add(l);
            }
          }
          out.sort((a, b) => _dist[a.id]!.compareTo(_dist[b.id]!));
          items = out;
        }
      }
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('ApiException: ', ''); _loading = false; });
    }
  }

  final Map<int, double> _dist = {};

  void _openListing(Listing l) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ListingScreen(l.id)));
  }

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final count = _items.length == 1 ? '1 house found' : '${_items.length} houses found';
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        titleSpacing: 14,
        title: const Text('Search'),
      ),
      body: Column(children: [
        // filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _qCtrl,
                onSubmitted: (_) => _goSearch(),
                style: const TextStyle(fontSize: 14.5),
                decoration: const InputDecoration(hintText: 'Search town, estate, tag…'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44), padding: EdgeInsets.zero,
                backgroundColor: _filtersOpen || _hasFilters ? t.mist : null,
              ),
              onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
              child: Stack(alignment: Alignment.center, children: [
                const Icon(Icons.tune, size: 20),
                if (_hasFilters)
                  Positioned(top: 8, right: 8, child: Container(width: 7, height: 7,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: C.ember))),
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44, width: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(50, 44), padding: EdgeInsets.zero),
                onPressed: _goSearch,
                child: const Icon(Icons.search, size: 20),
              ),
            ),
          ]),
        ),
        if (_filtersOpen) _filterPanel(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(children: [
            Text(_loading ? 'Searching…' : count,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.ink2)),
            const Spacer(),
            if (_hasFilters)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: () {
                  setState(() {
                    _town = ''; _ptype = ''; _min = ''; _max = ''; _amenities.clear(); _sort = 'new';
                  });
                  context.read<AppState>().setMyTown('');
                  _load();
                },
                child: const Text('Clear filters', style: TextStyle(fontSize: 12)),
              ),
          ]),
        ),
        Expanded(
          child: _loading
              ? ListView(physics: const NeverScrollableScrollPhysics(), children: const [
                  Padding(padding: EdgeInsets.all(16), child: Skel(h: 320)),
                ])
              : _error.isNotEmpty
                  ? ListView(children: [EmptyBox(Icons.wifi_off, 'Search failed', _error)])
                  : _items.isEmpty
                      ? ListView(children: const [
                          EmptyBox(Icons.search_off, 'Nothing matched',
                              'Try another town, a wider price range, or remove some filters.'),
                        ])
                      : RefreshIndicator(
                          color: C.ember,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
                            children: [
                              ListingGrid(_items, distances: _dist, onOpen: _openListing),
                            ],
                          ),
                        ),
        ),
      ]),
    );
  }

  bool get _hasFilters => _town.isNotEmpty || _ptype.isNotEmpty || _min.isNotEmpty || _max.isNotEmpty || _amenities.isNotEmpty;

  Widget _chipWrap(BuildContext context, List<String> labels, String selected, void Function(String) onTap,
      {String anyLabel = 'Any'}) {
    return Wrap(spacing: 7, runSpacing: 7, children: [
      _chip(context, anyLabel, selected.isEmpty, () => onTap('')),
      for (final l in labels) _chip(context, l, selected == l, () => onTap(l)),
    ]);
  }

  Widget _chip(BuildContext context, String label, bool on, VoidCallback onTap) {
    final t = T(Theme.of(context).brightness);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? t.pineBtn : t.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? t.pineBtn : t.line, width: 1.4),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? Colors.white : t.ink2)),
      ),
    );
  }

  Widget _filterPanel(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final label = (s) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: t.ink)),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        label('Town'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip(context, 'Anywhere in Kenya', _town.isEmpty, () { setState(() => _town = ''); context.read<AppState>().setMyTown(''); _load(); }),
            for (final tw in TOWNS)
              Padding(
                padding: const EdgeInsets.only(left: 7),
                child: _chip(context, tw.n, _town == tw.n, () {
                  setState(() => _town = tw.n);
                  context.read<AppState>().setMyTown(tw.n);
                  _load();
                }),
              ),
          ]),
        ),
        label('Property type'),
        _chipWrap(context, TYPES, _ptype, (v) { setState(() => _ptype = v); _load(); }),
        label('Price (KES)'),
        Row(children: [
          Expanded(child: TextField(
            keyboardType: TextInputType.number,
            onChanged: (v) => _min = v.trim(),
            onSubmitted: (_) => _load(),
            decoration: const InputDecoration(hintText: 'Min'),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            keyboardType: TextInputType.number,
            onChanged: (v) => _max = v.trim(),
            onSubmitted: (_) => _load(),
            decoration: const InputDecoration(hintText: 'Max'),
          )),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: _load,
            child: const Text('Go', style: TextStyle(fontSize: 13)),
          ),
        ]),
        label('Amenities'),
        for (final a in const [
          ('water', 'Water included'), ('wifi', 'WiFi included'),
          ('ensuite', 'Bathroom inside (self-contained)'), ('kitchen', 'Own kitchen'),
          ('parking', 'Parking'), ('guard', 'Security guard'), ('backup', 'Backup power'),
        ])
        InkWell(
          onTap: () {
            setState(() {
              _amenities.contains(a.$1) ? _amenities.remove(a.$1) : _amenities.add(a.$1);
            });
            _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(
                width: 20, height: 20,
                child: Checkbox(
                  value: _amenities.contains(a.$1),
                  onChanged: (v) {
                    setState(() {
                      v == true ? _amenities.add(a.$1) : _amenities.remove(a.$1);
                    });
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Text(a.$2, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: t.ink)),
            ]),
          ),
        ),
        label('Sort by'),
        SizedBox(
          height: 44,
          child: DropdownButtonFormField<String>(
            value: _sort,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
            dropdownColor: t.card,
            items: const [
              DropdownMenuItem(value: 'new', child: Text('Newest (boosted first)')),
              DropdownMenuItem(value: 'near', child: Text('Nearest to me')),
              DropdownMenuItem(value: 'priceAsc', child: Text('Price: low to high')),
              DropdownMenuItem(value: 'priceDesc', child: Text('Price: high to low')),
            ],
            onChanged: (v) { setState(() => _sort = v ?? 'new'); _load(); },
          ),
        ),
      ]),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

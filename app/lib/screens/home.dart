// HuntInKE — Home. Exact port of the website's viewHome(): green hero with search +
// town chips, "Houses near you" (GPS, 7 km rule), "Boosted in <town>", "Newest in Kenya",
// how-it-works and the never-pay safety notice.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data.dart';
import '../loc.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../screens/auth.dart';
import '../screens/mylistings.dart';
import '../util.dart';
import '../widgets.dart';
import 'listing.dart';
import 'search.dart';
import 'shell.dart' show shellTab;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String _error = '';
  List<Listing> _items = [];
  final Map<int, double> _dist = {};
  bool _askedGps = false;
  final _heroQ = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final st = context.read<AppState>();
    try {
      final rows = await st.api.listings(sort: 'new', bt: st.myTown, limit: 60);
      if (!mounted) return;
      final items = rows.map((j) => Listing.fromJson((j as Map).cast<String, dynamic>())).toList();
      _dist.clear();
      final pos = st.myLat != null && st.myLng != null;
      if (pos) {
        for (final l in items) {
          if (l.hasLocation) _dist[l.id] = distMeters(st.myLat!, st.myLng!, l.lat!, l.lng!);
        }
      }
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('ApiException: ', ''); _loading = false; });
    }
  }

  Future<void> _useMyLocation() async {
    snack(context, 'Getting your location…');
    final p = await huntinGetLocation(context);
    if (p == null || !mounted) return;
    final st = context.read<AppState>();
    await st.setMyPos(p.latitude, p.longitude);
    final near = nearestTown(p.latitude, p.longitude);
    if (near != null && distMeters(p.latitude, p.longitude, near.lat, near.lng) < 60000) {
      await st.setMyTown(near.n); // GPS says which town you are in
    }
    _askedGps = true;
    _load();
  }

  void _openSearch({String? town, String? q}) {
    if (town == null && (q == null || q.isEmpty)) {
      // empty tap on the magnifier: keep whatever is typed, default to plain search
      q = _heroQ.text.trim();
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(town: town, q: (q == null || q.isEmpty) ? null : q)));
  }

  void _openTab(int i) => shellTab.value = i;

  void _openListing(Listing l) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ListingScreen(l.id)))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final st = context.watch<AppState>();
    final myTown = st.myTown;
    // ONLY a recent fix counts for "Houses near you" — a position saved hours
    // ago (or an emulator's factory default point) made a hostel 200 m away
    // read as "no hostel around". Stale position => browse by town instead.
    final hasPos = st.posFresh();

    List<Listing> nearItems;
    if (hasPos) {
      nearItems = _items.where((l) => _dist[l.id] != null && _dist[l.id]! <= 7000).toList()
        ..sort((a, b) => _dist[a.id]!.compareTo(_dist[b.id]!));
    } else {
      nearItems = _items.where((l) => myTown.isNotEmpty && l.town == myTown).toList();
    }
    final boostedItems = _items.where((l) => l.boosted && (myTown.isEmpty || l.town == myTown)).toList();

    return Scaffold(
      backgroundColor: t.bg,
      // NOTE: the brand topbar (logo + wordmark + theme + sign in) lives in the
      // Shell, exactly like the website where one .topbar sits on every page.
      body: RefreshIndicator(
        color: C.ember,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 100),
          children: [
            _hero(context, myTown),
            const SizedBox(height: 22),
            _nearSection(context, myTown, hasPos, nearItems),
            if (boostedItems.isNotEmpty) ...[
              const SizedBox(height: 22),
              SectionHead('Boosted in ${myTown.isEmpty ? 'Kenya' : myTown}', icon: Icons.bolt),
              ListingGrid(boostedItems.take(4).toList(), onOpen: _openListing),
            ],
            const SizedBox(height: 22),
            SectionHead('Newest in Kenya', action: 'See all →', onAction: () => _openSearch()),
            if (_loading)
              const _SkelGrid()
            else if (_error.isNotEmpty)
              EmptyBox(Icons.wifi_off, 'Could not load listings', '$_error\nCheck your internet and pull down to refresh.')
            else if (_items.isEmpty)
              EmptyBox(Icons.home_work_outlined, 'No listings yet',
                  st.user?.isLandlord == true
                      ? 'Be the first! Post your vacant house — it takes 2 minutes.'
                      : 'Check back soon — landlords across Kenya are posting vacant houses every week.')
            else
              ListingGrid(_items.take(8).toList(), onOpen: _openListing),
            const SizedBox(height: 24),
            SectionHead('How HuntInKE works'),
            _steps(context),
            const SizedBox(height: 20),
            Notice(Icons.shield_outlined,
                'HuntInKE never collects rent. Any payment happens face-to-face with the landlord after a viewing. Report anything suspicious.',
                kind: 'g'),
            const SizedBox(height: 20),
            if (st.user == null) _ctaGuest(context) else if (st.user!.isLandlord) _ctaLandlord(context, st),
          ],
        ),
      ),
    );
  }

  // ---- hero ----
  Widget _hero(BuildContext context, String myTown) {
    final q = _heroQ;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [T(Theme.of(context).brightness).heroTop, T(Theme.of(context).brightness).heroBottom]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(children: [
        Positioned(right: -30, top: -30, child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06)))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Find a house anywhere in Kenya',
              style: TextStyle(fontFamily: kDisp, fontSize: 26, fontWeight: FontWeight.w800,
                  color: Colors.white, height: 1.15, letterSpacing: -.25)),
          const SizedBox(height: 8),
          Text('Bedsitters, apartments and family houses in every town — chat with the landlord directly, view first, pay later.',
              style: TextStyle(fontSize: 14, color: const Color(0xFFD8E8DD), height: 1.5)),
          const SizedBox(height: 15),
          Row(children: [
            Expanded(
              child: TextField(
                controller: q,
                onSubmitted: (v) => _openSearch(q: v.trim()),
                style: const TextStyle(fontSize: 14.5),
                // web .hero-search .inp{border:none} — plain white pill
                decoration: const InputDecoration(
                    hintText: 'Search town, estate, landmark…', filled: true,
                    border: InputBorder.none, enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44, width: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 44), padding: EdgeInsets.zero),
                onPressed: () => _openSearch(q: q.text.trim()),
                child: const Icon(Icons.search, size: 20),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7, runSpacing: 7,
            children: [
              // pixel port of web .hero-chips .chip / .chip.on
              for (final tw in towns.where((x) => x.big))
                GestureDetector(
                  onTap: () => _openSearch(town: tw.n),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: tw.n == myTown ? Colors.white : Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: tw.n == myTown ? Colors.white : Colors.white.withValues(alpha: .22),
                          width: 1.5),
                    ),
                    child: Text(tw.n, style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600,
                        color: tw.n == myTown ? C.pineDeep : const Color(0xFFEAF4EC))),
                  ),
                ),
            ],
          ),
        ]),
      ]),
    );
  }

  // ---- houses near you ----
  Widget _nearSection(BuildContext context, String myTown, bool hasPos, List<Listing> nearItems) {
    if (!hasPos && myTown.isEmpty && !_askedGps) {
      final t = T(Theme.of(context).brightness);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.line)),
        child: Column(children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on_outlined, size: 18, color: t.pine),
            const SizedBox(width: 6),
            Text('Houses around you', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: t.ink)),
          ]),
          const SizedBox(height: 6),
          Text('Allow location and HuntInKE shows vacant houses nearest to you first — in any town.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: t.ink3, height: 1.5)),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
            onPressed: _useMyLocation,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_on_outlined, size: 17),
              SizedBox(width: 6),
              Text('Use my location'),
            ]),
          ),
          const SizedBox(height: 9),
          Text('Prefer not to? Just pick your town on the green card above.',
              style: TextStyle(fontSize: 12, color: t.ink3)),
        ]),
      );
    }
    return Column(children: [
      SectionHead(hasPos ? 'Houses near you' : 'Houses in $myTown',
          icon: Icons.location_on_outlined,
          action: 'Open map →',
          onAction: () => _openTab(2)),
      if (_loading)
        const _SkelGrid()
      else if (nearItems.isEmpty)
        EmptyBox(Icons.location_on_outlined,
            hasPos ? 'No vacant houses within 7 km of you yet' : 'No houses in $myTown yet',
            hasPos
                ? 'Nothing pinned near your location so far. Try browsing ${myTown.isEmpty ? 'your town' : myTown} or search another town.'
                : 'Be the first — or search another town. New houses are posted every week.')
      else
        ListingGrid(nearItems.take(8).toList(),
            distances: _dist, onOpen: _openListing),
    ]);
  }

  Widget _steps(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final steps = [
      ('1', 'Search & compare', 'Real prices, real photos, exact map pins — in Nairobi, Mombasa, Nanyuki or any town in Kenya.'),
      ('2', 'Chat with the landlord', 'Message in the app or tap WhatsApp — agree on a viewing time. No agents, no middlemen.'),
      ('3', 'View first, pay later', 'Never send money before you have seen the house in person. That is the HuntInKE rule.'),
    ];
    return Column(children: [
      for (final s in steps)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 30, height: 30, alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.pine),
                child: Text(s.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.$2, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: t.ink)),
              const SizedBox(height: 3),
              Text(s.$3, style: TextStyle(fontSize: 12.8, color: t.ink2, height: 1.5)),
            ])),
          ]),
        ),
    ]);
  }

  Widget _ctaGuest(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: t.pineBtn, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Have a vacant house?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.5)),
        const SizedBox(height: 6),
        Text('Post it on HuntInKE and reach renters in every town in Kenya. First 2 listings are free.',
            style: TextStyle(fontSize: 13.2, color: const Color(0xFFD8E8DD), height: 1.5)),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.ember, minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
          child: const Text('List your property'),
        ),
      ]),
    );
  }

  Widget _ctaLandlord(BuildContext context, AppState st) {
    final t = T(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: t.pineBtn, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Get more renters to your houses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.5)),
        const SizedBox(height: 8),
        Text.rich(TextSpan(style: TextStyle(fontSize: 13, color: const Color(0xFFD8E8DD), height: 1.55), children: const [
          TextSpan(text: '1. Get verified', style: TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: ' — upload your ID and ownership proof in your Profile to earn the green badge and post up to 5 listings instead of 2.\n\n'),
          TextSpan(text: '2. Boost', style: TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: ' — KES $boostAmountKes pins a listing at the top of results in your town for $boostDays days.'),
        ])),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (st.user!.verifyStatus != 'APPROVED')
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.ember, minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 14)),
              onPressed: () => _openTab(4),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shield_outlined, size: 16), SizedBox(width: 6), Text('Get verified'),
              ]),
            ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38),
                minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen())),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.description_outlined, size: 16), SizedBox(width: 6), Text('My listings'),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _SkelGrid extends StatelessWidget {
  const _SkelGrid();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 620 ? 3 : 2;
      return GridView.count(
        crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.64,
        children: List.generate(cols * 2, (_) => const Skel()),
      );
    });
  }
}

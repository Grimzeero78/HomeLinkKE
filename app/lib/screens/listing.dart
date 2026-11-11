// HuntInKE — Listing detail. Exact port of the website's viewListing():
// gallery with count, price head + pills (Boosted / Verified / vacancy / views),
// Save · Share · Report, never-pay notice, key facts, search tags, mini map +
// Google Maps links, utilities, inside the unit, security & tenants, pricing,
// owner card (Call / WhatsApp / Message in app), similar houses.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import 'auth.dart';
import 'boost.dart';
import 'thread.dart';
import 'welcome.dart';

class ListingScreen extends StatefulWidget {
  final int id;
  const ListingScreen(this.id, {super.key});
  @override
  State<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends State<ListingScreen> {
  bool _loading = true;
  String _error = '';
  Listing? _l;
  List<Photo> _photos = [];
  List<Listing> _similar = [];
  bool _isOwner = false;
  bool _isFav = false;
  int _gal = 0;
  // Drives the big photo — WITHOUT a controller the arrows and thumbs changed
  // the counter but the photo never moved (the bug the user reported).
  final PageController _galCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _load();
    _pickTileSource();
  }

  // Same probe as the Map tab: if Google tiles hang or are blocked, the mini
  // map opens straight on CARTO Voyager instead of a blank square.
  Future<void> _pickTileSource() async {
    final ok = await tileSourceWorks('https://mt{s}.google.com/vt/lyrs=m&hl=en&x={x}&y={y}&z={z}&s=Ga');
    if (mounted && !ok) setState(() => _mapTilesFailed = true);
  }

  @override
  void dispose() {
    _galCtrl.dispose();
    super.dispose();
  }

  // one path for arrows AND thumbs: move the photo, then update the state
  void _goGal(int i) {
    if (_photos.isEmpty) return;
    final target = i % _photos.length;
    setState(() => _gal = target);
    _galCtrl.animateToPage(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  Future<void> _load() async {
    final st = context.read<AppState>();
    try {
      final r = await st.api.listing(widget.id);
      if (!mounted) return;
      final l = Listing.fromJson((r['listing'] as Map).cast<String, dynamic>());
      _l = l;
      _photos = ((r['photos'] ?? []) as List).map((p) => Photo.fromJson((p as Map).cast<String, dynamic>())).toList();
      _similar = ((r['similar'] ?? []) as List).map((j) => Listing.fromJson((j as Map).cast<String, dynamic>())).toList();
      _isOwner = r['isOwner'] == true;
      _isFav = false;
      // SHOW IT NOW. The old code waited on a second call (my favourites) before
      // rendering — that double wait is exactly the "listing opening delays" bug.
      setState(() => _loading = false);
      // favourites + view counter continue quietly in the background
      if (st.user != null) {
        st.api.myFavorites().then((f) {
          if (!mounted) return;
          setState(() => _isFav = f.any((x) => ((x as Map)['id'] as num?)?.toInt() == l.id));
        }).catchError((_) {});
      }
      st.api.view(l.id); // view counter (server dedupes per visitor)
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('ApiException: ', ''); _loading = false; });
    }
  }

  Future<void> _toggleFav() async {
    final st = context.read<AppState>();
    if (st.user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }
    try {
      final on = await st.api.toggleFavorite(_l!.id);
      setState(() => _isFav = on);
      if (mounted) snack(context, on ? 'Saved to favourites' : 'Removed from favourites');
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
    }
  }

  void _share() {
    final url = '$kWebBase/#/listing/${_l!.id}';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Share this listing'),
      content: SelectableText(url),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton(
          onPressed: () async {
            try { await launchUrl(Uri.parse('mailto:?subject=${Uri.encodeComponent(_l!.title)}&body=${Uri.encodeComponent(url)}')); } catch (_) {}
          },
          child: const Text('Share'),
        ),
      ],
    ));
  }

  Future<void> _report() async {
    final st = context.read<AppState>();
    if (st.user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }
    String? reason = reportReasons.first;
    final note = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setM) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Report this listing', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: reason,
            items: [for (final r in reportReasons) DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13.5)))],
            onChanged: (v) => setM(() => reason = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Details (optional) — tell us what is wrong…'),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Send report'))),
        ])),
      ),
    );
    if (ok != true) return;
    try {
      await st.api.report(_l!.id, reason ?? 'Other', note.text.trim());
      if (mounted) snack(context, 'Report sent. Our team will review it.');
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
    }
  }

  Future<void> _messageInApp() async {
    final st = context.read<AppState>();
    if (st.user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }
    try {
      final id = await st.api.openConv(_l!.id);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ThreadScreen(id)));
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
    }
  }

  void _openGuide() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    if (_loading) {
      return Scaffold(backgroundColor: t.bg, appBar: AppBar(), body: ListView(padding: const EdgeInsets.all(14), children: const [
        Skel(h: 260), SizedBox(height: 14), Skel(h: 26, w: 220, r: 8), SizedBox(height: 10), Skel(h: 120),
      ]));
    }
    if (_error.isNotEmpty || _l == null) {
      return Scaffold(backgroundColor: t.bg, appBar: AppBar(), body: ListView(children: [
        EmptyBox(Icons.search_off, 'Listing not found', _error.isEmpty ? 'It may have been removed.' : _error),
        // the 40-second dead spinner used to be the whole experience on a weak
        // network — now every failure has an explicit way back in
        Center(child: OutlinedButton.icon(
          onPressed: () { setState(() { _error = ''; _loading = true; }); _load(); },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Try again'),
        )),
      ]));
    }
    final l = _l!;
    final st = context.watch<AppState>();
    final verified = l.ownerVerified;
    final canContact = st.user != null;
    final contactNum = (l.raw['contactPhone'] ?? '').toString().isNotEmpty
        ? (l.raw['contactPhone'] ?? '').toString()
        : (l.raw['ownerPhone'] ?? '').toString();
    final dist = (st.myLat != null && l.hasLocation)
        ? '${fmtDist(distMeters(st.myLat!, st.myLng!, l.lat!, l.lng!))} away' : '';

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Listing')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
        children: [
          if (_isOwner && !l.boosted)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoostScreen(l.id)))
                    .then((_) => _load()),
                child: Notice(Icons.bolt, '', kind: 'o', richChild: Text.rich(TextSpan(
                  style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600, color: C.emberDeep, height: 1.5),
                  children: [
                    const TextSpan(text: 'This is your listing. ', style: TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: 'Get seen first in ${l.town.isEmpty ? 'your town' : l.town} — '),
                    TextSpan(text: 'Boost it for KES $boostAmountKes / $boostDays days', style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w800)),
                    TextSpan(text: '. Renters browsing ${l.town.isEmpty ? 'your town' : l.town} will see it on top.'),
                  ])),
                ),
              ),
            ),
          if (_isOwner && !verified)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Notice(Icons.shield_outlined, '', kind: 'g', richChild: Text.rich(TextSpan(
                style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600, color: t.pineInk, height: 1.5),
                children: const [
                  TextSpan(text: 'Earn the green ', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: 'Verified landlord ', style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: 'badge and post up to 5 listings — '),
                  TextSpan(text: 'verify in your Profile', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w800)),
                  TextSpan(text: '.'),
                ])),
              ),
            ),
          if (_photos.isNotEmpty) ...[
            _gallery(context),
            const SizedBox(height: 10),
          ],
          _head(context, l, dist, verified),
          const SizedBox(height: 14),
          _ownerCard(context, l, canContact, contactNum),
          const SizedBox(height: 2),
          _block(context, 'Key facts', _keyFacts(context, l)),
          if ((l.raw['tags'] ?? '').toString().trim().isNotEmpty)
            _block(context, 'Search tags', Wrap(spacing: 7, runSpacing: 7,
                children: [for (final tg in (l.raw['tags'] as String).split(',').map((x) => x.trim()).where((x) => x.isNotEmpty))
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.line)),
                    child: Text(tg, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: t.ink2)))])),
          _block(context, 'Location', _location(context, l)),
          _block(context, 'Utilities', _utilities(context, l)),
          _block(context, 'Inside the unit', _inside(context, l)),
          _block(context, 'Security & tenants', _security(context, l)),
          _block(context, 'Pricing & terms', _pricing(context, l)),
          if (_similar.isNotEmpty) ...[
            const SizedBox(height: 22),
            SectionHead('Similar houses'),
            SizedBox(
              height: 300,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _similar.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => SizedBox(
                  width: 240,
                  child: ListingCard(_similar[i], onOpen: () =>
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ListingScreen(_similar[i].id)))),
                ),
              ),
            ),
          ],
          if (st.user?.isAdmin == true) ...[
            const SizedBox(height: 16),
            Center(child: TextButton(onPressed: _openGuide, child: const Text('Open getting-started guide'))),
          ],
        ],
      ),
    );
  }

  // ---- gallery: web .gallery + .gal-nav + .gal-count + .gal-thumbs ----
  // Side arrows (the buttons the user asked for), count pill bottom-right,
  // thumbs row with a pine border on the active one, tap photo = lightbox.
  Widget _gallery(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(children: [
            PageView.builder(
              controller: _galCtrl,
              itemCount: _photos.length,
              onPageChanged: (i) => setState(() => _gal = i),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _lightbox(context, i),
                child: DataImg(_photos[i].url, cachePx: 800, fit: BoxFit.cover,
                    placeholder: Container(color: t.galBg)),
              ),
            ),
            if (_photos.length > 1) ...[
              // web .gal-nav: 38px white circles, left/right 10
              Positioned(left: 10, top: 0, bottom: 0, child: Center(
                child: _galNav(context, Icons.arrow_back_ios_new_rounded, true),
              )),
              Positioned(right: 10, top: 0, bottom: 0, child: Center(
                child: _galNav(context, Icons.arrow_back_ios_new_rounded, false),
              )),
              // invisible left/right halves of the photo let you swipe too —
              // the whole photo area is a PageView so both drag and buttons work
              // web .gal-count: right 10, bottom 10
              Positioned(
                right: 10, bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xB80A1E12), borderRadius: BorderRadius.circular(99)),
                  child: Text('${_gal + 1}/${_photos.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ]),
        ),
      ),
      // web .gal-thumbs: 62x48 thumbs, radius 9, 2px pine border when active
      if (_photos.length > 1)
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: 8),
            itemCount: _photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _goGal(i),
              child: Container(
                key: ValueKey('thumb$i'),
                width: 62, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: i == _gal ? t.pine : Colors.transparent, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: DataImg(_photos[i].url, cachePx: 124, fit: BoxFit.cover,
                      placeholder: Container(color: t.galBg)),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _galNav(BuildContext context, IconData icon, bool back) {
    return GestureDetector(
      onTap: () => _goGal(_gal + (back ? -1 : 1)),
      child: Container(
        width: 38, height: 38,
        decoration: const BoxDecoration(
          color: Color(0xEBFFFFFF),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: C.ink,
            textDirection: back ? TextDirection.ltr : TextDirection.rtl),
      ),
    );
  }

  void _lightbox(BuildContext context, int i) {
    showDialog(context: context, barrierColor: Colors.black87, builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: Scaffold(backgroundColor: Colors.transparent, body: Center(
        child: DataImg(_photos[i].url, cachePx: 1600, fit: BoxFit.contain),
      )),
    ));
  }

  // ---- head: price, title, pills, actions ----
  Widget _head(BuildContext context, Listing l, String dist, bool verified) {
    final t = T(Theme.of(context).brightness);
    final period = l.period.startsWith('Per Month') ? 'month' : 'semester';
    final loc = [l.town.isEmpty ? 'Kenya' : l.town, if (l.area.isNotEmpty) l.area, if (l.landmark.isNotEmpty) l.landmark].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: kes(l.rent), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: t.pineInk, letterSpacing: -.5)),
        TextSpan(text: ' /$period', style: TextStyle(fontSize: 13, color: t.ink3, fontWeight: FontWeight.w600)),
      ])),
      const SizedBox(height: 3),
      Text(l.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: t.ink, height: 1.2)),
      const SizedBox(height: 5),
      Row(children: [
        Icon(Icons.location_on_outlined, size: 14, color: t.ink2),
        const SizedBox(width: 4),
        Expanded(child: Text(dist.isEmpty ? loc : '$loc · $dist',
            style: TextStyle(fontSize: 13, color: t.ink2))),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 7, runSpacing: 7, children: [
        _pill(context, Icons.bolt, 'Boosted', bg: t.emberMist, fg: C.emberDeep, show: l.boosted),
        _pill(context, Icons.shield_outlined, 'Verified landlord', bg: t.mist, fg: t.pineInk, show: verified),
        VacBadge(l, small: true),
        _pill(context, Icons.visibility_outlined, '${l.views} views', bg: t.soft, fg: t.ink2, show: true),
      ].whereType<Widget>().toList()),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), textStyle: const TextStyle(fontSize: 13)),
          onPressed: _toggleFav,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_isFav ? Icons.favorite : Icons.favorite_border, size: 16, color: _isFav ? C.bad : null),
            const SizedBox(width: 6), Text(_isFav ? 'Saved' : 'Save'),
          ]),
        )),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), textStyle: const TextStyle(fontSize: 13)),
          onPressed: _share,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.share_outlined, size: 16), SizedBox(width: 6), Text('Share'),
          ]),
        )),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), textStyle: const TextStyle(fontSize: 13)),
          onPressed: _report,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.flag_outlined, size: 16), SizedBox(width: 6), Text('Report'),
          ]),
        )),
      ]),
      if (!_isOwner) ...[
        const SizedBox(height: 12),
        Notice(Icons.shield_outlined, '', kind: 'r', richChild: Text.rich(TextSpan(
          style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600, color: C.bad, height: 1.5),
          children: const [
            TextSpan(text: 'Never pay before viewing. ', style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: 'Visit the house and meet the landlord or caretaker in person before sending any deposit — M-Pesa or cash.'),
          ])),
        ),
      ],
      if (l.full && !_isOwner) ...[
        const SizedBox(height: 10),
        Notice(Icons.cancel_outlined,
            'All units here are occupied right now. Save this listing or message the landlord — be first in line when a unit opens.',
            kind: 'o'),
      ],
    ]);
  }

  // ---- owner card (web .owner-card): avatar, verified, Call / WhatsApp / Message ----
  Widget _ownerCard(BuildContext context, Listing l, bool canContact, String contactNum) {
    final t = T(Theme.of(context).brightness);
    final ownerName = ((l.raw['ownerName'] ?? l.raw['ownerUsername'] ?? '?') as String);
    final verified = l.ownerVerified;
    void needAuth() {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
    void call() async {
      if (contactNum.isEmpty) { snack(context, 'This landlord has not added a phone number yet', error: true); return; }
      final n = contactNum.replaceAll(RegExp(r'[\s+-]'), '');
      final tel = n.startsWith('0') ? '254${n.substring(1)}' : n;
      try { await launchUrl(Uri.parse('tel:+$tel')); } catch (_) { snack(context, 'Could not open the dialer', error: true); }
    }
    void whatsapp() async {
      if (contactNum.isEmpty) { snack(context, 'This landlord has not added a WhatsApp number yet', error: true); return; }
      final link = waLink(contactNum, 'Hi! I saw your listing "${l.title}" on HuntInKE. Is it still available?');
      try { await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication); } catch (_) { snack(context, 'Could not open WhatsApp', error: true); }
    }
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
      child: Column(children: [
        Row(children: [
          Avatar(ownerName, verified: verified),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(ownerName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: t.ink))),
              if (verified) ...[const SizedBox(width: 5), Icon(Icons.verified_user_outlined, size: 15, color: t.pine)],
            ]),
            const SizedBox(height: 2),
            Text('Landlord · joined ${fmtDate((l.raw['ownerSince'] as num?)?.toInt())}',
                style: TextStyle(fontSize: 11.5, color: t.ink3)),
          ])),
        ]),
        if (!verified) ...[
          const SizedBox(height: 11),
          Notice(Icons.flag_outlined,
              'This landlord is not verified yet. Always view the room in person before paying anything.', kind: 'o'),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44), textStyle: const TextStyle(fontSize: 13.5)),
            onPressed: canContact ? call : needAuth,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.call_outlined, size: 17), SizedBox(width: 6), Text('Call'),
            ]),
          )),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44), textStyle: const TextStyle(fontSize: 13.5)),
            onPressed: canContact ? whatsapp : needAuth,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chat_outlined, size: 17), SizedBox(width: 6), Text('WhatsApp'),
            ]),
          )),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), textStyle: const TextStyle(fontSize: 13.5)),
            onPressed: canContact ? _messageInApp : needAuth,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chat_bubble_outline, size: 17), SizedBox(width: 6), Text('Message in app'),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.shield_outlined, size: 13, color: t.ink3),
          const SizedBox(width: 5),
          Expanded(child: Text('Never send a deposit before viewing the room in person.',
              style: TextStyle(fontSize: 12, color: t.ink3))),
        ]),
      ]),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label, {required Color bg, required Color fg, required bool show}) {
    if (!show) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: fg),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
      ]),
    );
  }

  Widget _block(BuildContext context, String title, Widget child) {
    final t = T(Theme.of(context).brightness);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: t.ink)),
        const SizedBox(height: 9),
        child,
      ]),
    );
  }

  Widget _keyFacts(BuildContext context, Listing l) {
    final vac = l.full ? 'All occupied now' : (l.vacantCount == 1 ? '1 house is vacant' : '${l.vacantCount} houses are vacant');
    final cells = [
      ('Type', l.ptype),
      ('Vacant now', vac),
      ('Furnishing', l.furnishing),
      ('Building floors', floorLabel(l.floor)),
      ('Road access', l.road),
      ('Available from', fmtAvail((l.raw['availableFrom'] ?? '').toString())),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 480 ? 3 : 2;
      return Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          for (final cell in cells)
            SizedBox(
              width: (c.maxWidth - (cols - 1) * 8) / cols,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: T(Theme.of(context).brightness).card2, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cell.$1, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: T(Theme.of(context).brightness).ink3)),
                  const SizedBox(height: 3),
                  Text(cell.$2, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: T(Theme.of(context).brightness).ink)),
                ]),
              ),
            ),
        ],
      );
    });
  }

  Widget _location(BuildContext context, Listing l) {
    final t = T(Theme.of(context).brightness);
    if (!l.hasLocation) {
      return Text('The landlord has not pinned this property on the map yet. Ask for directions in the chat.',
          style: TextStyle(fontSize: 13, color: t.ink2, height: 1.5));
    }
    // Same tile sources as the website (maps.js): Google roads first, silent
    // swap to CARTO Voyager if tiles keep failing.
    const tileGoogle = 'https://mt{s}.google.com/vt/lyrs=m&hl=en&x={x}&y={y}&z={z}&s=Ga';
    const tileCarto = 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
    final carto = _mapTilesFailed;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 220,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: ll.LatLng(l.lat!, l.lng!),
              initialZoom: 17,
              // THE WEBSITE FIX: an embedded map never hijacks the page scroll
              // (maps.js mode 'page' — phone swipes scroll the page). So here:
              // pinch + double-tap zoom ONLY, no one-finger drag.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
              ),
              onTap: (_, __) => _pinPopup(context, l),
            ),
            children: [
              TileLayer(
                urlTemplate: carto ? tileCarto : tileGoogle,
                subdomains: carto ? const ['a', 'b', 'c', 'd'] : const ['0', '1', '2', '3'],
                maxNativeZoom: 20,
                userAgentPackageName: 'com.huntin.ke',
                errorTileCallback: (_, __, ___) {
                  if (!carto && mounted && !_mapTilesFailed) {
                    _tileErrs++;
                    if (_tileErrs >= 8) setState(() => _mapTilesFailed = true);
                  }
                },
              ),
              MarkerLayer(markers: [
                Marker(
                  point: ll.LatLng(l.lat!, l.lng!), width: 34, height: 30,
                  alignment: Alignment.bottomCenter, // tip of the pin touches the spot
                  child: GestureDetector(onTap: () => _pinPopup(context, l), child: const _RedPin()),
                ),
              ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text('Pinch to zoom the map. Scrolling the page never moves the map — same as the website.',
          style: TextStyle(fontSize: 12, color: t.ink3)),
      const SizedBox(height: 9),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), textStyle: const TextStyle(fontSize: 12.5)),
          onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${l.lat},${l.lng}'), mode: LaunchMode.externalApplication),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on_outlined, size: 15), SizedBox(width: 5), Text('Open in Google Maps'),
          ]),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), textStyle: const TextStyle(fontSize: 12.5)),
          onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${l.lat},${l.lng}'), mode: LaunchMode.externalApplication),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.directions_outlined, size: 15), SizedBox(width: 5), Text('Directions'),
          ]),
        ),
      ]),
    ]);
  }

  int _tileErrs = 0;
  bool _mapTilesFailed = false;

  // web: the listing pin carries a popup with the house name + area
  void _pinPopup(BuildContext context, Listing l) {
    final t = T(Theme.of(context).brightness);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: t.ink)),
          const SizedBox(height: 4),
          Text([l.town, if (l.area.isNotEmpty) l.area, if (l.landmark.isNotEmpty) l.landmark].join(' · '),
              style: TextStyle(fontSize: 13, color: t.ink2)),
        ]),
      ),
    );
  }

  String? _y(String? v) => (v == null || v.isEmpty) ? null : v;

  Widget _utilities(BuildContext context, Listing l) {
    final r = l.raw;
    final water = (r['water'] ?? '').toString();
    final waterTxt = water + (water != 'Included in rent' && (r['waterCost'] ?? '').toString().isNotEmpty ? ' · ${r['waterCost']}' : '');
    final elec = (r['elec'] ?? '').toString();
    final elecTxt = elec + ((r['elecCost'] ?? '').toString().isNotEmpty && !['Included in rent', 'Own token meter', 'Prepaid'].contains(elec) ? ' · ${r['elecCost']}' : '');
    final wifi = (r['wifi'] ?? '').toString();
    final wifiTxt = wifi + ((r['wifiCost'] ?? '').toString().isNotEmpty && wifi == 'Available but paid separately' ? ' · ${r['wifiCost']}' : '') + ((r['wifiProvider'] ?? '').toString().isNotEmpty ? ' (${r['wifiProvider']})' : '');
    final rows = <String, String>{
      'Water': waterTxt,
      if (water == 'Rationed' && (r['waterSched'] ?? '').toString().isNotEmpty) 'Water schedule': (r['waterSched'] ?? '').toString(),
      'Storage tank': _y((r['waterTank'] ?? '').toString()) ?? '—',
      'Electricity': elecTxt,
      'WiFi': wifiTxt,
      'Garbage': (r['garbage'] ?? '').toString(),
      'Backup power': (r['backup'] ?? '').toString(),
    };
    return Column(children: [for (final e in rows.entries) Kv(e.key, e.value)]);
  }

  Widget _inside(BuildContext context, Listing l) {
    final r = l.raw;
    final rows = <String, String>{
      if (RegExp(r'^\d').hasMatch((r['bath'] ?? '').toString())) 'Bathrooms': (r['bath'] ?? '').toString(),
      if (r['ensuite'] == 'Yes' || r['bath'] == 'Ensuite (own)') 'Bathroom inside': 'Yes — self-contained',
      if (r['kitchen'] == 'Yes' || r['kitchen'] == 'Own') 'Own kitchen': 'Yes, inside the unit',
      if (r['parking'] == 'Yes') 'Parking': 'Available',
      'Balcony': _y((r['balcony'] ?? '').toString()) ?? '—',
      'Floor finish': _y((r['tile'] ?? '').toString()) ?? '—',
      'Ceiling': _y((r['ceiling'] ?? '').toString()) ?? '—',
      if (r['wardrobe'] == 'Yes') 'Wardrobes': 'Built-in',
      'Hot shower': _y((r['hotShower'] ?? '').toString()) ?? '—',
    };
    return Column(children: [for (final e in rows.entries) Kv(e.key, e.value)]);
  }

  Widget _security(BuildContext context, Listing l) {
    final t = T(Theme.of(context).brightness);
    final sec = parseSecurity((l.raw['security'] ?? '[]').toString());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 7, runSpacing: 7, children: [
        for (final s in (sec.isEmpty ? ['Not specified'] : sec))
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.line)),
            child: Text(s, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: t.ink2))),
      ]),
      const SizedBox(height: 8),
      Kv('Preferred tenants', ((l.raw['tenantPref'] ?? 'Anyone') as String)),
      Kv('Pets', _y((l.raw['pets'] ?? '').toString()) ?? '—'),
    ]);
  }

  Widget _pricing(BuildContext context, Listing l) {
    final t = T(Theme.of(context).brightness);
    final r = l.raw;
    final rows = <String, String>{
      'Rent': '${kes(l.rent)} / ${(l.period).toLowerCase()}',
      if (l.deposit > 0) 'Deposit': kes(l.deposit),
      'Move-in fees': ((r['fees'] ?? 'None') as String).isEmpty ? 'None' : (r['fees'] ?? 'None'),
      'Negotiable': (r['negotiable'] == 1 || r['negotiable'] == true || r['negotiable'] == 'Yes') ? 'Yes' : 'No',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final e in rows.entries) Kv(e.key, e.value),
      if (((r['terms'] ?? '') as String).isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text((r['terms'] ?? '').toString(), style: TextStyle(fontSize: 13.2, color: t.ink2, height: 1.55)),
        ),
    ]);
  }
}

// web .gpin — the exact red teardrop the website drops on a pinned house:
// 24px #E94335 circle with one sharp corner, 2.5px white border, 9px white
// centre dot, rotated -45° so the tip points down at the exact spot.
class _RedPin extends StatelessWidget {
  const _RedPin();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34, height: 30,
      child: Stack(children: [
        Positioned(
          left: 5, top: 0,
          child: Transform.rotate(
            angle: -math.pi / 4, // same -45° as the website's .gpin
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFE94335),
                border: Border.all(color: Colors.white, width: 2.5),
                // three round corners + a sharp bottom-left (web border-radius
                // 50% 50% 50% 0); after the -45° rotation the sharp corner
                // points straight down at the spot.
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 3))],
              ),
              child: Center(
                child: Container(width: 9, height: 9,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

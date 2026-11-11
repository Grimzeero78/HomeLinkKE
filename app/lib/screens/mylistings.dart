// HuntInKE — My listings (exact port of viewMyListings()): rows with photo, vacancy
// stepper (−1 / +1 / All taken / Reopen — every tap saves instantly), View / Edit /
// Boost / Delete. Free plan vs verified limits are shown in the notices.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import 'boost.dart';
import 'create.dart';
import 'listing.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});
  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  bool _loading = true;
  String _error = '';
  List<Listing> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final st = context.read<AppState>();
    try {
      final rows = await st.api.myListings();
      if (!mounted) return;
      setState(() {
        _items = rows
            .map((j) => Listing.fromJson((j as Map).cast<String, dynamic>()))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('ApiException: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _setVacant(Listing l, int v) async {
    final st = context.read<AppState>();
    try {
      final r = await st.api.setStatus(l.id, v);
      final nv = (r['unitsVacant'] as num?)?.toInt() ?? v;
      if (mounted) {
        snack(context, nv > 0 ? 'Saved — $nv vacant' : 'Saved — all occupied');
      }
      _load();
    } catch (e) {
      if (mounted) {
        snack(context, e.toString().replaceFirst('ApiException: ', ''),
            error: true);
      }
    }
  }

  Future<void> _delete(Listing l) async {
    final ok = await confirmDlg(context, 'Delete this listing?',
        'It will be removed from HuntInKE. You cannot undo this.', 'Delete',
        danger: true);
    if (!ok) return;
    try {
      await context.read<AppState>().api.deleteListing(l.id);
      if (mounted) snack(context, 'Listing deleted');
      _load();
    } catch (e) {
      if (mounted) {
        snack(context, e.toString().replaceFirst('ApiException: ', ''),
            error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final st = context.watch<AppState>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('My listings')),
      body: RefreshIndicator(
        color: C.ember,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
          children: [
            Notice(
                Icons.shield_outlined,
                st.user?.verified == true
                    ? 'Verified account: up to 5 listings.'
                    : 'Free plan: 2 listings. Get verified in your Profile to post up to 5.',
                kind: 'g'),
            const SizedBox(height: 10),
            Notice(Icons.bolt, '',
                kind: 'o',
                richChild: Text.rich(TextSpan(
                    style: TextStyle(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w600,
                        color: C.emberDeep,
                        height: 1.5),
                    children: const [
                      TextSpan(
                          text: 'Boost gets you seen: ',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(
                          text:
                              'KES $boostAmountKes pins a listing at the top of results in its town for $boostDays days — renters browsing that town see it first. Tap Boost on any listing below.'),
                    ]))),
            const SizedBox(height: 14),
            if (_loading) ...[
              const Skel(h: 150),
              const SizedBox(height: 10),
              const Skel(h: 150)
            ] else if (_error.isNotEmpty)
              EmptyBox(Icons.wifi_off, 'Could not load', _error)
            else if (_items.isEmpty)
              EmptyBox(Icons.home_work_outlined, 'No listings yet',
                  'Post your first vacant room — it takes about 2 minutes.')
            else
              for (final l in _items) ...[
                _row(context, l),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 4),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CreateScreen()))
                        .then((_) => _load()),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 6),
                      Text('Post a new listing'),
                    ]))),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Listing l) {
    final t = T(Theme.of(context).brightness);
    final boosted = l.boosted;
    final v = l.vacantCount;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line)),
      child: Column(children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: l.thumb.isNotEmpty
                  ? DataImg(l.thumb,
                      cachePx: 128,
                      fit: BoxFit.cover,
                      placeholder: Container(color: t.galBg))
                  : Container(
                      color: t.galBg,
                      child:
                          Icon(Icons.photo_outlined, size: 22, color: t.ink3)),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(l.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: t.ink)),
                const SizedBox(height: 2),
                Text(
                    '${kes(l.rent)}/${perShort(l.period)} · ${l.town}${l.area.isNotEmpty ? ' · ${l.area}' : ''} · ${l.views} views',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.ink2)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  VacBadge(l, small: true),
                  if (boosted)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: t.emberMist,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('Boosted till ${fmtDate(l.boostedUntil)}',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: C.emberDeep))),
                ]),
              ])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _act(
              context,
              Icons.visibility_outlined,
              'View',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ListingScreen(l.id, initialListing: l)))),
          const SizedBox(width: 6),
          _act(
              context,
              Icons.edit_outlined,
              'Edit',
              () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CreateScreen(editId: l.id)))
                  .then((_) => _load())),
          const SizedBox(width: 6),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(fontSize: 12.5)),
              onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => BoostScreen(l.id)))
                  .then((_) => _load()),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.bolt, size: 15),
                SizedBox(width: 4),
                Flexible(child: Text('Boost', overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          _act(context, Icons.delete_outline, '', () => _delete(l),
              danger: true),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.only(top: 9),
          decoration:
              BoxDecoration(border: Border(top: BorderSide(color: t.line))),
          child: Row(children: [
            Text('VACANCY',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: t.ink3,
                    letterSpacing: .5)),
            const Spacer(),
            _vacBtn(context, '−1', v > 0 ? () => _setVacant(l, v - 1) : null),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Text(
                  l.full
                      ? 'All occupied'
                      : '$v ${v == 1 ? 'house' : 'houses'} vacant',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: t.pineInk)),
            ),
            _vacBtn(context, '+1', v >= 50 ? null : () => _setVacant(l, v + 1)),
            const SizedBox(width: 6),
            _vacBtn(
                context,
                l.full ? 'Reopen' : 'All taken',
                () => _setVacant(
                    l, l.full ? (l.totalUnits < 1 ? 1 : l.totalUnits) : 0)),
          ]),
        ),
      ]),
    );
  }

  Widget _act(
      BuildContext context, IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: label.isEmpty ? const Size(44, 38) : const Size(0, 38),
        padding: label.isEmpty
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: danger ? C.bad : null,
        textStyle: const TextStyle(fontSize: 12.5),
      ),
      onPressed: onTap,
      child: label.isEmpty
          ? Icon(icon, size: 17)
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15),
              const SizedBox(width: 4),
              Text(label)
            ]),
    );
  }

  Widget _vacBtn(BuildContext context, String label, VoidCallback? onTap) {
    final t = T(Theme.of(context).brightness);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: onTap == null ? t.soft : t.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: onTap == null ? t.line : t.ink3.withValues(alpha: .4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: onTap == null ? t.ink3 : t.ink)),
      ),
    );
  }
}

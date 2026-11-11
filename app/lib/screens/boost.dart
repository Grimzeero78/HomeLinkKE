// HuntInKE — Boost payment page (exact port of viewBoost()): what a boost does,
// 3 payment steps with the live paybill details from /settings, M-Pesa code or
// sender name, "I have sent the money". Town-targeted: the boost only lifts the
// listing for renters browsing the listing's own town.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data.dart';
import '../models.dart';
import '../notifs.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';

class BoostScreen extends StatefulWidget {
  final int id;
  const BoostScreen(this.id, {super.key});
  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen> {
  bool _loading = true;
  String _error = '';
  Listing? _l;
  bool _pending = false;
  final _code = TextEditingController(), _name = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final st = context.read<AppState>();
    setState(() { _loading = true; _error = ''; });
    try {
      final r = await st.api.listing(widget.id);
      if (!mounted) return;
      _l = Listing.fromJson((r['listing'] as Map).cast<String, dynamic>());
      final isOwner = r['isOwner'] == true;
      if (!isOwner) {
        setState(() { _error = 'Only the owner can boost this listing.'; _loading = false; });
        return;
      }
      try {
        final mine = await st.api.myBoosts();
        _pending = mine.any((b) =>
            ((b as Map)['listingId'] as num?)?.toInt() == widget.id && b['status'] == 'PENDING');
      } catch (_) {}
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('ApiException: ', ''); _loading = false; });
    }
  }

  Future<void> _submit() async {
    final code = _code.text.trim().toUpperCase();
    final sname = _name.text.trim();
    if (code.isEmpty && sname.isEmpty) {
      snack(context, 'Add the M-Pesa code or the name you sent from — the admin needs one to find your payment', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().api.boost(widget.id, code, sname);
      if (!mounted) return;
      snack(context, 'Sent! The admin will confirm your payment shortly.');
      Notifs.showAccount('Boost requested',
          'Your KES $BOOST_AMOUNT_KES boost request is waiting for admin confirmation.');
      _load();
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final st = context.watch<AppState>();
    if (_loading) {
      return Scaffold(backgroundColor: t.bg, appBar: AppBar(), body: ListView(padding: const EdgeInsets.all(14), children: const [Skel(h: 300)]));
    }
    if (_error.isNotEmpty || _l == null) {
      return Scaffold(backgroundColor: t.bg, appBar: AppBar(), body: ListView(children: [
        EmptyBox(Icons.bolt, 'Listing not found', _error),
      ]));
    }
    final l = _l!;
    final boosted = l.boosted;
    final town = l.town.isEmpty ? 'its town' : l.town;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: Text('Boost "${l.title}"', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (boosted)
            Notice(Icons.check_circle_outline, '', kind: 'g', richChild: Text.rich(TextSpan(
              style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600, color: t.pineInk, height: 1.5),
              children: [
                const TextSpan(text: 'This listing is boosted until ', style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: fmtDate(l.boostedUntil), style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: ' — renters browsing $town see it at the top.'),
              ]))),
          if (_pending)
            Notice(Icons.hourglass_top, 'Payment received — waiting for the admin to confirm your M-Pesa payment. Your boost starts right after confirmation.', kind: 'o'),
          if (!boosted && !_pending) ...[
            _block(context, 'What a boost does', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your listing jumps to the top of results in $town with an orange BOOSTED badge for $BOOST_DAYS days — on the home page, search results and the map for everyone browsing $town. Renters in other towns are not affected unless they search $town themselves. Boosted listings get the most views and chats.',
                  style: TextStyle(fontSize: 13, color: t.ink2, height: 1.55)),
            ])),
            const SizedBox(height: 12),
            _block(context, 'How to pay (KES $BOOST_AMOUNT_KES / $BOOST_DAYS days)', Column(children: [
              _payStep(context, '1', 'Open M-Pesa', 'Go to Send Money (Pochi / Send to mobile).'),
              _payStep(context, '2', 'Send KES $BOOST_AMOUNT_KES', "To number ${st.paybillNumber} — ${st.paybillName}."),
              _payStep(context, '3', 'Confirm below', 'Enter the M-Pesa confirmation code or the name you sent from, then tap "I have sent the money". The admin will activate your boost.'),
            ])),
            const SizedBox(height: 14),
            _plabel(context, 'M-Pesa confirmation code (fastest — copy it from the SMS)'),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'e.g. SLK7AB12C9'),
            ),
            _plabel(context, 'Name the money was sent from (if you did not note the code)'),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Grace Wanjiru — the name on M-Pesa'),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bolt, size: 18), SizedBox(width: 6), Text('I have sent the money'),
                    ]))),
            const SizedBox(height: 10),
            Text('Payments go directly to ${st.paybillName}, not to HuntInKE. Rent and deposits are NEVER paid through this platform.',
                style: TextStyle(fontSize: 12, color: t.ink3, height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _block(BuildContext context, String title, Widget child) {
    final t = T(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: t.ink)),
        const SizedBox(height: 9),
        child,
      ]),
    );
  }

  Widget _payStep(BuildContext context, String n, String title, String body) {
    final t = T(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 28, height: 28, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: t.pine),
            child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5))),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: t.ink)),
          const SizedBox(height: 2),
          Text(body, style: TextStyle(fontSize: 12.5, color: t.ink2, height: 1.5)),
        ])),
      ]),
    );
  }

  Widget _plabel(BuildContext context, String s) {
    final t = T(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 13, 0, 6),
      child: Text(s, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.ink2)),
    );
  }
}

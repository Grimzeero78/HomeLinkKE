// HuntInKE — Admin panel (exact port of viewAdmin()): Verifications · Boosts ·
// Reports · Listings · Users, with the same approve/decline/remove/delete/suspend
// actions and the pending counts badge.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  bool _loading = true;
  String _error = '';
  List<dynamic> _verifs = [], _boosts = [], _reports = [], _listings = [], _users = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() { if (mounted) setState(() {}); });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final st = context.read<AppState>();
    setState(() { _loading = true; _error = ''; });
    try {
      final s = await _safeMap(st.api.adminStats);
      _stats = (s['stats'] ?? <String, dynamic>{}) as Map<String, dynamic>;
      _verifs = await _safe(() => st.api.adminVerifications());
      _boosts = await _safe(() => st.api.adminBoosts());
      _reports = await _safe(() => st.api.adminReports());
      _listings = await _safe(() => st.api.adminListings());
      _users = await _safe(() => st.api.adminUsers());
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('ApiException: ', ''); _loading = false; });
    }
  }

  Future<List<dynamic>> _safe(Future<List<dynamic>> Function() f) async {
    try { return await f(); } catch (_) { return []; }
  }

  Future<Map<String, dynamic>> _safeMap(Future<Map<String, dynamic>> Function() f) async {
    try { return await f(); } catch (_) { return <String, dynamic>{}; }
  }

  Future<void> _act(Future<void> Function() f, String okMsg) async {
    try {
      await f();
      if (mounted) snack(context, okMsg);
      _load();
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Admin panel'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: t.pine,
          unselectedLabelColor: t.ink3,
          indicatorColor: t.pine,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(text: 'Verify'), Tab(text: 'Boosts'), Tab(text: 'Reports'),
            Tab(text: 'Listings'), Tab(text: 'Users'),
          ],
        ),
      ),
      body: _loading
          ? ListView(padding: const EdgeInsets.all(14), children: const [Skel(h: 300)])
          : _error.isNotEmpty
              ? ListView(children: [EmptyBox(Icons.lock_outline, 'Admins only', _error)])
              : RefreshIndicator(
                  color: C.ember,
                  onRefresh: _load,
                  child: TabBarView(controller: _tabs, children: [
                    _verifTab(context), _boostTab(context), _reportTab(context),
                    _listingTab(context), _userTab(context),
                  ]),
                ),
    );
  }

  Widget _card(BuildContext context, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: t0.card, borderRadius: BorderRadius.circular(15), border: Border.all(color: t0.line)),
    child: child,
  );

  T get t0 => T(Theme.of(context).brightness);

  // ---------- platform stats (top of the first tab) ----------
  Widget _statsCard(BuildContext context) {
    final t = t0;
    String v(String k) => ((_stats[k] as num?)?.toInt() ?? 0).toString();
    Widget cell(String label, String value) => Expanded(child: Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: t.ink)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10.5, color: t.ink3), textAlign: TextAlign.center),
    ]));
    return _card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('HuntInKE today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: t.ink2)),
      const SizedBox(height: 10),
      Row(children: [cell('users', v('users')), cell('landlords', v('landlords')), cell('listings', v('listings')), cell('vacant now', v('available'))]),
      const SizedBox(height: 8),
      Row(children: [cell('total views', v('views')), cell('verify pending', v('verifications')), cell('boost pending', v('boosts')), cell('open reports', v('reports'))]),
    ]));
  }

  // ---------- verifications ----------
  Widget _verifTab(BuildContext context) {
    if (_verifs.isEmpty && _stats.isEmpty) return _emptyTab(context, 'No verifications waiting', 'Landlords who submit their ID and ownership proof appear here.');
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (_stats.isNotEmpty) _statsCard(context),
        if (_verifs.isEmpty)
          _card(context, Text('No verifications waiting — landlords who submit their ID and ownership proof appear here.', style: TextStyle(fontSize: 12.5, color: t0.ink2))),
        for (final v in _verifs)
          _card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar((v['name'] ?? v['username'] ?? '?').toString(), size: 40),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((v['name'] ?? '').toString(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: t0.ink)),
                Text('@${v['username']} · ${v['phone'] ?? ''}', style: TextStyle(fontSize: 12, color: t0.ink2)),
              ])),
            ]),
            const SizedBox(height: 10),
            Text('Documents (tap to view full size in a browser dialog):', style: TextStyle(fontSize: 11.5, color: t0.ink3)),
            const SizedBox(height: 6),
            Text('ID: ${(v['doc_id'] ?? '').toString().length} chars · Ownership: ${(v['doc_own'] ?? '').toString().length} chars',
                style: TextStyle(fontSize: 12, color: t0.ink2)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: C.bad, textStyle: const TextStyle(fontSize: 13)),
                onPressed: () => _act(() => context.read<AppState>().api.adminVerify((v['id'] as num).toInt(), false, 'Documents not clear'),
                    'Verification rejected'),
                child: const Text('Reject'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40), textStyle: const TextStyle(fontSize: 13)),
                onPressed: () => _act(() => context.read<AppState>().api.adminVerify((v['id'] as num).toInt(), true, ''),
                    'Approved — green badge granted'),
                child: const Text('Approve'))),
            ]),
          ])),
      ],
    );
  }

  // ---------- boosts ----------
  Widget _boostTab(BuildContext context) {
    if (_boosts.isEmpty) return _emptyTab(context, 'No boost payments waiting', 'Landlords who send KES 200 confirm here with their M-Pesa code.');
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (final b in _boosts)
          _card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((b['ltitle'] ?? '').toString(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: t0.ink)),
            const SizedBox(height: 4),
            Text('by @${b['uname']} · ${b['uphone'] ?? ''} · ${b['town'] ?? ''}',
                style: TextStyle(fontSize: 12, color: t0.ink2)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: t0.emberMist, borderRadius: BorderRadius.circular(10)),
              child: Text('M-Pesa code: ${(b['mpesaCode'] ?? '').toString().isEmpty ? '—' : b['mpesaCode']}   ·   Sender: ${(b['senderName'] ?? '').toString().isEmpty ? '—' : b['senderName']}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: C.emberDeep)),
            ),
            const SizedBox(height: 8),
            Text('requested ${timeAgo((b['createdAt'] as num?)?.toInt())}', style: TextStyle(fontSize: 11.5, color: t0.ink3)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: C.bad, textStyle: const TextStyle(fontSize: 13)),
                onPressed: () => _act(() => context.read<AppState>().api.adminBoost((b['id'] as num).toInt(), false), 'Boost declined'),
                child: const Text('Decline'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40), textStyle: const TextStyle(fontSize: 13)),
                onPressed: () => _act(() => context.read<AppState>().api.adminBoost((b['id'] as num).toInt(), true),
                    'Boost approved — live for 7 days'),
                child: const Text('Approve boost'))),
            ]),
          ])),
      ],
    );
  }

  // ---------- reports ----------
  Widget _reportTab(BuildContext context) {
    if (_reports.isEmpty) return _emptyTab(context, 'No open reports', 'Reports from renters and landlords appear here.');
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (final r in _reports)
          _card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['reason']} — ${(r['ltitle'] ?? '').toString()}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: t0.ink)),
            const SizedBox(height: 4),
            if (((r['note'] ?? '') as String).isNotEmpty)
              Text(r['note'].toString(), style: TextStyle(fontSize: 12.5, color: t0.ink2, height: 1.45)),
            const SizedBox(height: 4),
            Text('listing #${r['listingId']} · by @${r['uname'] ?? '—'} · ${timeAgo((r['createdAt'] as num?)?.toInt())}',
                style: TextStyle(fontSize: 11.5, color: t0.ink3)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), textStyle: const TextStyle(fontSize: 12)),
                onPressed: () => _act(() => context.read<AppState>().api.adminReport((r['id'] as num).toInt(), 'resolve'), 'Report resolved'),
                child: const Text('Resolve'))),
              const SizedBox(width: 6),
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), textStyle: const TextStyle(fontSize: 12)),
                onPressed: () => _act(() => context.read<AppState>().api.adminReport((r['id'] as num).toInt(), 'remove'), 'Listing removed'),
                child: const Text('Remove listing'))),
              const SizedBox(width: 6),
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), foregroundColor: C.bad, textStyle: const TextStyle(fontSize: 12)),
                onPressed: () => _act(() => context.read<AppState>().api.adminReport((r['id'] as num).toInt(), 'delete'), 'Listing deleted'),
                child: const Text('Delete'))),
            ]),
          ])),
      ],
    );
  }

  // ---------- listings ----------
  Widget _listingTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (final l in _listings)
          _card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${l['title']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: t0.ink))),
              _statusPill(context, (l['status'] ?? '').toString()),
            ]),
            const SizedBox(height: 3),
            Text('${kes(l['rent'] as num? ?? 0)} · ${l['town']} · @${l['owner']} · ${l['views']} views · ${timeAgo((l['createdAt'] as num?)?.toInt())}',
                style: TextStyle(fontSize: 12, color: t0.ink2)),
            const SizedBox(height: 10),
            Row(children: [
              if (l['status'] == 'REMOVED')
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), textStyle: const TextStyle(fontSize: 12)),
                  onPressed: () => _act(() => context.read<AppState>().api.adminListingAction((l['id'] as num).toInt(), 'restore'), 'Listing restored'),
                  child: const Text('Restore')))
              else
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), textStyle: const TextStyle(fontSize: 12)),
                  onPressed: () => _act(() => context.read<AppState>().api.adminListingAction((l['id'] as num).toInt(), 'remove'), 'Listing removed'),
                  child: const Text('Remove'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), foregroundColor: C.bad, textStyle: const TextStyle(fontSize: 12)),
                onPressed: () async {
                  final ok = await confirmDlg(context, 'Delete this listing for everyone?',
                      'Photos, chats and boosts die with it. This cannot be undone.', 'Delete forever', danger: true);
                  if (ok) _act(() => context.read<AppState>().api.adminListingAction((l['id'] as num).toInt(), 'delete'), 'Listing deleted');
                },
                child: const Text('Delete'))),
            ]),
          ])),
      ],
    );
  }

  // ---------- users ----------
  Widget _userTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (final u in _users)
          _card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar((u['name'] ?? u['username'] ?? '?').toString(), size: 38, verified: u['verify_status'] == 'APPROVED'),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${u['name']} (@${u['username']})', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: t0.ink)),
                Text('${u['role']} · ${u['phone'] ?? ''} · ${timeAgo((u['created_at'] as num?)?.toInt())}',
                    style: TextStyle(fontSize: 11.5, color: t0.ink2)),
              ])),
              if (u['suspended'] == 1 || u['suspended'] == true)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: t0.dangerBg, borderRadius: BorderRadius.circular(99)),
                  child: const Text('SUSPENDED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: C.bad))),
            ]),
            if (u['role'] != 'ADMIN') ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), textStyle: const TextStyle(fontSize: 12)),
                  onPressed: () => _act(
                      () => context.read<AppState>().api.adminSuspend((u['id'] as num).toInt(), !(u['suspended'] == 1 || u['suspended'] == true)),
                      (u['suspended'] == 1 || u['suspended'] == true) ? 'Account unsuspended' : 'Account suspended'),
                  child: Text((u['suspended'] == 1 || u['suspended'] == true) ? 'Unsuspend' : 'Suspend'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), foregroundColor: C.bad, textStyle: const TextStyle(fontSize: 12)),
                  onPressed: () async {
                    final ok = await confirmDlg(context, 'Delete this account?',
                        'Their listings, chats and documents are wiped. Admin accounts can never be deleted.', 'Delete user', danger: true);
                    if (ok) _act(() => context.read<AppState>().api.adminDeleteUser((u['id'] as num).toInt()), 'User deleted');
                  },
                  child: const Text('Delete'))),
              ]),
            ],
          ])),
      ],
    );
  }

  Widget _statusPill(BuildContext context, String status) {
    final t = t0;
    final (bg, fg) = switch (status) {
      'AVAILABLE' => (t.mist, t.pineInk),
      'TAKEN' => (t.soft, t.ink2),
      'REMOVED' => (t.dangerBg, C.bad),
      _ => (t.soft, t.ink2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _emptyTab(BuildContext context, String title, String text) =>
      ListView(children: [EmptyBox(Icons.inbox_outlined, title, text)]);
}

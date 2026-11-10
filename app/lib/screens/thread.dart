// HuntInKE — Chat thread (exact port of viewThread()): 4s polling, WhatsApp ticks,
// typing indicator, quick-reply chips, long-press actions (Copy / Edit within 15 min /
// Delete for me / Delete for everyone), edit bar. Server keeps deleted text private.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';

class ThreadScreen extends StatefulWidget {
  final int convId;
  const ThreadScreen(this.convId, {super.key});
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _scroll = ScrollController();
  final _inp = TextEditingController();
  final _focus = FocusNode();
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _info;
  Listing? _listing;
  Map<String, dynamic>? _other;
  final List<Msg> _msgs = [];
  int _lastId = 0;
  bool _otherTyping = false;
  int? _editingMid;
  bool _sending = false;
  int _lastTypingSent = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _inp.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final st = context.read<AppState>();
    try {
      final info = await st.api.conv(widget.convId);
      if (!mounted) return;
      _info = info;
      _listing = Listing.fromJson(((info['listing'] ?? {}) as Map).cast<String, dynamic>());
      _other = (info['other'] ?? {}) as Map<String, dynamic>;
      setState(() => _loading = false);
      await _pollOnce(initial: true);
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _pollOnce());
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('ApiException: ', ''); _loading = false; });
    }
  }

  Future<void> _pollOnce({bool initial = false}) async {
    if (!mounted) return;
    final st = context.read<AppState>();
    try {
      final r = await st.api.messages(widget.convId, after: _lastId);
      if (!mounted) return;
      final items = ((r['items'] ?? []) as List).map((j) => Msg.fromJson((j as Map).cast<String, dynamic>(), st.user?.id ?? 0)).toList();
      final sync = ((r['sync'] ?? []) as List).map((j) => Msg.fromJson((j as Map).cast<String, dynamic>(), st.user?.id ?? 0)).toList();
      setState(() {
        for (final m in items) {
          _lastId = _lastId < m.id ? m.id : _lastId;
          final i = _msgs.indexWhere((x) => x.id == m.id);
          if (i >= 0) { _msgs[i] = m; } else { _msgs.add(m); }
        }
        _msgs.sort((a, b) => a.id.compareTo(b.id));
        for (final m in sync) {
          final i = _msgs.indexWhere((x) => x.id == m.id);
          if (i >= 0) _msgs[i] = m;
        }
        _otherTyping = r['otherTyping'] == true;
      });
      if (items.isNotEmpty || initial) _jumpBottom();
    } catch (_) {}
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _onInputChanged() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTypingSent > 2500) {
      _lastTypingSent = now;
      context.read<AppState>().api.typing(widget.convId);
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final st = context.read<AppState>();
    final text = _inp.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (_editingMid != null) {
        await st.api.editMsg(widget.convId, _editingMid!, text);
        final i = _msgs.indexWhere((m) => m.id == _editingMid);
        if (i >= 0) {
          _msgs[i] = Msg(
            id: _msgs[i].id, senderId: _msgs[i].senderId, createdAt: _msgs[i].createdAt,
            text: text, deleted: false, edited: true, mine: true, read: _msgs[i].read,
          );
        }
        if (mounted) setState(() { _editingMid = null; _inp.clear(); });
      } else {
        _inp.clear();
        final id = await st.api.send(widget.convId, text);
        if (!mounted) return;
        setState(() {
          _msgs.add(Msg(id: id, senderId: st.user!.id, createdAt: DateTime.now().millisecondsSinceEpoch,
              text: text, deleted: false, edited: false, mine: true, read: false));
          _lastId = _lastId < id ? id : _lastId;
        });
        _jumpBottom();
      }
    } catch (e) {
      if (mounted) {
        _inp.text = text;
        snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delMsg(Msg m, {required bool all}) async {
    final st = context.read<AppState>();
    try {
      await st.api.deleteMsg(widget.convId, m.id, all: all);
      if (!mounted) return;
      setState(() {
        if (all) {
          final i = _msgs.indexWhere((x) => x.id == m.id);
          if (i >= 0) {
            _msgs[i] = Msg(id: m.id, senderId: m.senderId, createdAt: m.createdAt, text: '', deleted: true, edited: false, mine: m.mine, read: m.read);
          }
        } else {
          _msgs.removeWhere((x) => x.id == m.id);
        }
      });
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
    }
  }

  void _bubbleMenu(Msg m) {
    if (m.deleted) return;
    final fresh = DateTime.now().millisecondsSinceEpoch - m.createdAt < 15 * 60000;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        ),
        const Divider(),
        ListTile(leading: const Icon(Icons.copy_outlined), title: const Text('Copy'),
            onTap: () { Navigator.pop(ctx); Clipboard.setData(ClipboardData(text: m.text)); snack(context, 'Copied to clipboard'); }),
        if (m.mine && fresh)
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit'),
              onTap: () { Navigator.pop(ctx); setState(() { _editingMid = m.id; _inp.text = m.text; }); _focus.requestFocus(); }),
        ListTile(leading: const Icon(Icons.visibility_off_outlined), title: const Text('Delete for me'),
            onTap: () { Navigator.pop(ctx); _delMsg(m, all: false); }),
        if (m.mine)
          ListTile(leading: const Icon(Icons.delete_outline, color: C.bad), title: const Text('Delete for everyone', style: TextStyle(color: C.bad)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await confirmDlg(context, 'Delete for everyone?',
                    'This message will be removed for both of you. This cannot be undone.', 'Delete', danger: true);
                if (ok) _delMsg(m, all: true);
              }),
        const SizedBox(height: 6),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final st = context.watch<AppState>();
    if (_loading) {
      return Scaffold(backgroundColor: t.bg, appBar: AppBar(), body: ListView(padding: const EdgeInsets.all(14), children: const [Skel(h: 70), SizedBox(height: 12), Skel(h: 300)]));
    }
    if (_error.isNotEmpty || _listing == null) {
      return Scaffold(backgroundColor: t.bg, appBar: AppBar(), body: ListView(children: [
        EmptyBox(Icons.chat_bubble_outline, 'Conversation not found', _error),
      ]));
    }
    final otherName = ((_other?['name'] ?? _other?['username'] ?? '?') as String);
    final otherVerified = (_other?['verifyStatus'] ?? '') == 'APPROVED';
    final otherPhone = ((_other?['phone'] ?? '') as String);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Avatar(otherName, size: 36, verified: otherVerified),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(otherName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: t.ink)),
            Text('${_listing!.title} · ${kes(_listing!.rent)}/${perShort(_listing!.period)}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: t.ink2)),
          ])),
        ]),
        actions: [
          if (otherPhone.isNotEmpty) ...[
            IconButton(
              tooltip: 'Call',
              onPressed: () async {
                var n = otherPhone.replaceAll(RegExp(r'[\s+-]'), '');
                if (n.startsWith('0')) n = '254${n.substring(1)}';
                try { await launchUrl(Uri.parse('tel:+$n')); } catch (_) {}
              },
              icon: const Icon(Icons.call_outlined, size: 20)),
            IconButton(
              tooltip: 'WhatsApp',
              onPressed: () async {
                final link = waLink(otherPhone, 'Hi! About "${_listing!.title}" on HuntInKE…');
                try { await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication); } catch (_) {}
              },
              icon: const Icon(Icons.chat_outlined, size: 20)),
          ],
          IconButton(
            tooltip: 'View listing',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ListingScreen(_listing!.id))),
            icon: const Icon(Icons.home_outlined, size: 20)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _focus.unfocus(),
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              itemCount: _msgs.length + (_otherTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _msgs.length) return _typingRow(context);
                return _bubble(context, _msgs[i]);
              },
            ),
          ),
        ),
        // quick replies
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final q in st.user?.isLandlord == true ? QR_LANDLORD : QR_STUDENT)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ActionChip(
                    label: Text(q, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: t.ink2)),
                    backgroundColor: t.card,
                    side: BorderSide(color: t.line),
                    onPressed: () {
                      setState(() => _editingMid = null);
                      _inp.text = q;
                      _focus.requestFocus();
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_editingMid != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: t.emberMist, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.edit_outlined, size: 15, color: C.emberDeep),
              const SizedBox(width: 7),
              const Expanded(child: Text('Editing message', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.emberDeep))),
              GestureDetector(
                onTap: () => setState(() { _editingMid = null; _inp.clear(); }),
                child: const Icon(Icons.close, size: 16, color: C.emberDeep)),
            ]),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _inp,
                focusNode: _focus,
                onChanged: (_) => _onInputChanged(),
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontSize: 14.5),
                decoration: const InputDecoration(hintText: 'Type a message…'),
              )),
              const SizedBox(width: 8),
              SizedBox(
                width: 48, height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(48, 44), padding: EdgeInsets.zero),
                  onPressed: _sending ? null : _send,
                  child: const Icon(Icons.send, size: 19),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
          child: Row(children: [
            Icon(Icons.shield_outlined, size: 12, color: t.ink3),
            const SizedBox(width: 5),
            Expanded(child: Text('Agree on a viewing first. Never send money before you have seen the room.',
                style: TextStyle(fontSize: 11.5, color: t.ink3))),
          ]),
        ),
      ]),
    );
  }

  Widget _typingRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        const SizedBox(width: 8),
        for (var i = 0; i < 3; i++)
          Container(
            width: 7, height: 7, margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(shape: BoxShape.circle, color: T(Theme.of(context).brightness).ink3),
          ),
      ]),
    );
  }

  Widget _bubble(BuildContext context, Msg m) {
    final t = T(Theme.of(context).brightness);
    final time = _timeStr(m.createdAt);
    Widget body;
    if (m.deleted) {
      body = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.not_interested, size: 12, color: t.ink3),
        const SizedBox(width: 5),
        Text(m.mine ? 'You deleted this message' : 'This message was deleted',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: t.ink3)),
      ]);
    } else {
      body = Text(m.text, style: TextStyle(fontSize: 14, color: m.mine ? Colors.white : t.ink, height: 1.4));
    }
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _bubbleMenu(m),
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
          decoration: BoxDecoration(
            color: m.deleted
                ? t.soft
                : m.mine ? t.pineBtn : t.card,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(15),
              topRight: const Radius.circular(15),
              bottomLeft: Radius.circular(m.mine ? 15 : 4),
              bottomRight: Radius.circular(m.mine ? 4 : 15),
            ),
            border: m.mine || m.deleted ? null : Border.all(color: t.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            body,
            if (!m.deleted) ...[
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (m.edited)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Text('edited', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: m.mine ? Colors.white70 : t.ink3)),
                  ),
                Text(time, style: TextStyle(fontSize: 10, color: m.mine ? Colors.white70 : t.ink3)),
                if (m.mine) ...[
                  const SizedBox(width: 3),
                  Text(m.read ? '✓✓' : '✓',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: m.read ? const Color(0xFF9CE0BB) : Colors.white70)),
                ],
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  String _timeStr(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final am = d.hour < 12 ? 'AM' : 'PM';
    return '$h:${d.minute.toString().padLeft(2, '0')} $am';
  }
}

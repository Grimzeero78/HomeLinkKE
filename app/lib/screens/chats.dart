// HuntInKE — Chats: conversation list (2.5s → 12s polling like the web viewChats()).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import 'auth.dart';
import 'thread.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  bool _loading = true;
  String _error = '';
  List<Conv> _items = [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final st = context.read<AppState>();
    if (st.user == null) { setState(() => _loading = false); return; }
    if (!silent) setState(() { _loading = true; _error = ''; });
    try {
      final rows = await st.api.convs();
      if (!mounted) return;
      setState(() {
        _items = rows.map((j) => Conv.fromJson((j as Map).cast<String, dynamic>())).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('ApiException: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final st = context.watch<AppState>();
    if (st.user == null) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(title: const Text('Chats')),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.chat_bubble_outline, size: 46, color: t.ink3),
          const SizedBox(height: 10),
          Text('Sign in to see your chats', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: t.ink)),
          const SizedBox(height: 6),
          Text('Renters and landlords talk here — ask about\nviewings, water, deposit, anything.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: t.ink2, height: 1.5)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 22)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
            child: const Text('Sign in'),
          ),
        ])),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Chats')),
      body: RefreshIndicator(
        color: C.ember,
        onRefresh: _load,
        child: _loading
            ? ListView(padding: const EdgeInsets.all(14), children: const [Skel(h: 74), SizedBox(height: 10), Skel(h: 74)])
            : _error.isNotEmpty
                ? ListView(children: [EmptyBox(Icons.wifi_off, 'Could not load chats', _error)])
                : _items.isEmpty
                    ? ListView(children: const [
                        EmptyBox(Icons.chat_bubble_outline, 'No chats yet',
                            'Open any listing and tap "Message in app" to start talking to the landlord.'),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                        itemCount: _items.length,
                        itemBuilder: (context, i) => _row(context, _items[i]),
                      ),
      ),
    );
  }

  Widget _row(BuildContext context, Conv c) {
    final t = T(Theme.of(context).brightness);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThreadScreen(c.id)))
            .then((_) => _load(silent: true)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(children: [
            Stack(children: [
              Avatar(c.otherName.isEmpty ? '?' : c.otherName, size: 46),
              if (c.unread > 0)
                Positioned(
                  right: -2, top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: C.ember, borderRadius: BorderRadius.circular(99), border: Border.all(color: t.bg, width: 1.6)),
                    child: Text('${c.unread > 9 ? '9+' : c.unread}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(c.otherName.isEmpty ? 'User' : c.otherName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: t.ink))),
                Text(timeAgo(c.lastAt), style: TextStyle(fontSize: 11, color: t.ink3)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(child: Text(c.lastMsg.isEmpty ? 'New conversation' : c.lastMsg,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: c.unread > 0 ? t.ink : t.ink2))),
                Text('${kes(num.tryParse(c.lrent) ?? 0)}/mo',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.pine)),
              ]),
              if (c.ltitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(c.ltitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: t.ink3)),
                ),
            ])),
          ]),
        ),
      ),
    );
  }
}

// HuntInKE — Favourites (exact port of viewFavorites()).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'listing.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _loading = true;
  String _error = '';
  List<Listing> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final st = context.read<AppState>();
    try {
      final rows = await st.api.myFavorites();
      if (!mounted) return;
      setState(() {
        _items = rows.map((j) => Listing.fromJson((j as Map).cast<String, dynamic>())).toList();
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
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Favourites')),
      body: _loading
          ? ListView(padding: const EdgeInsets.all(14), children: const [Skel(h: 300)])
          : _error.isNotEmpty
              ? ListView(children: [EmptyBox(Icons.wifi_off, 'Sign in required', _error)])
              : _items.isEmpty
                  ? ListView(children: const [
                      EmptyBox(Icons.favorite_border, 'No favourites yet',
                          'Tap the Save button on any listing to keep it here.'),
                    ])
                  : RefreshIndicator(
                      color: C.ember,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(14),
                        children: [
                          ListingGrid(_items, onOpen: (l) =>
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ListingScreen(l.id)))
                                  .then((_) => _load())),
                        ],
                      ),
                    ),
    );
  }
}

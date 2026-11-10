// HuntInKE — bottom navigation shell: Home · Search · Map · Chats (unread badge) · Profile,
// plus a floating Post button for landlords. Same tabs as the website's bottom nav.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import 'chats.dart';
import 'create.dart';
import 'home.dart';
import 'mapview.dart';
import 'profile.dart';
import 'search.dart';

// lets any screen jump to a tab (e.g. "Open map →" on the home page)
final ValueNotifier<int> shellTab = ValueNotifier<int>(0);

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    shellTab.addListener(_onTabReq);
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTabReq);
    super.dispose();
  }

  void _onTabReq() {
    if (!mounted) return;
    setState(() => _tab = shellTab.value);
  }

  void _go(int i) {
    setState(() => _tab = i);
    if (shellTab.value != i) shellTab.value = i;
    if (i == 3) context.read<AppState>().resetUnreadBadge();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final pages = [
      const HomeScreen(), const SearchScreen(), const MapScreen(),
      const ChatsScreen(), const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: st.user?.isLandlord == true
          ? FloatingActionButton.extended(
              backgroundColor: C.ember,
              foregroundColor: Colors.white,
              heroTag: 'post',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateScreen())),
              icon: const Icon(Icons.add_home_work_outlined, size: 20),
              label: const Text('Post listing', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Search'),
          const NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on), label: 'Map'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: st.unread > 0,
              label: Text('${st.unread > 9 ? '9+' : st.unread}'),
              backgroundColor: C.ember,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

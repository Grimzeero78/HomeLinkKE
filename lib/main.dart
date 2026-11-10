// HuntInKE — app entry. Boots the session (same token the browser saves), starts
// notifications, applies the light/dark/system theme and shows the splash → app.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notifs.dart';
import 'state.dart';
import 'theme.dart';
import 'screens/auth.dart';
import 'screens/shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifs.init();
  final st = AppState();
  runApp(HuntInApp(state: st));
}

class HuntInApp extends StatefulWidget {
  final AppState state;
  const HuntInApp({super.key, required this.state});
  @override
  State<HuntInApp> createState() => _HuntInAppState();
}

class _HuntInAppState extends State<HuntInApp> {
  @override
  void initState() {
    super.initState();
    widget.state.boot();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.state,
      child: Consumer<AppState>(
        builder: (context, st, _) => MaterialApp(
          title: 'HuntIn KE',
          debugShowCheckedModeBanner: false,
          theme: huntinTheme(Brightness.light),
          darkTheme: huntinTheme(Brightness.dark),
          themeMode: st.themeMode,
          home: !st.ready ? const _Splash() : (st.user == null ? const AuthScreen() : const Shell()),
        ),
      ),
    );
  }
}

// splash — same feel as the website's (#splash): pine background, logo + wordmark
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.pine,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.all(6),
            child: Image.asset('assets/icon/icon-1024.png',
                errorBuilder: (_, __, ___) => const Icon(Icons.home, color: C.pine, size: 52)),
          ),
          const SizedBox(height: 18),
          const Text.rich(
            TextSpan(children: [
              TextSpan(text: 'HUNT', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
              TextSpan(text: 'IN', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: C.ember, letterSpacing: 1)),
              TextSpan(text: 'KE', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
            ]),
          ),
          const SizedBox(height: 10),
          Text('Vacant houses across Kenya', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .75))),
        ]),
      ),
    );
  }
}

// HuntInKE — app entry. Boots the session (same token the browser saves), starts
// notifications, applies the light/dark/system theme and shows the splash → app.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notifs.dart';
import 'state.dart';
import 'theme.dart';
import 'screens/shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // If a screen ever throws, show the error text on screen (long-press to copy
  // and send it to us) instead of the blank/grey screen Flutter shows by default.
  ErrorWidget.builder = (details) => _CrashBox(text: details.exceptionAsString());
  final st = AppState();
  // UI starts immediately — never wait for plugins before the first frame.
  // (Waiting here froze the splash forever on emulators/old Android when the
  // notifications plugin failed.)
  runApp(HuntInApp(state: st));
  _initNotifs(); // in the background; notifications are optional, not critical
}

Future<void> _initNotifs() async {
  try {
    await Notifs.init();
  } catch (_) {
    // old Android/emulator without notification support — app still works
  }
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
          // ALWAYS open the app shell (Home · Search · Map · Chats · Profile).
          // Guests browse freely — same as the website — and sign in only when
          // they tap Sign in / save a house / message a landlord.
          home: !st.ready ? const _Splash() : const Shell(),
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

// Full-screen replacement for Flutter's blank/grey crash page: shows the actual
// error text so a screenshot (or a long-press copy) tells us exactly what broke.
class _CrashBox extends StatelessWidget {
  final String text;
  const _CrashBox({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDECEC),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bug_report_outlined, size: 42, color: Color(0xFFB3261E)),
          const SizedBox(height: 12),
          const Text('Something broke on this screen',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: Color(0xFF7A1F17))),
          const SizedBox(height: 6),
          const Text('Screenshot or long-press to copy this and send it to support.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF8C4239))),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(text,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B221D))),
          ),
        ]),
      ),
    );
  }
}

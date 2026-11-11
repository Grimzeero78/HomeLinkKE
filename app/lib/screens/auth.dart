// HuntInKE — Login / Register. Same fields, same rules as the website's viewAuth().
// After creating an account the user lands on the welcome guide (role-aware).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'welcome.dart';
import 'shell.dart' show shellTab;

class AuthScreen extends StatefulWidget {
  final bool register;
  const AuthScreen({super.key, this.register = false});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isReg = widget.register;
  String _role = 'SEEKER';
  bool _busy = false;

  final _liU = TextEditingController(), _liP = TextEditingController();
  final _rgName = TextEditingController(), _rgPhone = TextEditingController(),
      _rgU = TextEditingController(), _rgP = TextEditingController(),
      _rgP2 = TextEditingController(), _rgHint = TextEditingController();

  @override
  void dispose() {
    for (final c in [_liU, _liP, _rgName, _rgPhone, _rgU, _rgP, _rgP2, _rgHint]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _doLogin() async {
    final st = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final r = await st.api.login(_liU.text.trim(), _liP.text);
      if (!mounted) return;
      await st.signIn((r['token'] ?? '').toString(), User.fromJson((r['user'] ?? {}) as Map<String, dynamic>));
      if (!mounted) return;
      snack(context, 'Welcome, ${st.user!.name.isNotEmpty ? st.user!.name : st.user!.username}!');
      shellTab.value = 0;
      // Grab the navigator BEFORE popping — popping the last route would leave a
      // black screen, and a disposed context cannot push/pop at all.
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doRegister() async {
    final st = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final r = await st.api.register({
        'role': _role,
        'name': _rgName.text.trim(),
        'phone': _rgPhone.text.trim(),
        'username': _rgU.text.trim(),
        'password': _rgP.text,
        'confirm': _rgP2.text,
        'hint': _rgHint.text.trim(),
      });
      if (!mounted) return;
      await st.signIn((r['token'] ?? '').toString(), User.fromJson((r['user'] ?? {}) as Map<String, dynamic>));
      if (!mounted) return;
      // Grab the navigator before popping (see _doLogin).
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
      nav.push(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final u = TextEditingController();
    String out = '';
    bool asked = false;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => AlertDialog(
      title: const Text('Password hint'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Enter your username and we will show you the hint you saved when registering.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        TextField(controller: u, decoration: const InputDecoration(hintText: 'username')),
        if (asked) ...[
          const SizedBox(height: 12),
          Text(out, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton(
          onPressed: () async {
            try {
              final h = await context.read<AppState>().api.hint(u.text.trim().toLowerCase());
              setM(() { asked = true; out = h.isEmpty ? 'No account found with that username.' : 'Your hint: $h'; });
            } catch (e) {
              setM(() { asked = true; out = e.toString().replaceFirst('ApiException: ', ''); });
            }
          },
          child: const Text('Show my hint'),
        ),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.line)),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // clean web icon + the brand shadow from web .brand-logo
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: C.pine.withValues(alpha: .45), blurRadius: 12, offset: const Offset(0, 4), spreadRadius: -4)],
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(12),
                        child: Image.asset('assets/icon/icon-192.png', width: 44, height: 44,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 44))),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const BrandWord(size: 19),
                    const SizedBox(height: 3),
                    SizedBox(width: 230, child: Text(
                      _isReg
                          ? 'Create a free account — find a house anywhere in Kenya or list your own.'
                          : 'Vacant houses & apartments across Kenya — chat with landlords directly, never pay before viewing.',
                      style: TextStyle(fontSize: 11.8, color: t.ink3, height: 1.4))),
                  ]),
                ]),
                const SizedBox(height: 16),
                // segmented Sign in / Create account
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line, width: 1.4)),
                  child: Row(children: [
                    _seg(context, 'Sign in', !_isReg, () => setState(() => _isReg = false)),
                    _seg(context, 'Create account', _isReg, () => setState(() => _isReg = true)),
                  ]),
                ),
                const SizedBox(height: 6),
                if (!_isReg) ...[
                  _lbl(context, 'Username'),
                  TextField(controller: _liU, autofillHints: const [AutofillHints.username], decoration: const InputDecoration(hintText: 'your username')),
                  _lbl(context, 'Password'),
                  TextField(controller: _liP, obscureText: true, autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _doLogin(),
                      decoration: const InputDecoration(hintText: '••••••••')),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: _busy ? null : _doLogin,
                      child: _busy ? const _Spin() : const Text('Sign in'))),
                  SizedBox(width: double.infinity, child: TextButton(
                      onPressed: _forgot, child: const Text('Forgot password?', style: TextStyle(fontSize: 13)))),
                ] else ...[
                  _lbl(context, 'I am a…'),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line, width: 1.4)),
                    child: Row(children: [
                      _seg(context, 'Looking for a house', _role == 'SEEKER', () => setState(() => _role = 'SEEKER')),
                      _seg(context, 'Landlord', _role == 'LANDLORD', () => setState(() => _role = 'LANDLORD')),
                    ]),
                  ),
                  _lbl(context, 'Full name'),
                  TextField(controller: _rgName, autofillHints: const [AutofillHints.name], decoration: const InputDecoration(hintText: 'e.g. Brian Mutua')),
                  _lbl(context, 'WhatsApp number (the other side reaches you here)'),
                  TextField(controller: _rgPhone, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber], decoration: const InputDecoration(hintText: 'e.g. 0712 345 678 or 254712…')),
                  _lbl(context, 'Username'),
                  TextField(controller: _rgU, autofillHints: const [AutofillHints.newUsername], decoration: const InputDecoration(hintText: '3–20 letters, numbers or _')),
                  _lbl(context, 'Password'),
                  TextField(controller: _rgP, obscureText: true, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(hintText: 'At least 6 characters')),
                  _lbl(context, 'Confirm password'),
                  TextField(controller: _rgP2, obscureText: true, decoration: const InputDecoration(hintText: 'Type the password again')),
                  _lbl(context, 'Password hint'),
                  TextField(controller: _rgHint, decoration: const InputDecoration(hintText: 'e.g. my nickname + year I finished school')),
                  const SizedBox(height: 5),
                  Text("Shown to you if you forget your password. Don't make it the same as the password.",
                      style: TextStyle(fontSize: 12, color: t.ink3, height: 1.4)),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: _busy ? null : _doRegister,
                      child: _busy ? const _Spin() : const Text('Create account'))),
                ],
                const SizedBox(height: 12),
                Center(child: Text.rich(TextSpan(style: TextStyle(fontSize: 12.5, color: t.ink2), children: [
                  TextSpan(text: _isReg ? 'Already have an account? ' : 'New to HuntInKE? '),
                  TextSpan(
                    text: _isReg ? 'Sign in' : 'Create an account',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: C.pine),
                    recognizer: null,
                  ),
                ])),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isReg = !_isReg),
                  child: const SizedBox(height: 20, width: double.infinity),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seg(BuildContext context, String label, bool on, VoidCallback onTap) {
    final t = T(Theme.of(context).brightness);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
              color: on ? t.pineBtn : Colors.transparent,
              borderRadius: BorderRadius.circular(9)),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: on ? Colors.white : t.ink2)),
        ),
      ),
    );
  }

  Widget _lbl(BuildContext context, String s) {
    final t = T(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 13, 0, 6),
      child: Text(s, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.ink2, letterSpacing: .02)),
    );
  }
}

class _Spin extends StatelessWidget {
  const _Spin();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
        strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation(Colors.white)));
  }
}

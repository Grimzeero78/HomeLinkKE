// HuntInKE — Profile: account card, edit profile, landlord verification (ID + ownership
// docs), quick actions, sign out. Plus the role-aware Welcome guide
// shown right after creating an account (exact port of viewProfile / viewWelcome).
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../notifs.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import 'admin.dart';
import 'auth.dart';
import 'create.dart';
import 'favorites.dart';
import 'mylistings.dart';
import 'privacy.dart';
import 'welcome.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _edit = false;
  Uint8List? _docId, _docOwn;

  final _name = TextEditingController(), _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDoc(bool isId) async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img == null) return;
    if (mounted) snack(context, 'Processing image…');
    final bytes = await img.readAsBytes();
    setState(() => isId ? _docId = bytes : _docOwn = bytes);
  }

  Future<void> _submitVerify() async {
    final st = context.read<AppState>();
    if (_docId == null || _docOwn == null) {
      snack(context, 'Upload both photos first', error: true);
      return;
    }
    try {
      final docId = await compressToDataUrl(_docId!, maxKB: 260, maxDim: 1400, q: 78);
      final docOwn = await compressToDataUrl(_docOwn!, maxKB: 260, maxDim: 1400, q: 78);
      await st.api.verify({'docId': docId, 'docOwn': docOwn});
      await st.refreshUser();
      if (mounted) {
        snack(context, 'Submitted! The admin will review your documents.');
        Notifs.showAccount('Verification submitted',
            'The admin will review your documents and approve your green badge.');
      }
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
    }
  }

  Future<void> _saveProfile() async {
    final st = context.read<AppState>();
    try {
      final r = await st.api.updateMe({'name': _name.text.trim(), 'phone': _phone.text.trim()});
      await st.updateUser(User.fromJson((r['user'] ?? {}) as Map<String, dynamic>));
      if (mounted) { snack(context, 'Profile saved'); setState(() => _edit = false); }
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('ApiException: ', ''), error: true);
    }
  }

  Future<void> _signOut() async {
    final ok = await confirmDlg(context, 'Sign out?', 'End this session on this device.', 'Sign out', danger: true);
    if (!ok) return;
    final st = context.read<AppState>();
    await st.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final st = context.watch<AppState>();
    if (st.user == null) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(child: ListView(shrinkWrap: true, children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.person_outline, size: 46, color: t.ink3),
            const SizedBox(height: 10),
            Text('You are not signed in', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: t.ink)),
            const SizedBox(height: 6),
            Text('Sign in to save houses, chat with landlords\nand post your own listings.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: t.ink2, height: 1.5)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 22)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
              child: const Text('Sign in or create account'),
            ),
          ]),
        ])),
      );
    }
    final u = st.user!;
    final roleTxt = u.isAdmin ? 'Admin' : u.isLandlord ? 'Landlord' : 'Renter';

    return Scaffold(
      backgroundColor: t.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.line)),
            child: _edit ? _editForm(context, u) : _profileCard(context, u, roleTxt),
          ),
          if (u.isLandlord) ...[
            const SizedBox(height: 14),
            _verifyCard(context, u),
          ],
          const SizedBox(height: 18),
          Text(u.isLandlord ? 'LANDLORD TOOLS' : 'QUICK ACTIONS',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: t.ink3, letterSpacing: .6)),
          const SizedBox(height: 8),
          ProwBox(children: [
            if (u.isLandlord) Prow(Icons.description_outlined, 'My listings',
                sub: 'Edit, mark taken, or boost your rooms',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen()))),
            if (u.isLandlord) Prow(Icons.add_home_work_outlined, 'Post a new listing',
                sub: 'Free plan: 2 listings · verified: 5',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateScreen()))),
            if (u.isAdmin) Prow(Icons.settings_outlined, 'Admin panel',
                sub: 'Verifications, boosts, reports, users',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()))),
            Prow(Icons.favorite_border, 'Favourites', sub: 'Rooms you saved for later',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()))),
            Prow(Icons.map_outlined, 'Getting started guide', sub: 'How it works — the guide from your first day',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()))),
            Prow(Icons.shield_outlined, 'Privacy & safety', sub: 'How HuntInKE handles your data',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()))),
          ]),
          const SizedBox(height: 18),
          ProwBox(children: [
            Prow(Icons.logout, 'Sign out', sub: 'End this session on this device', danger: true, onTap: _signOut),
          ]),
          const SizedBox(height: 26),
          Center(child: Text('HuntInKE · never pay before viewing',
              style: TextStyle(fontSize: 11.5, color: t.ink3))),
        ],
      ),
    );
  }

  Widget _profileCard(BuildContext context, User u, String roleTxt) {
    final t = T(Theme.of(context).brightness);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Avatar(u.name.isNotEmpty ? u.name : u.username, size: 52, verified: u.verified),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u.name.isNotEmpty ? u.name : u.username,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: t.ink)),
          const SizedBox(height: 2),
          Text('@${u.username} · $roleTxt · joined ${fmtDate(u.createdAt)}',
              style: TextStyle(fontSize: 12, color: t.ink3)),
        ])),
      ]),
      const SizedBox(height: 14),
      Kv('Full name', u.name.isEmpty ? '—' : u.name),
      Kv('WhatsApp number', u.phone.isEmpty ? '—' : u.phone),
      Kv('Account', roleTxt),
      const SizedBox(height: 12),
      ElevatedButton(
        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: () {
          _name.text = u.name;
          _phone.text = u.phone;
          setState(() => _edit = true);
        },
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.edit_outlined, size: 16), SizedBox(width: 6), Text('Edit profile'),
        ]),
      ),
    ]);
  }

  Widget _editForm(BuildContext context, User u) {
    final t = T(Theme.of(context).brightness);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: t.ink)),
      _lbl(context, 'Full name'),
      TextField(controller: _name, decoration: const InputDecoration()),
      _lbl(context, 'WhatsApp number (shown to the other side)'),
      TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration()),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => setState(() => _edit = false), child: const Text('Cancel'))),
        const SizedBox(width: 9),
        Expanded(child: ElevatedButton(onPressed: _saveProfile, child: const Text('Save changes'))),
      ]),
    ]);
  }

  Widget _lbl(BuildContext context, String s) {
    final t = T(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 13, 0, 6),
      child: Text(s, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.ink2)),
    );
  }

  Widget _verifyCard(BuildContext context, User u) {
    final t = T(Theme.of(context).brightness);
    final st = u.verifyStatus;
    final pill = switch (st) {
      'APPROVED' => _vpill(context, 'Verified landlord — up to 5 listings', t.mist, t.pineInk),
      'PENDING' => _vpill(context, 'Verification under review', t.emberMist, C.emberDeep),
      'REJECTED' => _vpill(context, u.verifyNote.isEmpty ? 'Rejected' : 'Rejected: ${u.verifyNote}', t.dangerBg, C.bad),
      _ => _vpill(context, 'Not verified — 2 listing limit', t.soft, t.ink2),
    };
    final needDocs = st == 'NONE' || st == 'REJECTED';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Landlord verification', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: t.ink)),
        const SizedBox(height: 9),
        pill,
        const SizedBox(height: 9),
        Text('Verified landlords get a green badge on every listing and can post up to 5 listings. Upload a photo of your National ID and a proof of ownership (title deed, allotment letter, or a signed note from the compound owner).',
            style: TextStyle(fontSize: 12.3, color: t.ink2, height: 1.5)),
        if (needDocs) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _docCell(context, 'ID photo', _docId, () => _pickDoc(true))),
            const SizedBox(width: 10),
            Expanded(child: _docCell(context, 'Ownership doc', _docOwn, () => _pickDoc(false))),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _submitVerify, child: const Text('Submit for verification'))),
        ],
      ]),
    );
  }

  Widget _vpill(BuildContext context, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _docCell(BuildContext context, String label, Uint8List? bytes, VoidCallback onTap) {
    final t = T(Theme.of(context).brightness);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
        child: bytes != null
            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.camera_alt_outlined, size: 22, color: t.ink2),
                const SizedBox(height: 5),
                Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: t.ink2)),
              ]),
      ),
    );
  }
}

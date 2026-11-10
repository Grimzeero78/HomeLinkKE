// HuntInKE — first-time welcome & guide (exact port of viewWelcome()).
// Role-aware: seekers get the anti-scam warning + how it works; landlords get the
// verify → post → boost guide. Reachable any time from Profile → Getting started guide.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'create.dart';
import 'shell.dart' show shellTab;

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final st = context.watch<AppState>();
    final isLL = st.user?.isLandlord == true;
    final hi = (st.user?.name ?? '').isNotEmpty ? ', ${st.user!.name.split(' ').first}' : '';

    final seeker = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      Notice(Icons.shield_outlined, '', kind: 'o', richChild: Text.rich(TextSpan(
        style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600, color: C.emberDeep, height: 1.5),
        children: const [
          TextSpan(text: 'Never send money before you SEE the house. ', style: TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: 'No deposit, no booking fee, no reservation — nothing. Visit the house first, then pay the landlord directly.'),
        ]))),
      const SizedBox(height: 16),
      _block(context, 'How HuntInKE works', _list(context, [
        ('Search', "type a town in the search bar, or tap Use my location to see vacant houses nearest to you first."),
        ('Open & compare', 'check the photos, rent, deposit, water and electricity on every listing before you chat.'),
        ('Chat', 'message the landlord in the app or on WhatsApp. Ask anything — when to view, what is included.'),
        ('Visit & view', 'go see the house in daylight, ideally with a friend. A real landlord will welcome this.'),
        ('Pay only after viewing', 'deposit and rent go directly to the landlord, never through HuntInKE.'),
      ])),
      const SizedBox(height: 16),
      _block(context, 'Red flags — walk away', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _list(context, [
          ('Rushing', 'anyone rushing you to send M-Pesa for a house you have not seen.'),
          ('Pay-first stories', '"Pay first to book" stories, or rent too cheap for that area.'),
          ('No viewing', 'refusing a video call or a physical viewing.'),
        ], numbered: false),
        const SizedBox(height: 8),
        Text('See a fake listing? Open it and tap Report — every report is reviewed by the admin.',
            style: TextStyle(fontSize: 12.3, color: t.ink3, height: 1.5)),
      ])),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () { shellTab.value = 0; Navigator.pop(context); },
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on_outlined, size: 17), SizedBox(width: 6), Text('Find houses near me'),
        ]))),
    ]);

    final landlord = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      _block(context, 'Your 4 steps to renting out faster', _list(context, [
        ('Get verified', 'Profile → verification: upload your ID and an ownership photo. The admin approves it, you earn the green badge and 5 listings instead of 2. Verified landlords get more chats.'),
        ('Post your house', 'tap Post listing: 8 quick steps. Pick the town, pin your exact spot on the map, add 3+ clear daylight photos.'),
        ('Boost for KES $BOOST_AMOUNT_KES', 'your listing sits at the top for $BOOST_DAYS days for every renter browsing your town. Pay by M-Pesa, enter the code, and the admin turns it on.'),
        ('Reply fast', 'houses whose landlord answers quickly rent much faster. Chats land in your Chats tab.'),
      ])),
      const SizedBox(height: 16),
      Notice(Icons.shield_outlined, '', kind: 'g', richChild: Text.rich(TextSpan(
        style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600, color: t.pineInk, height: 1.5),
        children: const [
          TextSpan(text: 'Be the landlord renters trust: ', style: TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: 'never ask for money before a viewing, and meet tenants at the house in daylight. HuntInKE never collects money on your behalf.'),
        ]))),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateScreen()));
          },
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 17), SizedBox(width: 6), Text('Post my first house'),
          ]))),
        const SizedBox(width: 9),
        Expanded(child: OutlinedButton(
          onPressed: () { Navigator.pop(context); shellTab.value = 4; },
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shield_outlined, size: 17), SizedBox(width: 6), Text('Verify me'),
          ]))),
      ]),
    ]);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Getting started')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/icon/icon-1024.png', width: 44, height: 44,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 44))),
                const SizedBox(width: 11),
                Expanded(child: Text('Welcome to HuntInKE$hi!',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17.5, color: t.ink, height: 1.25))),
              ]),
              const SizedBox(height: 8),
              Text(isLL ? 'Your account is ready — here is how to rent out fast and safe.'
                       : 'Your account is ready — here is how to find a house safely.',
                  style: TextStyle(fontSize: 13, color: t.ink2, height: 1.5)),
              isLL ? landlord : seeker,
            ]),
          ),
        ],
      ),
    );
  }

  Widget _block(BuildContext context, String title, Widget child) {
    final t = T(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: t.ink)),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }

  Widget _list(BuildContext context, List<(String, String)> items, {bool numbered = true}) {
    final t = T(Theme.of(context).brightness);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 20, height: 20, margin: const EdgeInsets.only(top: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: numbered ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: numbered ? null : BorderRadius.circular(6),
                  color: t.mist),
              child: Text(numbered ? '${i + 1}' : '!',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.pineInk)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text.rich(TextSpan(
              style: TextStyle(fontSize: 13.2, color: t.ink2, height: 1.5),
              children: [
                TextSpan(text: '${items[i].$1} — ', style: TextStyle(fontWeight: FontWeight.w800, color: t.ink)),
                TextSpan(text: items[i].$2),
              ]))),
          ]),
        ),
    ]);
  }
}

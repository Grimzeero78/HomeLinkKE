// HuntInKE — Privacy & safety (exact port of viewPrivacy()).
import 'package:flutter/material.dart';
import '../theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    Widget block(String title, String text) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: t.ink)),
        const SizedBox(height: 7),
        Text(text, style: TextStyle(fontSize: 13.2, color: t.ink2, height: 1.6)),
      ]),
    );
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Privacy & safety')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          block('What we store',
              'Your username, name, phone/WhatsApp number, role, and — for landlords — the verification documents you upload. Listing photos and details you post. Chat messages you send. Nothing else. No email, no tracking pixels.'),
          block('Who can see it',
              'Listing content is public. Your phone number is shown to signed-in users on your listings and in chats so renters can reach you. Your verification documents are only visible to the admin. Chats are only visible to you and the other person. If you share your location, it stays on your device — it is never sent to our servers.'),
          block('The golden rule',
              'HuntInKE never collects rent, deposit, or any payment. All money matters happen face-to-face after a viewing. If anyone asks you to pay through the app or before a viewing, report them.'),
          block('Data Protection Act (Kenya, 2019)',
              'We collect the minimum data needed to run the service. You may ask for your data to be deleted at any time — contact the site admin.'),
        ],
      ),
    );
  }
}

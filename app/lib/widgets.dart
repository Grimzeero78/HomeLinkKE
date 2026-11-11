// HuntInKE — shared widgets: listing card (same layout as the website's listingCard()),
// vacancy badges, amenity tags, empty boxes, section headers, kv rows, settings rows.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';
import 'util.dart';

// ---------- snack (the web toast) ----------
void snack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? C.bad : null,
      duration: const Duration(milliseconds: 2600),
    ));
}

Future<bool> confirmDlg(BuildContext context, String title, String text, String okLabel,
    {bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: C.bad) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

// ---------- data-URL image, decoded at display size (fast, low memory) ----------
class DataImg extends StatelessWidget {
  final String? dataUrl;
  final double? width, height;
  final BoxFit fit;
  final int cachePx;
  final Widget? placeholder;
  const DataImg(this.dataUrl,
      {super.key, this.width, this.height, this.fit = BoxFit.cover, this.cachePx = 600, this.placeholder});

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final d = dataUrl;
    if (d == null || !d.contains(',')) {
      return placeholder ?? Container(color: t.galBg, width: width, height: height);
    }
    try {
      final bytes = base64Decode(d.split(',')[1]);
      return Image.memory(bytes,
          width: width, height: height, fit: fit, gaplessPlayback: true,
          cacheWidth: (cachePx * MediaQuery.devicePixelRatioOf(context)).round());
    } catch (_) {
      return placeholder ?? Container(color: t.galBg, width: width, height: height);
    }
  }
}

// ---------- brand word mark ----------
class BrandWord extends StatelessWidget {
  final double size;
  const BrandWord({super.key, this.size = 17});
  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: [
      TextSpan(text: 'HUNT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: size)),
      TextSpan(text: 'IN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: size, color: C.ember)),
      TextSpan(text: 'KE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: size)),
    ]));
  }
}

// ---------- vacancy badge (green "3 VACANT" / red "ALL OCCUPIED") ----------
class VacBadge extends StatelessWidget {
  final Listing l;
  final bool small;
  const VacBadge(this.l, {super.key, this.small = false});
  @override
  Widget build(BuildContext context) {
    final label = l.full ? 'ALL OCCUPIED' : '${l.vacantCount} VACANT';
    final bg = l.full ? C.bad : (T(Theme.of(context).brightness).pine);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(l.full ? Icons.close : Icons.check, size: small ? 11 : 12, color: Colors.white),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(
            color: l.full ? Colors.white : const Color(0xFF08130C),
            fontSize: small ? 10 : 10.5, fontWeight: FontWeight.w800, letterSpacing: .3)),
      ]),
    );
  }
}

// ---------- THE listing card (web .card) ----------
class ListingCard extends StatelessWidget {
  final Listing l;
  final double? distanceM;
  final VoidCallback onOpen;
  const ListingCard(this.l, {super.key, required this.onOpen, this.distanceM});

  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final loc = [l.town, if (l.area.isNotEmpty) l.area, if (l.landmark.isNotEmpty) l.landmark].join(' · ');
    final tags = amenityTags(l.raw);
    final dist = distanceM != null ? '${fmtDist(distanceM!)} away' : '';
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: l.thumb.isNotEmpty
                  ? DataImg(l.thumb, cachePx: 340, fit: BoxFit.cover,
                      placeholder: Container(color: t.galBg))
                  : Container(color: t.galBg, child: Icon(Icons.photo_outlined, size: 34, color: t.ink3)),
            ),
            if (l.boosted)
              Positioned(
                top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: C.ember, borderRadius: BorderRadius.circular(99)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bolt, size: 11, color: Colors.white),
                    SizedBox(width: 2),
                    Text('BOOSTED', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            Positioned(bottom: 8, left: 8, child: VacBadge(l)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: kes(l.rent), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: t.pineInk, letterSpacing: -.3)),
                TextSpan(text: '/${perShort(l.period)}', style: TextStyle(fontSize: 11.5, color: t.ink3, fontWeight: FontWeight.w600)),
              ])),
              const SizedBox(height: 2),
              Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 13, color: t.ink2),
                const SizedBox(width: 3),
                Expanded(child: Text(loc, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: t.ink2))),
              ]),
              const SizedBox(height: 7),
              if (tags.isNotEmpty || dist.isNotEmpty)
                SizedBox(
                  height: 20,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final tg in tags)
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(color: t.mist, borderRadius: BorderRadius.circular(6)),
                            child: Text(tg, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: t.pineInk)),
                          ),
                        ),
                      if (dist.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(color: t.mist, borderRadius: BorderRadius.circular(6)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.location_on_outlined, size: 11, color: t.pine),
                            const SizedBox(width: 2),
                            Text(dist, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: t.pine)),
                          ]),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (l.ownerVerified)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified_user_outlined, size: 13, color: t.pine),
                    const SizedBox(width: 3),
                    Text('Verified', style: TextStyle(color: t.pine, fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ])
                else
                  const SizedBox.shrink(),
                Text('${l.views} views · ${timeAgo(l.createdAt)}',
                    style: TextStyle(fontSize: 11.5, color: t.ink3)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------- grid of cards (2 columns like the web .grid) ----------
class ListingGrid extends StatelessWidget {
  final List<Listing> items;
  final void Function(Listing) onOpen;
  final Map<int, double>? distances;
  const ListingGrid(this.items, {super.key, required this.onOpen, this.distances});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 620 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => ListingCard(items[i],
            distanceM: distances?[items[i].id], onOpen: () => onOpen(items[i])),
      );
    });
  }
}

// ---------- empty box / section header / kv row / prow ----------
class EmptyBox extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const EmptyBox(this.icon, this.title, this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
      child: Column(children: [
        Icon(icon, size: 40, color: t.ink3),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: t.ink, height: 1.25)),
        const SizedBox(height: 6),
        Text(text, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: t.ink2, height: 1.5)),
      ]),
    );
  }
}

class SectionHead extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? action;
  final VoidCallback? onAction;
  const SectionHead(this.title, {super.key, this.icon, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: t.pine),
          const SizedBox(width: 7),
        ],
        Expanded(child: Text(title, style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 18.5, color: t.ink, letterSpacing: -.3))),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.ember)),
          ),
      ]),
    );
  }
}

class Kv extends StatelessWidget {
  final String k;
  final String v;
  const Kv(this.k, this.v, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(k, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink3))),
        Expanded(child: Text(v, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: t.ink, height: 1.45))),
      ]),
    );
  }
}

class Prow extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
  const Prow(this.icon, this.title, {super.key, this.sub = '', this.onTap, this.trailing, this.danger = false});
  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Icon(icon, size: 21, color: danger ? C.bad : t.pine),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5,
                  color: danger ? C.bad : t.ink)),
              if (sub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(sub, style: TextStyle(fontSize: 12, color: t.ink3), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
            ])),
            if (trailing != null) trailing! else Icon(Icons.chevron_right, size: 20, color: t.ink3),
          ]),
        ),
      ),
    );
  }
}

class ProwBox extends StatelessWidget {
  final List<Widget> children;
  const ProwBox({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Container(
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) Divider(height: 1, color: t.line, indent: 47),
        ],
      ]),
    );
  }
}

// skeleton card placeholder
class Skel extends StatelessWidget {
  final double? h;
  final double? w;
  final double r;
  const Skel({super.key, this.h, this.w, this.r = 16});
  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Container(height: h, width: w,
        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(r)));
  }
}

// notice strip (web .notice) — kind: g green / o orange / r red
class Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final String kind;
  final Widget? richChild;
  const Notice(this.icon, this.text, {super.key, this.kind = 'g', this.richChild});
  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    final bg = switch (kind) { 'r' => t.dangerBg, 'o' => t.emberMist, _ => t.mist };
    final fg = switch (kind) { 'r' => C.bad, 'o' => C.emberDeep, _ => t.pineInk };
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: fg),
        const SizedBox(width: 10),
        Expanded(
          child: richChild ??
              Text(text, style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600, color: fg, height: 1.5)),
        ),
      ]),
    );
  }
}

// avatar with first letter
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final bool verified;
  const Avatar(this.name, {super.key, this.size = 42, this.verified = false});
  @override
  Widget build(BuildContext context) {
    final t = T(Theme.of(context).brightness);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: verified ? t.pine : t.soft2,
        border: Border.all(color: verified ? t.pine : t.line, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text((name.isNotEmpty ? name[0] : '?').toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * .42,
              color: verified ? Colors.white : t.ink2)),
    );
  }
}

// Crawlable listing page — /listing/123 returns real HTML with title, description,
// structured data and the listing facts, so Google can index every vacant house
// (the app itself lives on hash routes, which crawlers cannot reach one by one).
// Humans are offered a one-tap jump into the app.
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const kes = n => 'KES ' + Number(n || 0).toLocaleString('en-KE');
const base = 'https://homelinkke.pages.dev';
const appUrlFor = id => base + '/#/listing/' + id;

export async function onRequestGet({ env, params }) {
  const id = Number(Array.isArray(params.id) ? params.id[0] : params.id);
  const appUrl = appUrlFor(id || 0);
  if (!id || id < 1) return page('<h1>Listing not found</h1>', 'Listing not found — HuntInKE', 'The listing may have been taken down.', 404);
  const l = await env.DB.prepare(
    `SELECT l.id, l.title, l.ptype, l.rent, l.period, l.town, l.area, l.landmark, l.tags, l.units, l.unitsVacant,
            l.status, l.furnishing, l.water, l.createdAt, o.name AS owner, o.verify_status AS verified
     FROM listings l JOIN users o ON o.id = l.ownerId
     WHERE l.id = ? AND l.status != 'REMOVED'`).bind(id).first();
  if (!l) return page('<h1>Listing not found</h1><p>It may have been taken down.</p>', 'Listing not found — HuntInKE', 'The listing may have been taken down.', 404);

  const ph = await env.DB.prepare("SELECT COALESCE(NULLIF(thumb, ''), url) AS u FROM photos WHERE listingId = ? ORDER BY idx LIMIT 1").bind(id).first();
  const vacant = l.unitsVacant == null ? (l.status === 'TAKEN' ? 0 : Math.max(1, l.units || 1)) : Math.max(0, l.unitsVacant);
  const where = [l.town, l.area, l.landmark].filter(Boolean).join(', ');
  const title = `${l.title} — ${kes(l.rent)}/month in ${l.town} | HuntInKE`;
  const desc = `${l.ptype} for rent in ${where}. ${kes(l.rent)} ${String(l.period || 'Per Month').toLowerCase()}. ` +
    (vacant > 0 ? `${vacant} vacant ${vacant === 1 ? 'unit' : 'units'} now. ` : 'Currently occupied. ') +
    'Chat the landlord directly on HuntInKE — never pay before viewing.';
  const tags = String(l.tags || '').split(',').map(t => t.trim()).filter(Boolean);
  const per = String(l.period || 'Per Month').toLowerCase().replace('per ', '');

  const inner = `
<h1>${esc(l.title)}</h1>
<p class="price"><b>${kes(l.rent)}</b> / ${esc(per)} · ${vacant > 0 ? `${vacant} VACANT now` : 'all units occupied'}</p>
<p>${esc(l.ptype)} for rent in <b>${esc(where)}</b> · listed by ${esc(l.owner || 'landlord')}${l.verified === 'APPROVED' ? ' (verified)' : ''} on ${new Date(l.createdAt || Date.now()).toLocaleDateString('en-KE', { day: 'numeric', month: 'long', year: 'numeric' })}</p>
${ph && ph.u ? `<img src="${esc(ph.u)}" alt="${esc(l.title)} — ${esc(where)}" style="max-width:100%;border-radius:12px">` : ''}
<ul>
  <li>Type: ${esc(l.ptype)}</li>
  <li>Town: ${esc(l.town)}${l.area ? ' · ' + esc(l.area) : ''}</li>
  <li>Rent: ${kes(l.rent)} ${esc(per)}</li>
  <li>Furnishing: ${esc(l.furnishing || '—')}</li>
  <li>Water: ${esc(l.water || '—')}</li>
  <li>Vacant units: ${vacant > 0 ? vacant + ' of ' + Math.max(1, l.units || 1) : '0 — full'}</li>
</ul>
${tags.length ? `<p>Tags: ${tags.map(t => `<span>${esc(t)}</span>`).join(', ')}</p>` : ''}
<p><a class="cta" href="${appUrl}">Open this listing in HuntInKE — chat the landlord directly</a></p>
<p class="foot">HuntInKE lists vacant houses, bedsitters and apartments across Kenya. <a href="${base}/">Browse all houses for rent in Kenya</a>. Never pay any deposit before you have physically viewed the house and met the landlord.</p>`;

  const ld = {
    '@context': 'https://schema.org',
    '@type': 'RealEstateListing',
    name: l.title,
    url: appUrl,
    description: desc,
    datePosted: new Date(l.createdAt || Date.now()).toISOString(),
    image: ph && ph.u ? ph.u : undefined,
    address: { '@type': 'PostalAddress', addressLocality: l.town, addressRegion: l.area || undefined, addressCountry: 'KE' },
    offers: { '@type': 'Offer', price: l.rent, priceCurrency: 'KES', availability: vacant > 0 ? 'https://schema.org/InStock' : 'https://schema.org/SoldOut' },
  };
  return page(inner, title, desc, 200, ld, ph && ph.u ? ph.u : null);

  function page(body, t, d, code, ldJson, img) {
    const head = `<title>${esc(t || 'HuntInKE')}</title><meta name="description" content="${esc(d || '')}">` +
      `<link rel="canonical" href="${appUrl}"><meta property="og:title" content="${esc(t || '')}"><meta property="og:description" content="${esc(d || '')}">` +
      `<meta property="og:type" content="article"><meta property="og:url" content="${appUrl}">` +
      (img ? `<meta property="og:image" content="${esc(img)}">` : '') +
      (ldJson ? `<script type="application/ld+json">${JSON.stringify(ldJson)}</script>` : '');
    const doc = `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">${head}` +
      `<style>body{font-family:system-ui,-apple-system,sans-serif;max-width:640px;margin:0 auto;padding:18px;color:#1c241e;line-height:1.55}h1{font-size:22px}img{height:auto}ul{padding-left:20px}li{margin:4px 0}.price{font-size:17px}.cta{display:block;background:#0e5a33;color:#fff;padding:13px 16px;border-radius:12px;text-align:center;text-decoration:none;font-weight:700;margin:18px 0}.foot{font-size:12.5px;color:#5b6a5f}a{color:#0e5a33}</style>` +
      `</head><body>${body}</body></html>`;
    return new Response(doc, { status: code, headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'public, max-age=300' } });
  }
}

// Dynamic sitemap — home page + every available listing as its own crawlable URL
// (pairs with functions/listing/[id].js). Cloudflare Pages functions take
// precedence over the static public/sitemap.xml.
const esc = s => String(s == null ? '' : s).replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

export async function onRequestGet({ env }) {
  const base = 'https://homelinkke.pages.dev';
  const urls = [`<url><loc>${base}/</loc><changefreq>daily</changefreq><priority>1.0</priority></url>`];
  try {
    const rows = (await env.DB.prepare(
      "SELECT id, updatedAt FROM listings WHERE status = 'AVAILABLE' ORDER BY id DESC LIMIT 500").all()).results || [];
    for (const r of rows) {
      const lm = new Date(r.updatedAt || Date.now()).toISOString().slice(0, 10);
      urls.push(`<url><loc>${base}/listing/${r.id}</loc><lastmod>${lm}</lastmod><changefreq>weekly</changefreq><priority>0.8</priority></url>`);
    }
  } catch (e) { /* DB hiccup — ship the home page rather than an error page */ }
  return new Response(`<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls.join('')}</urlset>`, {
    headers: { 'content-type': 'application/xml; charset=utf-8', 'cache-control': 'public, max-age=1800' },
  });
}

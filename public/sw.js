/* HomeLinkKE service worker — network first, cache fallback (offline shell only) */
const CACHE = 'homelinkke-v1';
const CORE = ['/', '/styles.css', '/js/api.js', '/js/ui.js', '/js/maps.js', '/js/app.js', '/manifest.webmanifest', '/icons/icon-192.png', '/vendor/leaflet.css', '/vendor/leaflet.js'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin || url.pathname.startsWith('/api')) return;
  e.respondWith(
    fetch(e.request).then(r => {
      const cp = r.clone();
      caches.open(CACHE).then(c => c.put(e.request, cp)).catch(() => {});
      return r;
    }).catch(() => caches.match(e.request).then(m => m || caches.match('/')))
  );
});

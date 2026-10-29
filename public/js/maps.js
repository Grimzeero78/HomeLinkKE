// HomeLinkKE map engine — real Google Maps tiles on self-hosted Leaflet.
// Same accurate Google map everywhere (roads, estates, shops are all labelled),
// with NO API key and NO billing. Key properties:
//   1. HEALTHY SCROLLING — the map never hijacks the page:
//      · PC: the mouse wheel scrolls the page; hold Ctrl + scroll to zoom the map.
//      · Phone: swiping on an embedded map scrolls the page; pinch zooms the map.
//        Only the full-screen Explore map pans with one finger.
//   2. NO BLANK FLASHES — panning/zooming only streams new tiles; the map is
//      never reloaded (the old iframe version went blank on every move).
//   3. DRAGGABLE RED PIN — grab the pin and carry it smoothly, exactly like the
//      Google Maps app; the map even auto-pans when the pin nears the edge.
//   4. RESILIENT — if Google tiles are ever unreachable, the map silently swaps
//      to a backup style instead of showing a blank grid.

let _leafletP = null;
function loadLeaflet() {
  if (window.L) return Promise.resolve();
  if (_leafletP) return _leafletP;
  _leafletP = new Promise((resolve, reject) => {
    const css = document.createElement('link');
    css.rel = 'stylesheet'; css.href = '/vendor/leaflet.css';
    document.head.appendChild(css);
    const s = document.createElement('script');
    s.src = '/vendor/leaflet.js';
    s.onload = resolve;
    s.onerror = () => { _leafletP = null; reject(new Error('Could not load the map library — check your internet connection.')); };
    document.head.appendChild(s);
  });
  return _leafletP;
}

const coarse = () => window.matchMedia && window.matchMedia('(pointer: coarse)').matches;

const TILES = {
  googleRoads: { url: 'https://mt{s}.google.com/vt/lyrs=m&hl=en&x={x}&y={y}&z={z}&s=Ga', attr: 'Map data &copy; Google', sub: '0123' },
  googleHybrid: { url: 'https://mt{s}.google.com/vt/lyrs=y&hl=en&x={x}&y={y}&z={z}&s=Ga', attr: 'Map data &copy; Google', sub: '0123' },
  backupRoads: { url: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', attr: '&copy; OpenStreetMap &copy; CARTO', sub: 'abcd' },
  backupSat: { url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', attr: 'Imagery &copy; Esri', sub: 'abc' },
};

function addTiles(map, def, maxZoom) {
  const layer = L.tileLayer(def.url, {
    subdomains: def.sub, maxZoom: maxZoom ?? 21, maxNativeZoom: 20,
    attribution: def.attr, updateWhenIdle: false, keepBuffer: 4, detectRetina: false,
  }).addTo(map);
  // silent fallback if the primary tile source fails repeatedly
  let errs = 0, win = Date.now(), swapped = false;
  layer.on('tileerror', () => {
    errs++;
    if (swapped || errs < 10) return;
    if (Date.now() - win > 25000) { errs = 1; win = Date.now(); return; }
    swapped = true;
    const bak = def === TILES.googleRoads ? TILES.backupRoads : TILES.backupSat;
    map.eachLayer(l => { if (l instanceof L.TileLayer) map.removeLayer(l); });
    addTiles(map, bak, maxZoom);
    toast('Google map unreachable right now — switched to a backup map style.');
  });
  return layer;
}

// ---- icons -----------------------------------------------------------------
function redPinIcon(draggable) {
  return L.divIcon({
    className: 'gpin-i',
    html: `<div class="gpin-w${draggable ? ' draggable' : ''}"><div class="gpin"><i></i></div></div>`,
    iconSize: [26, 38], iconAnchor: [13, 37], popupAnchor: [0, -34],
  });
}
function priceIcon(rent, period) {
  const n = Number(rent || 0);
  const short = n >= 1000 ? (Math.round(n / 100) / 10).toString().replace(/\.0$/, '') + 'k' : n;
  return L.divIcon({
    className: 'gprice-i',
    html: `<div class="gprice">${short} <small>/${perShort(period)}</small></div>`,
    iconSize: [58, 26], iconAnchor: [29, 26],
  });
}

// ---- map factory -------------------------------------------------------------
// mode 'page' = embedded inside a scrolling page (listing, wizard): the page
//               always keeps priority — swipe/wheel scroll the page.
// mode 'map'  = dedicated full-screen map (Explore): one finger pans, like the
//               real Google Maps app.
function makeMap(el, opts = {}) {
  const o = {
    lat: opts.lat ?? KENYA_CENTER.lat, lng: opts.lng ?? KENYA_CENTER.lng,
    zoom: opts.zoom ?? 16, sat: !!opts.sat,
    mode: opts.mode || 'page',
    zoomMin: opts.zoomMin ?? 10, zoomMax: opts.zoomMax ?? 20,
  };
  const map = L.map(el, {
    center: [o.lat, o.lng], zoom: o.zoom,
    minZoom: o.zoomMin, maxZoom: o.zoomMax,
    zoomControl: false, attributionControl: true,
    scrollWheelZoom: false,                       // PC wheel must scroll the page
    dragging: o.mode === 'map' ? true : !coarse(), // phone swipe must scroll the page
    touchZoom: true, doubleClickZoom: true, boxZoom: false,
    keyboard: true, tap: true,
    zoomSnap: 0.5, inertia: true,
  });
  map.attributionControl.setPrefix(false);
  let cur = o.sat ? TILES.googleHybrid : TILES.googleRoads;
  let layer = addTiles(map, cur, o.zoomMax + 1);

  // controls: + / − / satellite, top-right (same look as before)
  const ctl = document.createElement('div');
  ctl.className = 'gmap-ctl';
  ctl.innerHTML = `<button type="button" class="gmap-btn" data-a="zi" aria-label="Zoom in">+</button>
    <button type="button" class="gmap-btn" data-a="zo" aria-label="Zoom out">&minus;</button>
    <button type="button" class="gmap-btn wide" data-a="sat" aria-label="Toggle satellite view">Satellite</button>`;
  el.appendChild(ctl);
  // control clicks must NEVER reach the map (otherwise tapping +/−/Satellite in
  // the picker would fire a map click and quietly move the pin to the corner)
  L.DomEvent.disableClickPropagation(ctl);
  L.DomEvent.disableScrollPropagation(ctl);
  ctl.querySelector('[data-a="zi"]').onclick = () => map.zoomIn();
  ctl.querySelector('[data-a="zo"]').onclick = () => map.zoomOut();
  const satBtn = ctl.querySelector('[data-a="sat"]');
  satBtn.textContent = o.sat ? 'Map' : 'Satellite';
  let sat = o.sat;
  satBtn.onclick = () => {
    sat = !sat;
    map.removeLayer(layer);
    cur = sat ? TILES.googleHybrid : TILES.googleRoads;
    layer = addTiles(map, cur, o.zoomMax + 1);
    satBtn.textContent = sat ? 'Map' : 'Satellite';
  };

  // Ctrl + scroll to zoom on PC (the Google way) — plain scroll keeps scrolling
  // the page. Show a one-time hint the first time someone scrolls without Ctrl.
  let ctrlT = null, hinted = 0;
  el.addEventListener('wheel', e => {
    if (e.ctrlKey || e.metaKey) {
      e.preventDefault();
      if (!map.scrollWheelZoom.enabled()) map.scrollWheelZoom.enable();
      clearTimeout(ctrlT);
      ctrlT = setTimeout(() => map.scrollWheelZoom.disable(), 900);
    } else if (!coarse() && hinted < 2) {
      hinted++;
      const h = document.createElement('div');
      h.className = 'gmap-hint';
      h.textContent = 'Hold Ctrl + scroll to zoom the map';
      el.appendChild(h);
      setTimeout(() => h.remove(), 1800);
    }
  }, { passive: false });

  return {
    map,
    get zoom() { return map.getZoom(); },
    setView(lat, lng, z, fly) {
      const f = fly ? { animate: true, duration: 0.6 } : undefined;
      map.setView([lat, lng], Math.max(o.zoomMin, Math.min(o.zoomMax, z ?? map.getZoom())), f);
    },
    fit(points, pad) {
      if (!points.length) return;
      if (points.length === 1) { map.setView(points[0], 17); return; }
      map.fitBounds(L.latLngBounds(points), { padding: pad || [42, 42], maxZoom: 17 });
    },
    setSat(on) { if (on !== sat) satBtn.click(); },
    destroy() { map.remove(); },
  };
}

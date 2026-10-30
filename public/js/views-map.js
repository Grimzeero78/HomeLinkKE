// HomeLinKE — Explore map: real Google Maps tiles (roads, estates, shops all
// labelled) with every pinned house shown as a price chip. Tap a house in the
// side list (or a pin on the map) to see its exact spot and open the listing.
// This page IS a map, so one finger pans the map here — but embedded maps
// (listing page, wizard) never hijack the page scroll.
const MAP_RADIUS = { '1': 1000, '3': 3000, '5': 5000, '10': 10000, '25': 25000, '': 0 };

async function viewMap() {
  const v = document.getElementById('view');
  const gen = routeGen;
  const myTown = getMyTown() || 'Kenya';
  v.innerHTML = `
    <div class="sec-h"><h2>Map of houses in Kenya</h2></div>
    <div class="map-search">
      <input class="inp" id="map-q" placeholder="Search a place — e.g. Kilimani, Nanyuki, Mombasa CBD" autocomplete="off">
      <button class="btn btn-primary btn-sm" id="map-go" type="button" style="flex:none">${ic('search')} Search</button>
    </div>
    <div style="display:flex;gap:7px;align-items:center;flex-wrap:wrap;margin:-2px 0 10px">
      <button class="btn btn-outline btn-sm" id="map-loc" type="button">${ic('pin')} Use my location</button>
      <span style="font-size:11.5px;color:var(--ink3)">Within:</span>
      <div class="chips" id="map-rad" style="display:flex;gap:6px;flex-wrap:wrap">
        ${Object.keys(MAP_RADIUS).map(r => `<button class="chip ${r === '' ? 'on' : ''}" data-r="${r}">${r ? r + ' km' : 'Any'}</button>`).join('')}
      </div>
    </div>
    <p class="hint-t" style="margin:-4px 0 10px">Live Google map — roads, estates and shops are all named. Tap a house below to fly to its exact spot, then use <b>Directions</b> in its listing to get there.</p>
    <div class="map-wrap">
      <div class="map-side" id="map-side">${skeletonGrid(2)}</div>
      <div id="mapbox" class="gmap-loading"><div class="gm-err">Loading map…</div></div>
    </div>`;

  const r = await api('/listings?limit=100&sort=new&bt=' + encodeURIComponent(getMyTown()));
  if (stale(gen)) return;
  let items = (r.ok && r.items) || [];
  renderSide(items);

  const box = v.querySelector('#mapbox');
  if (!box) return;
  let M = null;
  const markers = new Map();
  const start = getMyPos() || TOWNS.find(t => t.n === getMyTown()) || KENYA_CENTER;
  try {
    await loadLeaflet();
    if (stale(gen)) return;
    box.querySelector('.gm-err')?.remove();
    box.classList.remove('gmap-loading');
    M = makeMap(box, { lat: start.lat, lng: start.lng, zoom: getMyPos() ? 15 : (getMyTown() ? 13 : 7), zoomMin: 6, mode: 'map' });
    onLeave(() => { try { M.destroy(); } catch (e) {} M = null; });

    const addMarkers = list => {
      markers.forEach(m => m.remove()); markers.clear();
      list.filter(l => l.lat != null && l.lng != null).forEach(l => {
        const m = window.L.marker([l.lat, l.lng], { icon: priceIcon(l.rent, l.period), keyboard: false }).addTo(M.map);
        const dl = distLabel(l);
        m.bindPopup(`
          <div style="max-width:190px">
            <b>${esc(l.title)}</b><br>
            <span style="color:var(--ink2)">${kes(l.rent)}/${perShort(l.period)} · ${esc(l.town)}${l.area ? ' · ' + esc(l.area) : ''}${dl ? ' · ' + esc(dl) : ''}</span><br>
            <a href="#/listing/${l.id}">Open listing →</a>
          </div>`);
        m.on('click', () => highlightSide(l.id));
        markers.set(l.id, m);
      });
    };
    addMarkers(items);
    const pinned = items.filter(l => l.lat != null && l.lng != null);
    if (pinned.length && !getMyPos()) M.fit(pinned.map(l => [l.lat, l.lng]));
    setTimeout(() => M.map.invalidateSize(), 60);

    // radius chips filter what's shown, around the renter or around the searched place
    let center = getMyPos() || null, rad = '';
    const applyFilter = () => {
      if (!center || !rad) { addMarkers(items); renderSide(items); return; }
      const lim = MAP_RADIUS[rad];
      const inR = items.filter(l => l.lat != null && l.lng != null && distMeters(center, l) <= lim);
      addMarkers(inR); renderSide(inR);
      if (!inR.length) toast('No houses within ' + rad + ' km of this spot', true);
    };
    v.querySelectorAll('#map-rad .chip').forEach(c => c.onclick = () => {
      v.querySelectorAll('#map-rad .chip').forEach(x => x.classList.remove('on'));
      c.classList.add('on'); rad = c.dataset.r; applyFilter();
    });
    v.querySelector('#map-loc').onclick = () => askLocation(ok => {
      if (!ok || !M) return;
      const p = getMyPos();
      center = p; M.setView(p.lat, p.lng, 15, true); applyFilter();
    });
  } catch (e) {
    box.innerHTML = `<div class="gm-err"><div><b>Map failed to load.</b><br>
      <span style="margin-top:6px;display:inline-block">Check your internet connection and try again.</span></div></div>`;
  }

  function highlightSide(id) {
    v.querySelectorAll('#map-side [data-id]').forEach(a => a.classList.toggle('on', +a.dataset.id === id));
    const row = v.querySelector(`#map-side [data-id="${id}"]`);
    if (row && row.scrollIntoView) row.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  }

  function showOnMap(l) {
    if (l.lat == null || l.lng == null) { toast('This house is not pinned yet — ask the landlord in chat', true); return; }
    if (!M) return;
    M.setView(l.lat, l.lng, 18, true);
    const m = markers.get(l.id);
    if (m) setTimeout(() => m.openPopup(), 450);
    highlightSide(l.id);
  }

  function renderSide(list) {
    const side = v.querySelector('#map-side');
    if (!side) return;
    if (!list.length) { side.innerHTML = emptyBox('Nothing on the map yet', 'Pinned houses will appear here — try a bigger radius or another town.'); return; }
    side.innerHTML = list.map(l => {
      const boosted = l.boostedUntil && l.boostedUntil > Date.now();
      const pinned = l.lat != null && l.lng != null;
      const dl = pinned ? distLabel(l) : '';
      return `
      <div class="conv-row map-row ${pinned ? '' : 'nopin'}" data-id="${l.id}" tabindex="0" role="button" aria-label="Show ${esc(l.title)} on map">
        <div class="cph" style="width:56px;height:56px;border-radius:10px;overflow:hidden;flex:none;aspect-ratio:auto">
          ${l.thumb ? `<img src="${l.thumb}" style="width:100%;height:100%;object-fit:cover">` : `<div class="cph-empty">${ic('photo')}</div>`}
        </div>
        <div class="conv-main">
          <div class="conv-top"><span class="conv-name">${kes(l.rent)}/${perShort(l.period)}</span>
            ${boosted ? `<span class="pill pill-o">${ic('bolt')}Boost</span>` : ''}</div>
          <div class="conv-last">${esc(l.title)}</div>
          <div class="conv-sub"><span style="font-size:11.5px;color:var(--ink3)">${esc(l.town)}${l.area ? ' · ' + esc(l.area) : ''}${l.landmark ? ' · ' + esc(l.landmark) : ''}${dl ? ' · ' + esc(dl) : ''}</span>
            <a href="#/listing/${l.id}" class="mini-open">View</a></div>
        </div>
      </div>`;
    }).join('');
    side.querySelectorAll('.map-row').forEach(row => {
      const go = () => {
        const l = list.find(x => x.id === +row.dataset.id);
        if (l) showOnMap(l);
      };
      row.addEventListener('click', go);
      row.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); go(); } });
    });
  }

  // search: Kenya towns first (instant), Nominatim (bounded to Kenya) as fallback
  const doSearch = async () => {
    const q = v.querySelector('#map-q').value.trim();
    if (!q) return;
    go.disabled = true;
    const hit = await searchPlaces(q);
    go.disabled = false;
    if (!hit) { toast('Place not found — try a town name, estate or road', true); return; }
    if (M) { M.setView(hit.lat, hit.lng, 15, true); center = { lat: hit.lat, lng: hit.lng }; applyFilter(); }
    v.querySelectorAll('#map-side .map-row.on').forEach(a => a.classList.remove('on'));
  };
  const go = v.querySelector('#map-go');
  go.onclick = doSearch;
  v.querySelector('#map-q').addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); doSearch(); } });
}

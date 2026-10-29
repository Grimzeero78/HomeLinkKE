// HomeLinkKE — Listing detail, Favourites, Privacy
let VIEWED = JSON.parse(localStorage.getItem('hl_viewed') || '[]');

async function viewListing(id) {
  const v = document.getElementById('view');
  const gen = routeGen;
  v.innerHTML = `<div class="skel" style="aspect-ratio:4/3;border-radius:16px"></div>
    <div class="skel" style="height:26px;margin-top:14px;width:70%"></div>
    <div class="skel" style="height:120px;margin-top:12px"></div>`;

  const r = await api('/listings/' + id);
  if (stale(gen)) return; // navigated away while loading
  if (!r.ok) { v.innerHTML = emptyBox('Listing not found', r.error || 'It may have been removed.'); return; }
  const l = r.listing, photos = r.photos || [];

  if (!VIEWED.includes(id)) { VIEWED.push(id); localStorage.setItem('hl_viewed', JSON.stringify(VIEWED)); api('/listings/' + id + '/view', { method: 'POST' }); }

  const isFav = await (async () => {
    if (!state.user) return false;
    const f = await api('/my/favorites');
    return f.ok && f.items.some(x => x.id === l.id);
  })();
  if (stale(gen)) return; // still fresh? the favorites fetch can also race a navigation
  const canContact = !!state.user;
  const verified = l.ownerVerify === 'APPROVED';
  const boosted = l.boostedUntil && l.boostedUntil > Date.now();
  const coords = l.lat != null && l.lng != null;
  const dl = distLabel(l);
  const gmapsLink = coords ? `https://www.google.com/maps/search/?api=1&query=${l.lat},${l.lng}` : null;
  const dirLink = coords ? `https://www.google.com/maps/dir/?api=1&destination=${l.lat},${l.lng}` : null;
  const contactNum = l.contactPhone || l.ownerPhone || '';
  const kv = (k, val) => val ? `<div class="kv"><span class="k">${k}</span><span class="v">${val}</span></div>` : '';
  const y = v2 => v2 === 'Yes' ? v2 : esc(v2);

  v.innerHTML = `
  <div class="detail-cols">
    <div class="detail-main">
      ${r.isOwner && !boosted ? `<div class="notice notice-o" style="margin-bottom:10px">${ic('bolt')}<span><b>This is your listing.</b> Get seen first in ${esc(l.town || 'your town')} — <a href="#/boost/${l.id}" style="text-decoration:underline">Boost it for KES ${BOOST.amountKes} / ${BOOST.days} days</a>. Renters browsing ${esc(l.town || 'your town')} will see it on top.</span></div>` : ''}
      ${r.isOwner && !verified ? `<div class="notice notice-g" style="margin-bottom:10px">${ic('shield')}<span>Earn the green <b>Verified landlord</b> badge and post up to 5 listings — <a href="#/profile" style="text-decoration:underline">verify in your Profile</a>.</span></div>` : ''}
      ${photos.length ? `
      <div class="gallery">
        <span class="wm" style="z-index:2"></span>
        <img id="gal-img" src="${photos[0].url}" alt="${esc(l.title)}">
        ${photos.length > 1 ? `
          <button class="gal-nav prev" id="gal-prev" aria-label="Previous photo">${ic('back')}</button>
          <button class="gal-nav next" id="gal-next" aria-label="Next photo" style="transform:translateY(-50%) scaleX(-1)">${ic('back')}</button>
          <div class="gal-count" id="gal-count">1/${photos.length}</div>` : ''}
      </div>
      <div class="gal-thumbs">${photos.map((p, i) => `<img src="${p.url}" data-i="${i}" class="${i === 0 ? 'on' : ''}" alt="">`).join('')}</div>` : ''}
      <div class="dhead">
        <div class="dprice">${kes(l.rent)}<span> /${perShort(l.period).replace('sem', 'semester').replace('yr', 'year').replace('mo', 'month')}</span></div>
        <div class="dtitle">${esc(l.title)}</div>
        <div class="dmeta">${ic('pin')} ${esc(l.town || 'Kenya')}${l.area ? ' · ' + esc(l.area) : ''}${l.landmark ? ' · ' + esc(l.landmark) : ''}${dl ? ` · <b style="color:var(--pine-accent)">${esc(dl)}</b>` : ''}</div>
        <div style="display:flex;gap:7px;margin-top:9px;flex-wrap:wrap">
          ${boosted ? `<span class="pill pill-o">${ic('bolt')}Boosted</span>` : ''}
          ${verified ? `<span class="pill pill-g">${ic('shield')}Verified landlord</span>` : ''}
          <span class="pill ${l.status === 'AVAILABLE' ? 'pill-g' : 'pill-x'}">${l.status === 'AVAILABLE' ? 'Available' : 'Taken'}</span>
          <span class="pill pill-x">${ic('eye')}${l.views} views</span>
        </div>
        <div class="dacts">
          <button class="btn btn-outline btn-sm" id="btn-fav">${ic('heart')} ${isFav ? 'Saved' : 'Save'}</button>
          <button class="btn btn-outline btn-sm" id="btn-share">${ic('send')} Share</button>
          <button class="btn btn-outline btn-sm" id="btn-report">${ic('flag')} Report</button>
        </div>
        ${!r.isOwner ? `<div class="notice notice-r" style="margin-top:12px">${ic('shield')}<span><b>Never pay before viewing.</b> Visit the house and meet the landlord or caretaker in person before sending any deposit — M-Pesa or cash.</span></div>` : ''}
      </div>

      <div class="sec-block"><h3>Key facts</h3><div class="dgrid">
        <div class="dcell"><div class="k">Type</div><div class="v">${esc(l.ptype)}</div></div>
        <div class="dcell"><div class="k">Units in compound</div><div class="v">${l.units}</div></div>
        <div class="dcell"><div class="k">Furnishing</div><div class="v">${esc(l.furnishing)}</div></div>
        <div class="dcell"><div class="k">Floor</div><div class="v">${esc(l.floor)}</div></div>
        <div class="dcell"><div class="k">Road access</div><div class="v">${esc(l.road)}</div></div>
        <div class="dcell"><div class="k">Available from</div><div class="v">${fmtAvail(l.availableFrom)}</div></div>
      </div></div>

      <div class="sec-block"><h3>Location</h3>
        ${coords ? `
        <div id="lmap" style="height:300px"></div>
        <p class="hint-t" style="margin-top:7px">Live Google Maps — every road, estate and shop is named. Tap <b>Satellite</b> (button on the map) to see the compound and gate clearly.</p>
        <div style="display:flex;gap:8px;margin-top:10px;flex-wrap:wrap">
          <a class="btn btn-outline btn-sm" target="_blank" rel="noopener" href="${gmapsLink}">${ic('pin')} Open in Google Maps</a>
          <a class="btn btn-outline btn-sm" target="_blank" rel="noopener" href="${dirLink}">${ic('send')} Directions</a>
        </div>` : `<p class="hint-t">The landlord has not pinned this property on the map yet. Ask for directions in the chat.</p>`}
      </div>

      <div class="sec-block"><h3>Utilities</h3>
        ${kv('Water', esc(l.water) + (l.waterCost && l.water !== 'Included in rent' ? ' · ' + esc(l.waterCost) : ''))}
        ${l.water === 'Rationed' && l.waterSched ? kv('Water schedule', esc(l.waterSched)) : ''}
        ${kv('Storage tank', y(l.waterTank))}
        ${kv('Electricity', esc(l.elec) + (l.elecCost && !['Included in rent', 'Own token meter', 'Prepaid'].includes(l.elec) ? ' · ' + esc(l.elecCost) : ''))}
        ${kv('WiFi', esc(l.wifi) + (l.wifiCost && l.wifi === 'Available but paid separately' ? ' · ' + esc(l.wifiCost) : '') + (l.wifiProvider ? ' (' + esc(l.wifiProvider) + ')' : ''))}
        ${kv('Garbage', esc(l.garbage))}
        ${kv('Backup power', esc(l.backup))}
      </div>

      <div class="sec-block"><h3>Inside the unit</h3>
        ${/^\d/.test(l.bath || '') ? kv('Bathrooms', esc(l.bath)) : ''}
        ${(l.ensuite === 'Yes' || l.bath === 'Ensuite (own)') ? kv('Own bathroom', 'Yes — en-suite') : ''}
        ${(l.kitchen === 'Yes' || l.kitchen === 'Own') ? kv('Own kitchen', 'Yes, inside the unit') : ''}
        ${l.parking === 'Yes' ? kv('Parking', 'Available') : ''}
        ${kv('Balcony', y(l.balcony))}
        ${kv('Floor finish', y(l.tile))}
        ${kv('Ceiling', y(l.ceiling))}
        ${l.wardrobe === 'Yes' ? kv('Wardrobes', 'Built-in') : ''}
        ${kv('Hot shower', y(l.hotShower))}
      </div>

      <div class="sec-block"><h3>Security & tenants</h3>
        <div class="chips" style="margin-bottom:10px">
          ${(parseSecurity(l.security).length ? parseSecurity(l.security) : ['Not specified']).map(s => `<span class="chip" style="pointer-events:none">${esc(s)}</span>`).join('')}
        </div>
        ${kv('Preferred tenants', esc(l.tenantPref || 'Anyone'))}
        ${kv('Pets', y(l.pets))}
      </div>

      <div class="sec-block"><h3>Pricing & terms</h3>
        ${kv('Rent', kes(l.rent) + ' / ' + esc((l.period || '').toLowerCase()))}
        ${l.deposit ? kv('Deposit', kes(l.deposit)) : ''}
        ${kv('Move-in fees', esc(l.fees || 'None'))}
        ${kv('Negotiable', l.negotiable ? 'Yes' : 'No')}
        ${l.terms ? `<p style="font-size:13.5px;color:var(--ink2);margin-top:8px">${esc(l.terms)}</p>` : ''}
      </div>

      <div id="similar-box"></div>
    </div>

    <div class="detail-side">
      <div class="owner-card">
        <div class="owner-row">
          <div class="avatar ${verified ? '' : 'lv'}">${esc((l.ownerName || l.ownerUsername || '?')[0].toUpperCase())}</div>
          <div>
            <div class="nm">${esc(l.ownerName || l.ownerUsername)} ${verified ? ic('shield') : ''}</div>
            <div class="sb">Landlord · joined ${fmtDate(l.ownerSince)}</div>
          </div>
        </div>
        ${verified ? '' : `<div class="notice notice-o" style="margin-top:11px;font-size:12.5px">${ic('flag')}<span>This landlord is not verified yet. Always view the room in person before paying anything.</span></div>`}
        <div class="contact-btns">
          <a class="btn btn-green ${canContact ? '' : 'need-auth'}" ${canContact ? `href="tel:${esc(contactNum)}"` : 'href="#/login"'}>
            ${ic('phone')} Call</a>
          <a class="btn btn-primary ${canContact ? '' : 'need-auth'}" ${canContact ? `target="_blank" rel="noopener" href="${waLink(contactNum, 'Hi! I saw your listing “' + l.title + '” on HomeLinkKE. Is it still available?')}"` : 'href="#/login"'}>
            ${ic('wa')} WhatsApp</a>
        </div>
        <button class="btn btn-outline btn-block" id="btn-msg" style="margin-top:8px">${ic('chat')} Message in app</button>
        <p class="hint-t" style="margin-top:10px">${ic('shield')} Never send a deposit before viewing the room in person.</p>
      </div>
    </div>
  </div>`;

  // gallery
  if (photos.length > 1) {
    let gi = 0;
    const show = i => {
      gi = (i + photos.length) % photos.length;
      v.querySelector('#gal-img').src = photos[gi].url;
      v.querySelector('#gal-count').textContent = (gi + 1) + '/' + photos.length;
      v.querySelectorAll('.gal-thumbs img').forEach((t, ti) => t.classList.toggle('on', ti === gi));
    };
    v.querySelector('#gal-prev').onclick = () => show(gi - 1);
    v.querySelector('#gal-next').onclick = () => show(gi + 1);
    v.querySelectorAll('.gal-thumbs img').forEach(t => t.onclick = () => show(+t.dataset.i));
    v.querySelector('#gal-img').onclick = () => lightbox(photos[gi].url);
  } else if (photos.length === 1) {
    v.querySelector('#gal-img').onclick = () => lightbox(photos[0].url);
  }

  v.querySelectorAll('.gallery img, .gal-thumbs img').forEach(el => { el.style.cursor = 'zoom-in'; });

  // location map — the SAME Google map the landlord pinned the spot on in the
  // create/edit wizard, so what students see is exactly what was pinned.
  if (coords) {
    const el = document.getElementById('lmap');
    if (el) {
      loadLeaflet().then(() => {
        const m = makeMap(el, { lat: l.lat, lng: l.lng, zoom: 17, zoomMin: 10, mode: 'page' });
        L.marker([l.lat, l.lng], { icon: redPinIcon(false), keyboard: false }).addTo(m.map)
          .bindPopup(`<b>${esc(l.title)}</b><br><span style="color:var(--ink2)">${esc(l.area)}${l.landmark ? ' · ' + esc(l.landmark) : ''}</span>`);
        setTimeout(() => m.map.invalidateSize(), 60);
        onLeave(() => { try { m.destroy(); } catch (e) {} });
      }).catch(() => {
        el.innerHTML = '<div class="gm-err"><div><b>Map failed to load.</b><br><span style="margin-top:6px;display:inline-block">Check your internet connection and refresh.</span></div></div>';
      });
    }
  }

  // actions
  v.querySelector('#btn-fav').onclick = async () => {
    if (!state.user) { location.hash = '#/login'; return; }
    const res = await api('/favorites/' + l.id, { method: 'POST' });
    if (res.ok) { v.querySelector('#btn-fav').innerHTML = `${ic('heart')} ${res.on ? 'Saved' : 'Save'}`; toast(res.on ? 'Saved to favourites' : 'Removed from favourites'); }
    else toast(res.error, true);
  };
  v.querySelector('#btn-share').onclick = async () => {
    const url = location.href;
    if (navigator.share) { try { await navigator.share({ title: l.title, url }); } catch {} }
    else { try { await navigator.clipboard.writeText(url); toast('Link copied'); } catch {} }
  };
  v.querySelector('#btn-report').onclick = () => openReport(l.id);
  v.querySelector('#btn-msg').onclick = async () => {
    if (!state.user) { location.hash = '#/login'; return; }
    const res = await api('/convs', { body: { listingId: l.id } });
    if (res.ok) location.hash = '#/chat/' + res.id;
    else toast(res.error, true);
  };

  // similar
  if (r.similar && r.similar.length) {
    document.getElementById('similar-box').innerHTML = `<div class="sec"><div class="sec-h"><h2>Similar houses</h2></div>
      <div class="grid">${r.similar.map(listingCard).join('')}</div></div>`;
  }
}

async function viewFavorites() {
  const v = document.getElementById('view');
  const gen = routeGen;
  v.innerHTML = `<div class="sec-h"><h2>Favourites</h2></div>${skeletonGrid(3)}`;
  const r = await api('/my/favorites');
  if (stale(gen)) return;
  if (!r.ok) { v.innerHTML = emptyBox('Sign in required', 'Sign in to see your saved rooms.'); return; }
  v.innerHTML = r.items.length
    ? `<div class="sec-h"><h2>Favourites</h2></div><div class="grid">${r.items.map(listingCard).join('')}</div>`
    : emptyBox('No favourites yet', 'Tap the Save button on any listing to keep it here.');
}

function viewPrivacy() {
  document.getElementById('view').innerHTML = `
  <div class="sec-h"><h2>Privacy & safety</h2></div>
  <div class="sec-block">
    <h3>What we store</h3>
    <p style="font-size:13.5px;color:var(--ink2);margin-bottom:10px">Your username, name, phone/WhatsApp number, role, and — for landlords — the verification documents you upload. Listing photos and details you post. Chat messages you send. Nothing else. No email, no tracking pixels.</p>
    <h3>Who can see it</h3>
    <p style="font-size:13.5px;color:var(--ink2);margin-bottom:10px">Listing content is public. Your phone number is shown to signed-in users on your listings and in chats so renters can reach you. Your verification documents are only visible to the admin. Chats are only visible to you and the other person. If you share your location, it stays on your device — it is never sent to our servers.</p>
    <h3>The golden rule</h3>
    <p style="font-size:13.5px;color:var(--ink2);margin-bottom:10px">HomeLinkKE never collects rent, deposit, or any payment. All money matters happen face-to-face after a viewing. If anyone asks you to pay through the app or before a viewing, report them.</p>
    <h3>Data Protection Act (Kenya, 2019)</h3>
    <p style="font-size:13.5px;color:var(--ink2)">We collect the minimum data needed to run the service. You may ask for your data to be deleted at any time — contact the site admin.</p>
  </div>`;
}

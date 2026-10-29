// HomeLinkKE — 8-step create/edit listing wizard
const LBLANK = () => ({
  title: '', ptype: 'Bedsitter', units: 1, furnishing: 'Unfurnished', floor: 'Ground',
  town: '', area: '', landmark: '', lat: null, lng: null, road: 'Tarmac',
  rent: '', period: 'Per Month', deposit: '', fees: 'None', negotiable: false, terms: '',
  water: 'Included in rent', waterCost: '', waterSched: '', waterTank: 'No',
  elec: 'Own token meter', elecCost: '', wifi: 'Not available', wifiCost: '', wifiProvider: '',
  garbage: 'Included', backup: 'None',
  bath: 'Shared', kitchen: 'Shared', cooking: 'Yes', balcony: 'No', tile: 'Tiled', ceiling: 'Yes',
  wardrobe: 'No', bed: 'No', desk: 'No',
  security: [], gender: 'Mixed', curfewOn: 'No', curfewTime: '', visitors: 'Daytime only', alcohol: 'No',
  availableFrom: 'Available now', contactPhone: '', photos: [], thumbs: [],
});

const WIZ_STEPS = ['Basics', 'Location', 'Pricing', 'Utilities', 'Room', 'Rules', 'Availability', 'Photos'];

async function viewCreate(id) {
  if (!state.user) { location.hash = '#/login'; return; }
  if (state.user.role !== 'LANDLORD') {
    document.getElementById('view').innerHTML = emptyBox('Landlords only',
      'Only landlord accounts can post listings. Create a landlord account to list your rooms.');
    return;
  }
  const v = document.getElementById('view');
  const gen = routeGen; // if the user navigates away mid-fetch, don't paint over the new page
  let L = LBLANK();
  let editingId = null;

  if (id) {
    v.innerHTML = `<div class="pageload"><div class="skel" style="height:200px"></div><div class="skel" style="height:60px"></div></div>`;
    const r = await api('/listings/' + id);
    if (stale(gen)) return;
    if (!r.ok || !r.isOwner) { v.innerHTML = emptyBox('Cannot edit', r.error || 'Not your listing.'); return; }
    L = { ...L, ...r.listing, security: parseSecurity(r.listing.security),
      photos: (r.photos || []).map(p => p.url), thumbs: (r.photos || []).map(p => p.thumb || '') };
    editingId = id;
  }
  let step = 0;
  let pickMap = null; // leaflet instance is destroyed before the wizard re-renders the step

  const yesNo = (k, label) => `
    <label class="lbl">${label}</label>
    <div class="seg" data-k="${k}"><button type="button" data-v="No" class="${L[k] !== 'Yes' ? 'on' : ''}">No</button><button type="button" data-v="Yes" class="${L[k] === 'Yes' ? 'on' : ''}">Yes</button></div>`;
  const sel = (k, label, opts, hint) => `
    <label class="lbl">${label}</label>
    <select class="inp" data-k="${k}">${opts.map(o => `<option ${L[k] === o ? 'selected' : ''}>${esc(o)}</option>`).join('')}</select>
    ${hint ? `<p class="hint-t">${hint}</p>` : ''}`;
  const txt = (k, label, ph, type = 'text') => `
    <label class="lbl">${label}</label>
    <input class="inp" data-k="${k}" type="${type}" ${type === 'number' ? 'min="0"' : ''} placeholder="${esc(ph || '')}" value="${esc(L[k] == null ? '' : L[k])}">`;

  const STEPS = [
    { t: 'Property basics', html: () => `
      ${txt('title', 'Listing title', 'e.g. Spacious 1 Bedroom — Kilimani')}
      ${sel('ptype', 'Property type', TYPES)}
      <label class="lbl">Town <span style="font-weight:500">(renters browse and search by town)</span></label>
      <select class="inp" data-k="town">
        <option value="" ${L.town ? '' : 'selected'} disabled>Choose the town…</option>
        ${TOWNS.map(t => `<option ${L.town === t.n ? 'selected' : ''}>${esc(t.n)}</option>`).join('')}
      </select>
      <p class="hint-t">Boosts are also targeted to this town — renters browsing ${esc(L.town || 'your town')} see boosted houses on top.</p>
      ${txt('units', 'Total units in the compound', 'e.g. 6', 'number')}
      ${sel('furnishing', 'Furnishing', FURN)}
      ${sel('floor', 'Floor', FLOORS)}` },
    { t: 'Location', html: () => `
      ${txt('area', 'Estate / area (optional)', 'e.g. Kilimani, Section 9, Milimani')}
      ${txt('landmark', 'Nearest landmark (optional)', 'e.g. opposite Naivas, near the stage')}
      ${sel('road', 'Road access', ROADS)}
      <div class="sec-block" style="margin-top:14px;padding:13px">
        <h3 style="font-size:14.5px">${ic('pin')} Pin the exact spot on Google Maps</h3>
        <p class="hint-t">Drag the red pin to your compound gate — or tap the map and the pin jumps there. This is the same Google map renters see on your listing. Switch to <b>Satellite</b> to see houses and gates clearly.</p>
        <div id="pick-map" style="margin-top:10px;height:300px"></div>
        <div style="display:flex;gap:8px;margin-top:10px">
          <input class="inp" id="pick-q" placeholder="Search a place, e.g. ${esc(L.town || 'Nanyuki')}" autocomplete="off">
          <button class="btn btn-outline btn-sm" id="pick-go" type="button" style="flex:none">${ic('search')} Search</button>
        </div>
        <div style="display:flex;gap:8px;margin-top:10px;flex-wrap:wrap">
          <button class="btn btn-outline btn-sm" id="pick-gps" type="button">${ic('pin')} Use my current location</button>
        </div>
        <div style="display:flex;gap:8px;margin-top:8px">
          <input class="inp" id="pick-lat" placeholder="(optional) lat" value="${L.lat ?? ''}">
          <input class="inp" id="pick-lng" placeholder="(optional) lng" value="${L.lng ?? ''}">
        </div>
        <p class="hint-t" id="pick-walk" style="margin-top:8px"></p>
      </div>` },
    { t: 'Pricing', html: () => `
      ${txt('rent', 'Rent (KES)', 'e.g. 6500', 'number')}
      ${sel('period', 'Payment period', PERIODS)}
      ${txt('deposit', 'Deposit (KES) — optional', 'e.g. 6500 — leave empty if none', 'number')}
      ${txt('fees', 'Move-in fees (optional)', 'e.g. Water connection KES 500 — or "None"')}
      <label class="check"><input type="checkbox" id="w-neg" ${L.negotiable ? 'checked' : ''}> Rent is negotiable</label>
      <label class="lbl">Payment terms & house rules (optional)</label>
      <textarea class="inp" data-k="terms" placeholder="e.g. Rent due by 5th of the month. One month deposit."> ${esc(L.terms)}</textarea>` },
    { t: 'Utilities', html: () => `
      ${sel('water', 'Water', WATER)}
      <div id="w-wcost">${txt('waterCost', 'Water cost', 'e.g. KES 200 per month or per jerrican — optional')}</div>
      <div id="w-sched-box">${txt('waterSched', 'Water schedule (if rationed)', 'e.g. Tuesday & Friday evenings')}</div>
      ${yesNo('waterTank', 'Has storage tank / backup tank?')}
      ${sel('elec', 'Electricity', ELEC)}
      <div id="w-ecost">${txt('elecCost', 'Electricity cost', 'e.g. KES 300 per week, shared — optional')}</div>
      <p class="hint-t">Own token meter? Leave the cost empty — each tenant buys their own tokens.</p>
      ${sel('wifi', 'WiFi / internet', WIFI)}
      <div id="w-wificost">${txt('wifiCost', 'WiFi cost', 'e.g. KES 300 per month shared — optional')}</div>
      ${txt('wifiProvider', 'WiFi provider (optional)', 'e.g. Faiba, Safaricom, Starlink')}
      ${sel('garbage', 'Garbage disposal', GARBAGE)}
      ${sel('backup', 'Backup power', BACKUP)}` },
    { t: 'Room & building', html: () => `
      ${sel('bath', 'Bathroom', BATH)}
      ${sel('kitchen', 'Kitchen', KITCHEN)}
      ${sel('cooking', 'Cooking allowed', ['Yes', 'No', 'Outside kitchen only'])}
      ${yesNo('balcony', 'Balcony?')}
      ${sel('tile', 'Floor finish', ['Tiled', 'Not tiled'])}
      ${yesNo('ceiling', 'Ceiling board?')}
      ${yesNo('wardrobe', 'Wardrobe provided?')}
      ${yesNo('bed', 'Bed provided?')}
      ${yesNo('desk', 'Study desk provided?')}` },
    { t: 'Security & rules', html: () => `
      <label class="lbl">Security (choose all that apply)</label>
      <div class="chips" id="w-sec">${SECURITY.map(s => `<button type="button" class="chip ${L.security.includes(s) ? 'on' : ''}" data-v="${esc(s)}">${esc(s)}</button>`).join('')}</div>
      ${sel('gender', 'Gender policy', GENDER)}
      ${yesNo('curfewOn', 'Is there a curfew?')}
      <div id="w-curfew-box">${txt('curfewTime', 'Curfew time', 'e.g. 10:30 PM')}</div>
      ${sel('visitors', 'Visitors allowed?', VISITORS)}
      ${yesNo('alcohol', 'Alcohol allowed in the compound?')}` },
    { t: 'Availability & contact', html: () => `
      <label class="lbl">Available from</label>
      <select class="inp" id="w-avail">${AVAIL_OPTIONS.map(o => `<option ${L.availableFrom === o || (!AVAIL_OPTIONS.includes(L.availableFrom) && o === 'Available now' && !L.availableFrom) ? 'selected' : ''}>${esc(o)}</option>`).join('')}</select>
      <div id="w-avail-date" style="display:none">
        <input class="inp" type="date" data-k="availableFrom" value="${/^\d{4}-\d{2}-\d{2}/.test(L.availableFrom || '') ? esc(L.availableFrom) : ''}">
      </div>
      <p class="hint-t">Pick "Available now" if the room is vacant today.</p>
      ${txt('contactPhone', 'Contact phone / WhatsApp (optional)', 'Defaults to your profile number')}
      <div class="notice notice-g" style="margin-top:14px">${ic('shield')}<span>Your number is only shown to signed-in users. HomeLinkKE never collects any payment on your behalf.</span></div>` },
    { t: 'Photos & publish', html: () => `
      <label class="lbl">Photos (3–8) — first photo is the cover</label>
      <div class="photo-grid" id="w-photos"></div>
      <input type="file" id="w-file" accept="image/*" multiple hidden>
      <p class="hint-t" style="margin-top:8px">Photos are compressed in your browser before upload. Add clear daylight photos — listings with good photos get 3× more chats.</p>
      <div class="sec-block" style="margin-top:14px"><h3>Review</h3><div id="w-review"></div></div>` },
  ];

  function render() {
    const st = STEPS[step];
    v.innerHTML = `
      <div class="wiz-progress">
        <span class="wiz-step">Step ${step + 1}/8</span>
        <div class="wiz-bar"><i style="width:${((step + 1) / 8) * 100}%"></i></div>
        <span class="wiz-step">${esc(st.t)}</span>
      </div>
      <div class="wiz-steps">${WIZ_STEPS.map((nm, i) =>
        `<button type="button" class="ws ${i === step ? 'on' : (i < step ? 'done' : '')}" data-step="${i}" aria-label="Go to section ${i + 1}: ${esc(nm)}"><b>${i + 1}</b> ${esc(nm)}</button>`).join('')}</div>
      <div class="wiz-card"><h2>${esc(st.t)}</h2><div id="wiz-fields">${st.html()}</div>
        ${editingId && step < 7 ? `<button class="btn btn-outline btn-block" id="wz-save" style="margin-top:14px">${ic('check')} Save changes now</button>
        <p class="hint-t" style="margin-top:6px">Editing — jump to any section above and save from there. No need to walk through all 8 steps.</p>` : ''}
        <div class="wiz-nav">
          ${step > 0 ? '<button class="btn btn-outline" id="wz-back">Back</button>' : '<button class="btn btn-outline" id="wz-cancel">Cancel</button>'}
          <button class="btn btn-green" id="wz-next">${step === 7 ? (editingId ? 'Save changes' : 'Publish listing') : 'Next'}</button>
        </div>
      </div>`;

    // tappable section chips — jump straight to the section you want (e.g. straight to
    // section 5 when editing). Moving BACK is always free; moving forward first checks
    // the fields on the section you are leaving so required data is never skipped.
    v.querySelectorAll('.ws').forEach(b => b.onclick = () => {
      const t = +b.dataset.step;
      if (t === step) return;
      if (t > step) {
        const err = validate(step);
        if (err) { toast(err, true); window.scrollTo({ top: 0, behavior: 'smooth' }); return; }
      }
      step = t; render(); window.scrollTo({ top: 0 });
    });

    // bind generic inputs
    v.querySelectorAll('[data-k]').forEach(el => {
      const k = el.dataset.k;
      const ev = el.tagName === 'SELECT' || el.type === 'date' ? 'change' : 'input';
      // a select always LOOKS selected — adopt its visible value so validation matches what the user sees
      if (el.tagName === 'SELECT' && !L[k]) L[k] = el.value;
      el.addEventListener(ev, () => { L[k] = el.value; });
    });
    v.querySelectorAll('.seg[data-k]').forEach(seg => seg.querySelectorAll('button').forEach(b => b.onclick = () => {
      seg.querySelectorAll('button').forEach(x => x.classList.remove('on'));
      b.classList.add('on'); L[seg.dataset.k] = b.dataset.v;
    }));
    const neg = v.querySelector('#w-neg'); if (neg) neg.onchange = () => { L.negotiable = neg.checked; };
    // ---- utilities: conditional cost fields ----
    const wcostBox = v.querySelector('#w-wcost'), ecostBox = v.querySelector('#w-ecost'), wificostBox = v.querySelector('#w-wificost');
    const wsel = v.querySelector('[data-k="water"]'), esel = v.querySelector('[data-k="elec"]'), wifisel = v.querySelector('[data-k="wifi"]');
    const syncUtilBoxes = () => {
      if (wcostBox) wcostBox.style.display = L.water === 'Included in rent' ? 'none' : '';
      if (ecostBox) ecostBox.style.display = (L.elec === 'Included in rent' || L.elec === 'Own token meter' || L.elec === 'Prepaid') ? 'none' : '';
      if (wificostBox) wificostBox.style.display = L.wifi === 'Available but paid separately' ? '' : 'none';
    };
    syncUtilBoxes();
    if (wsel) wsel.addEventListener('change', syncUtilBoxes);
    if (esel) esel.addEventListener('change', syncUtilBoxes);
    if (wifisel) wifisel.addEventListener('change', syncUtilBoxes);
    const schedBox = v.querySelector('#w-sched-box');
    if (schedBox) { schedBox.style.display = L.water === 'Rationed' ? '' : 'none'; if (wsel) wsel.addEventListener('change', () => schedBox.style.display = L.water === 'Rationed' ? '' : 'none'); }
    const cfBox = v.querySelector('#w-curfew-box'); if (cfBox) cfBox.style.display = L.curfewOn === 'Yes' ? '' : 'none';
    const co = v.querySelector('[data-k="curfewOn"]'); if (co) co.addEventListener('click', () => setTimeout(() => cfBox.style.display = L.curfewOn === 'Yes' ? '' : 'none', 0));
    // ---- availability: preset options, date only when picked ----
    const availSel = v.querySelector('#w-avail'), availDate = v.querySelector('#w-avail-date');
    if (availSel && availDate) {
      if (/^\d{4}-\d{2}-\d{2}/.test(L.availableFrom || '')) availSel.value = 'Pick a date…';
      availDate.style.display = availSel.value === 'Pick a date…' ? '' : 'none';
      availSel.addEventListener('change', () => {
        availDate.style.display = availSel.value === 'Pick a date…' ? '' : 'none';
        if (availSel.value !== 'Pick a date…') L.availableFrom = availSel.value;
      });
    }
    const secBox = v.querySelector('#w-sec'); if (secBox) secBox.onclick = e => {
      const b = e.target.closest('.chip'); if (!b) return;
      b.classList.toggle('on');
      const val = b.dataset.v;
      if (b.classList.contains('on')) { if (!L.security.includes(val)) L.security.push(val); }
      else L.security = L.security.filter(x => x !== val);
    };

    if (step === 1) wireLocation();
    if (step === 7) wirePhotos();

    const back = v.querySelector('#wz-back') || v.querySelector('#wz-cancel');
    back.onclick = () => {
      if (back.id === 'wz-cancel' && step === 0) { location.hash = editingId ? '#/listing/' + editingId : '#/mylistings'; return; }
      step--; render();
    };
    const saveBtn = v.querySelector('#wz-save');
    if (saveBtn) saveBtn.onclick = () => publish(saveBtn);
    v.querySelector('#wz-next').onclick = () => {
      const err = validate(step);
      if (err) { toast(err, true); window.scrollTo({ top: 0, behavior: 'smooth' }); return; }
      if (step === 7) publish(); else { step++; render(); window.scrollTo({ top: 0 }); }
    };
  }

  function validate(s) {
    if (s === 0) { if ((L.title || '').trim().length < 4) return 'Give your listing a title (at least 4 characters)'; if (!L.ptype) return 'Choose the property type'; if (!L.town) return 'Choose the town'; }
    if (s === 2) {
      if (!L.rent || Number(L.rent) < 1) return 'Enter the rent';
      if ((L.contactPhone || state.user.phone || '').replace(/[\s-]/g, '').length < 9) return 'Add a valid contact phone number';
    }
    if (s === 7 && L.photos.length < 3) return 'Add at least 3 photos';
    return null;
  }

  // ----- location picker (Google Maps — same map students see) -----
  function wireLocation() {
    const box = v.querySelector('#pick-map');
    const latIn = v.querySelector('#pick-lat'), lngIn = v.querySelector('#pick-lng');
    const statusEl = v.querySelector('#pick-walk');
    if (pickMap) { try { pickMap.destroy(); } catch (e) {} pickMap = null; }
    let M = null, pin = null;
    const setPos = (lat, lng, move) => {
      L.lat = +(+lat).toFixed(6); L.lng = +(+lng).toFixed(6);
      latIn.value = L.lat; lngIn.value = L.lng;
      statusEl.innerHTML = `${ic('check')} Spot pinned — renters will see this exact spot on Google Maps.${L.town ? '' : ' <b>Tip:</b> pick the town on Step 1 so renters can find it.'}`;
      if (!M) return; // map still loading — the coordinates are saved, the pin appears once it loads
      // NOTE: inside the wizard `L` is the listing object, so Leaflet must be reached via window.L
      if (!pin) {
        pin = window.L.marker([L.lat, L.lng], { icon: redPinIcon(true), draggable: true, autoPan: true, autoPanPadding: [46, 46] }).addTo(M.map);
        pin.on('drag', () => {
          const p = pin.getLatLng();
          L.lat = +p.lat.toFixed(6); L.lng = +p.lng.toFixed(6);
          latIn.value = L.lat; lngIn.value = L.lng;
        });
        pin.on('dragend', () => {
          const p = pin.getLatLng();
          setPos(p.lat, p.lng, false);
          toast('Pin moved — spot saved');
        });
      } else {
        pin.setLatLng([L.lat, L.lng]);
      }
      if (move && M) M.setView(L.lat, L.lng, Math.max(M.zoom, 17), true);
    };
    latIn.addEventListener('change', () => { if (latIn.value && lngIn.value) setPos(latIn.value, lngIn.value, true); });
    lngIn.addEventListener('change', () => { if (latIn.value && lngIn.value) setPos(latIn.value, lngIn.value, true); });
    v.querySelector('#pick-gps').onclick = () => {
      if (!navigator.geolocation) { toast('Geolocation is not supported on this device', true); return; }
      toast('Getting your location…');
      navigator.geolocation.getCurrentPosition(
        p => setPos(p.coords.latitude, p.coords.longitude, true),
        () => toast('Could not get your location — check location permission', true)
      );
    };
    // place search: local gazetteer first (instant, always finds Chuka names), Nominatim bounded fallback
    const qIn = v.querySelector('#pick-q'), goBtn = v.querySelector('#pick-go');
    const doSearch = async () => {
      const raw = qIn.value.trim();
      if (!raw) return;
      goBtn.disabled = true; toast('Searching…');
      const hit = await searchPlaces(raw);
      goBtn.disabled = false;
      if (!hit) { toast('Place not found — try the map or GPS instead', true); return; }
      setPos(hit.lat, hit.lng, true);
    };
    goBtn.onclick = doSearch;
    qIn.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); doSearch(); } });

    loadLeaflet().then(() => {
      const tc = TOWNS.find(t => t.n === L.town);
      const st = getMyPos();
      const c0 = L.lat != null ? { lat: L.lat, lng: L.lng } : st || tc || KENYA_CENTER;
      M = makeMap(box, {
        lat: c0.lat, lng: c0.lng, zoom: L.lat != null ? 17 : (st || tc ? 14 : 7),
        zoomMin: 6, mode: 'page',
      });
      pickMap = M;
      onLeave(() => { try { M.destroy(); } catch (e) {} });
      // tap anywhere = the pin jumps there (the camera stays put, no blank reload)
      M.map.on('click', e => setPos(e.latlng.lat, e.latlng.lng, false));
      if (L.lat != null) setPos(L.lat, L.lng, false);
      setTimeout(() => M.map.invalidateSize(), 60);
    }).catch(() => {
      box.innerHTML = '<div class="notice notice-o">Map could not load — check your internet connection and reopen this step.</div>';
    });
  }

  // ----- photos -----
  function wirePhotos() {
    const grid = v.querySelector('#w-photos');
    const fileIn = v.querySelector('#w-file');
    const draw = () => {
      grid.innerHTML = L.photos.map((src, i) => `
        <div class="photo-cell"><img src="${src}"><button class="photo-x" data-i="${i}" type="button">✕</button>
          ${i === 0 ? '<span class="mini-tag" style="position:absolute;bottom:4px;left:4px">Cover</span>' : ''}</div>`).join('')
        + (L.photos.length < 8 ? `<button class="photo-add" id="ph-add" type="button">${ic('camera')}<span>Add photo</span></button>` : '');
      grid.querySelectorAll('.photo-x').forEach(b => b.onclick = () => { const i = +b.dataset.i; L.photos.splice(i, 1); L.thumbs.splice(i, 1); draw(); });
      grid.querySelector('#ph-add').onclick = () => fileIn.click();
      drawReview();
    };
    fileIn.onchange = async () => {
      const files = [...fileIn.files].filter(f => f.type.startsWith('image/'));
      for (const f of files) {
        if (L.photos.length >= 8) { toast('Maximum 8 photos', true); break; }
        toast('Processing photo…');
        try {
          const full = await compressTo(f, 150, 1150, 0.72);
          let th = '';
          try { th = await shrinkDataUrl(full, 340, 0.6); } catch (e2) { /* card falls back to full */ }
          L.photos.push(full); L.thumbs.push(th);
        } catch (e) { toast(e.message, true); }
      }
      fileIn.value = '';
      draw();
    };
    function drawReview() {
      const rv = v.querySelector('#w-review'); if (!rv) return;
      const rows = [
        ['Title', L.title], ['Type', L.ptype], ['Town', L.town],
        ['Estate', L.area ? L.area + (L.landmark ? ' — ' + L.landmark : '') : ''],
        ['Rent', L.rent ? kes(L.rent) + ' / ' + (L.period || '').toLowerCase() : ''],
        ['Deposit', L.deposit ? kes(L.deposit) : 'None'],
        ['Water', L.water], ['Electricity', L.elec], ['WiFi', L.wifi], ['Bathroom', L.bath],
        ['Gender', L.gender], ['Available', L.availableFrom || 'Now'], ['Photos', L.photos.length + ' added'],
      ];
      rv.innerHTML = rows.filter(r2 => r2[1]).map(r2 => `<div class="rev-row"><span class="k">${r2[0]}</span><span class="v">${esc(r2[1])}</span></div>`).join('');
    }
    draw();
  }

  async function publish(btn) {
    const b = btn || v.querySelector('#wz-next');
    // quick required-field check before saving from the middle of the wizard
    for (const s of [0, 1, 2]) { const err = validate(s); if (err) { toast(err, true); return; } }
    const bHtml = b.innerHTML;
    b.disabled = true; b.textContent = editingId ? 'Saving…' : 'Publishing…';
    if (!L.contactPhone) L.contactPhone = state.user.phone || '';
    // clear costs that don't apply (keeps listings honest and tidy)
    if (L.water === 'Included in rent') L.waterCost = '';
    if (L.water !== 'Rationed') L.waterSched = '';
    if (L.elec === 'Included in rent' || L.elec === 'Own token meter' || L.elec === 'Prepaid') L.elecCost = '';
    if (L.wifi !== 'Available but paid separately') L.wifiCost = '';
    if (L.curfewOn !== 'Yes') L.curfewTime = '';
    if (L.availableFrom === 'Pick a date…' && !/^\d{4}-\d{2}-\d{2}/.test(L.availableFrom || '')) L.availableFrom = 'Available now';
    // make sure every photo has a small thumb (older edits load photos without one)
    for (let i = 0; i < L.photos.length; i++) {
      if (!L.thumbs[i] || L.thumbs[i].length >= L.photos[i].length) {
        try { L.thumbs[i] = await shrinkDataUrl(L.photos[i], 340, 0.6); } catch (e) { L.thumbs[i] = ''; }
      }
    }
    const body = { ...L, photos: L.photos, thumbs: L.thumbs };
    const res = editingId
      ? await api('/listings/' + editingId, { method: 'PUT', body })
      : await api('/listings', { body });
    if (res.ok) {
      toast(editingId ? 'Listing updated' : 'Listing published!');
      location.hash = '#/listing/' + (editingId || res.id);
    } else { toast(res.error, true); b.disabled = false; b.innerHTML = bHtml; }
  }

  render();
}

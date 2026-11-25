// HuntInKE — My listings + Boost payment (town-targeted)
async function viewMyListings() {
  if (!state.user) { location.hash = '#/login'; return; }
  const v = document.getElementById('view');
  const gen = routeGen;
  v.innerHTML = `<div class="sec-h"><h2>My listings</h2></div>${skeletonGrid(2)}
    <a class="btn btn-green btn-block" href="#/new" style="margin-top:14px">${ic('plus')} Post a new listing</a>`;
  const r = await api('/my/listings');
  if (stale(gen)) return; // navigated away while loading
  if (!r.ok) { v.innerHTML = emptyBox('Sign in required', r.error); return; }
  const items = r.items;
  const boosted = l => l.boostedUntil && l.boostedUntil > Date.now();

  v.innerHTML = `<div class="sec-h"><h2>My listings</h2><a href="#/new">${ic('plus')} New</a></div>
    <div class="notice notice-g" style="margin-bottom:10px">${ic('shield')}<span>${state.user.verifyStatus === 'APPROVED'
      ? 'Verified account: up to 5 listings.'
      : 'Free plan: 2 listings. Get verified in your Profile to post up to 5.'}</span></div>
    <div class="notice notice-o" style="margin-bottom:14px">${ic('bolt')}<span><b>Boost gets you seen:</b> KES ${BOOST.amountKes} pins a listing at the top of results <b>in its town</b> for ${BOOST.days} days — renters browsing that town see it first. Tap <b>Boost</b> on any listing below.</span></div>
    ${items.length ? items.map(l => {
      const vac = vacInfo(l);
      const hid = !!l.hidden;
      return `
      <div class="row-card" ${hid ? 'style="opacity:.66"' : ''}>
        <div class="row-top">
          <div style="display:flex;gap:11px;min-width:0">
            <div class="cph" style="width:64px;height:64px;border-radius:10px;overflow:hidden;flex:none;aspect-ratio:auto">
              ${l.thumb ? `<img src="${l.thumb}" style="width:100%;height:100%;object-fit:cover">` : `<div class="cph-empty">${ic('photo')}</div>`}
            </div>
            <div style="min-width:0">
              <div class="row-title">${esc(l.title)}</div>
              <div class="row-sub">${kes(l.rent)}/${perShort(l.period)} · ${esc(l.town || '')}${l.area ? ' · ' + esc(l.area) : ''} · ${l.views} views</div>
              <div style="display:flex;gap:6px;margin-top:6px;flex-wrap:wrap">
                <span class="pill ${vac.full ? 'pill-full' : 'pill-vac'}">${vac.full ? ic('x') : ic('check')}${esc(vac.label)}</span>
                ${hid ? `<span class="pill pill-muted">${ic('eyeoff')}Hidden — renters cannot see it</span>` : ''}
                ${boosted(l) ? `<span class="pill pill-o">${ic('bolt')}Boosted till ${fmtDate(l.boostedUntil)}</span>` : ''}
              </div>
            </div>
          </div>
        </div>
        <div class="row-acts">
          <a class="btn btn-outline btn-sm" href="#/listing/${l.id}">${ic('eye')} View</a>
          <a class="btn btn-outline btn-sm" href="#/edit/${l.id}">${ic('edit')} Edit</a>
          <button class="btn btn-outline btn-sm" data-act="hide" data-id="${l.id}" data-hid="${hid ? 1 : 0}" aria-label="${hid ? 'Show this listing to renters again' : 'Hide this listing from renters'}">${hid ? ic('eye') + ' Show' : ic('eyeoff') + ' Hide'}</button>
          ${hid ? '' : `<a class="btn btn-primary btn-sm" href="#/boost/${l.id}">${ic('bolt')} ${boosted(l) ? 'Boost again' : 'Boost'}</a>`}
          <button class="btn btn-danger btn-sm" data-act="del" data-id="${l.id}" aria-label="Delete this listing forever">${ic('trash')}</button>
        </div>
        <div class="vac-row" data-id="${l.id}" data-v="${vac.v}" data-u="${vac.u}" style="margin-top:9px;padding-top:9px;border-top:1px dashed var(--line)">
          <span style="font-size:12px;font-weight:700;color:var(--ink3)">VACANCY</span>
          <button class="btn btn-outline btn-sm" data-vac="${Math.max(0, vac.v - 1)}" ${vac.v <= 0 ? 'disabled' : ''} aria-label="One house was taken">−1</button>
          <span class="vac-lab">${vac.full ? '<b>All occupied</b>' : `<b>${vac.v}</b> ${vac.v === 1 ? 'house' : 'houses'} vacant`}</span>
          <button class="btn btn-outline btn-sm" data-vac="${Math.min(50, vac.v + 1)}" ${vac.v >= 50 ? 'disabled' : ''} aria-label="One house is free again">+1</button>
          ${vac.full
            ? `<button class="btn btn-outline btn-sm" data-vac="${Math.max(1, vac.u)}">Reopen</button>`
            : `<button class="btn btn-outline btn-sm" data-vac="0">All taken</button>`}
        </div>
      </div>`;
    }).join('')
    : emptyBox('No listings yet', 'Post your first vacant room — it takes about 2 minutes.')}
    <a class="btn btn-green btn-block" href="#/new" style="margin-top:14px">${ic('plus')} Post a new listing</a>`;

  // vacancy stepper — OPTIMISTIC: the count moves the moment you tap and the save
  // runs quietly behind a toast, so it feels instant even on a slow network.
  // (it used to wait for the server AND reload the whole list before anything moved)
  const paintVac = (row, v, u) => {
    row.dataset.v = v; row.dataset.u = u;
    const full = v <= 0;
    row.innerHTML = `
      <span style="font-size:12px;font-weight:700;color:var(--ink3)">VACANCY</span>
      <button class="btn btn-outline btn-sm" data-vac="${Math.max(0, v - 1)}" ${v <= 0 ? 'disabled' : ''} aria-label="One house was taken">−1</button>
      <span class="vac-lab">${full ? '<b>All occupied</b>' : `<b>${v}</b> ${v === 1 ? 'house' : 'houses'} vacant`}</span>
      <button class="btn btn-outline btn-sm" data-vac="${Math.min(50, v + 1)}" ${v >= 50 ? 'disabled' : ''} aria-label="One house is free again">+1</button>
      ${full
        ? `<button class="btn btn-outline btn-sm" data-vac="${Math.max(1, u)}">Reopen</button>`
        : `<button class="btn btn-outline btn-sm" data-vac="0">All taken</button>`}`;
    // keep the green/red vacancy pill at the top of the card in sync with the count
    const pill = row.closest('.row-card').querySelector('.pill-vac, .pill-full');
    if (pill) {
      pill.className = 'pill ' + (full ? 'pill-full' : 'pill-vac');
      pill.innerHTML = (full ? ic('x') : ic('check')) + esc(full ? 'All occupied' : (v === 1 ? '1 house vacant' : v + ' houses vacant'));
    }
  };
  v.querySelectorAll('.vac-row').forEach(row => {
    let chain = Promise.resolve(); // saves run in tap order — rapid taps never fight
    row.addEventListener('click', e => {
      const b = e.target.closest('[data-vac]');
      if (!b || b.disabled) return;
      const id = row.dataset.id, prev = +row.dataset.v, u = +row.dataset.u;
      const nv = Math.max(0, Math.min(50, +b.dataset.vac));
      if (nv === prev) return;
      paintVac(row, nv, u);           // instant — zero network before this
      toast('Updating vacancy…');     // popup while the save runs behind it
      chain = chain.then(() =>
        api('/listings/' + id + '/status', { body: { vacant: nv } }).then(res => {
          if (res.ok) { if (+row.dataset.v === nv) toast(res.unitsVacant > 0 ? 'Saved — ' + res.unitsVacant + ' vacant' : 'Saved — all occupied'); }
          else {
            if (+row.dataset.v === nv) paintVac(row, prev, u); // put the old number back
            toast(res.error, true);
          }
        }).catch(() => {
          if (+row.dataset.v === nv) paintVac(row, prev, u);
          toast('Network problem — the vacancy was not saved. Try again.', true);
        }));
    });
  });
  v.querySelectorAll('[data-act="hide"]').forEach(b => b.onclick = () => {
    const id = b.dataset.id, hid = b.dataset.hid === '1';
    if (hid) {
      // Show — reversible by design, no confirmation needed
      api('/listings/' + id + '/visibility', { body: { hidden: false } }).then(res => {
        if (res.ok) { toast('Listing is live again — renters can see it'); viewMyListings(); }
        else toast(res.error, true);
      });
    } else {
      confirmDlg('Hide this listing?', 'Renters will not see it anywhere — browse, search, map or its link. It stays right here on this page and you can bring it back with Show.', 'Hide', async () => {
        const res = await api('/listings/' + id + '/visibility', { body: { hidden: true } });
        if (res.ok) { toast('Listing hidden — only you can see it here'); viewMyListings(); }
        else toast(res.error, true);
      });
    }
  });
  v.querySelectorAll('[data-act="del"]').forEach(b => b.onclick = () =>
    confirmDlg('Delete this listing forever?', 'Everything about it is wiped — the listing, its photos, its chats, favorites and boosts. There is no way back. If you only want it out of sight for a while, use Hide instead.', 'Delete forever', async () => {
      const res = await api('/listings/' + b.dataset.id, { method: 'DELETE' });
      if (res.ok) { toast('Listing deleted for good'); viewMyListings(); } else toast(res.error, true);
    }, true));
}

async function viewBoost(id) {
  if (!state.user) { location.hash = '#/login'; return; }
  const v = document.getElementById('view');
  const gen = routeGen;
  v.innerHTML = skeletonGrid(1);
  const r = await api('/listings/' + id);
  if (stale(gen)) return;
  if (!r.ok || !r.isOwner) { v.innerHTML = emptyBox('Listing not found', 'Only the owner can boost this listing.'); return; }
  const l = r.listing;
  const paybill = state.settings.paybill_number || '0143374333';
  const payname = state.settings.paybill_name || 'Isaac Bridget';
  const boosted = l.boostedUntil && l.boostedUntil > Date.now();
  const mine = await api('/my/boosts');
  const pending = (mine.ok && mine.items || []).find(b => b.listingId === l.id && b.status === 'PENDING');

  v.innerHTML = `
    <div class="sec-h"><h2>${ic('bolt')} Boost "${esc(l.title)}"</h2></div>
    ${boosted ? `<div class="notice notice-g">${ic('check')}<span>This listing is boosted until <b>${fmtDate(l.boostedUntil)}</b> — renters browsing <b>${esc(l.town || 'its town')}</b> see it at the top.</span></div>` : ''}
    ${pending ? `<div class="notice notice-o">${ic('flag')}<span>Payment received — waiting for the admin to confirm your M-Pesa payment. Your boost starts right after confirmation.</span></div>` : ''}
    ${!boosted && !pending ? `
    <div class="sec-block">
      <h3>What a boost does</h3>
      <p class="hint-t" style="margin-bottom:12px">Your listing jumps to the <b>top of results in ${esc(l.town || 'its town')}</b> with an orange BOOSTED badge for ${BOOST.days} days — on the home page, search results and the map for everyone browsing ${esc(l.town || 'that town')}. Renters in other towns are not affected unless they search ${esc(l.town || 'your town')} themselves. Boosted listings get the most views and chats.</p>
      <h3>How to pay (KES ${BOOST.amountKes} / ${BOOST.days} days)</h3>
      <div class="steps3" style="margin-top:10px">
        <div class="stepcard"><div class="step-n">1</div><div><h3>Open M-Pesa</h3><p>Go to <b>Send Money</b> (Pochi / Send to mobile).</p></div></div>
        <div class="stepcard"><div class="step-n">2</div><div><h3>Send KES ${BOOST.amountKes}</h3><p>To number <b>${esc(paybill)}</b> — <b>${esc(payname)}</b>.</p></div></div>
        <div class="stepcard"><div class="step-n">3</div><div><h3>Confirm below</h3><p>Enter the M-Pesa confirmation code <b>or the name you sent from</b>, then tap "I have sent the money". The admin will activate your boost.</p></div></div>
      </div>
      <label class="lbl">M-Pesa confirmation code <span style="font-weight:500">(fastest — copy it from the SMS)</span></label>
      <input class="inp" id="bs-code" placeholder="e.g. SLK7AB12C9" style="text-transform:uppercase">
      <label class="lbl">Name the money was sent from <span style="font-weight:500">(if you did not note the code)</span></label>
      <input class="inp" id="bs-name" placeholder="e.g. Grace Wanjiru — the name on M-Pesa">
      <button class="btn btn-primary btn-block" id="bs-go" style="margin-top:16px">${ic('bolt')} I have sent the money</button>
      <p class="hint-t" style="margin-top:10px">Payments go directly to <b>${esc(payname)}</b>, not to HuntInKE. Rent and deposits are NEVER paid through this platform.</p>
    </div>` : ''}
    <div style="margin-top:14px"><a class="btn btn-outline" href="#/listing/${l.id}">${ic('back')} Back to listing</a></div>`;

  const go = v.querySelector('#bs-go');
  if (go) go.onclick = async () => {
    go.disabled = true;
    const code = (v.querySelector('#bs-code').value || '').trim().toUpperCase();
    const sname = (v.querySelector('#bs-name').value || '').trim();
    if (!code && !sname) {
      toast('Add the M-Pesa code or the name you sent from — the admin needs one to find your payment', true);
      go.disabled = false;
      return;
    }
    const res = await api('/listings/' + id + '/boost', { body: { mpesaCode: code, senderName: sname } });
    if (res.ok) { toast('Sent! The admin will confirm your payment shortly.'); viewBoost(id); }
    else { toast(res.error, true); go.disabled = false; }
  };
}

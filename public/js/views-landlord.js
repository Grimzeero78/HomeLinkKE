// HomeLinkKE — My listings + Boost payment (town-targeted)
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
    ${items.length ? items.map(l => `
      <div class="row-card">
        <div class="row-top">
          <div style="display:flex;gap:11px;min-width:0">
            <div class="cph" style="width:64px;height:64px;border-radius:10px;overflow:hidden;flex:none;aspect-ratio:auto">
              ${l.thumb ? `<img src="${l.thumb}" style="width:100%;height:100%;object-fit:cover">` : `<div class="cph-empty">${ic('photo')}</div>`}
            </div>
            <div style="min-width:0">
              <div class="row-title">${esc(l.title)}</div>
              <div class="row-sub">${kes(l.rent)}/${perShort(l.period)} · ${esc(l.town || '')}${l.area ? ' · ' + esc(l.area) : ''} · ${l.views} views</div>
              <div style="display:flex;gap:6px;margin-top:6px;flex-wrap:wrap">
                <span class="pill ${l.status === 'AVAILABLE' ? 'pill-g' : 'pill-x'}">${l.status === 'AVAILABLE' ? 'Available' : 'Taken'}</span>
                ${boosted(l) ? `<span class="pill pill-o">${ic('bolt')}Boosted till ${fmtDate(l.boostedUntil)}</span>` : ''}
              </div>
            </div>
          </div>
        </div>
        <div class="row-acts">
          <a class="btn btn-outline btn-sm" href="#/listing/${l.id}">${ic('eye')} View</a>
          <a class="btn btn-outline btn-sm" href="#/edit/${l.id}">${ic('edit')} Edit</a>
          <button class="btn btn-outline btn-sm" data-act="status" data-id="${l.id}" data-to="${l.status === 'AVAILABLE' ? 'TAKEN' : 'AVAILABLE'}">
            ${l.status === 'AVAILABLE' ? 'Mark taken' : 'Mark available'}</button>
          <a class="btn btn-primary btn-sm" href="#/boost/${l.id}">${ic('bolt')} ${boosted(l) ? 'Boost again' : 'Boost'}</a>
          <button class="btn btn-danger btn-sm" data-act="del" data-id="${l.id}">${ic('trash')}</button>
        </div>
      </div>`).join('')
    : emptyBox('No listings yet', 'Post your first vacant room — it takes about 2 minutes.')}
    <a class="btn btn-green btn-block" href="#/new" style="margin-top:14px">${ic('plus')} Post a new listing</a>`;

  v.querySelectorAll('[data-act="status"]').forEach(b => b.onclick = async () => {
    const res = await api('/listings/' + b.dataset.id + '/status', { body: { status: b.dataset.to } });
    if (res.ok) { toast('Marked as ' + res.status.toLowerCase()); viewMyListings(); } else toast(res.error, true);
  });
  v.querySelectorAll('[data-act="del"]').forEach(b => b.onclick = () =>
    confirmDlg('Delete this listing?', 'It will be removed from HomeLinkKE. You cannot undo this.', 'Delete', async () => {
      const res = await api('/listings/' + b.dataset.id, { method: 'DELETE' });
      if (res.ok) { toast('Listing deleted'); viewMyListings(); } else toast(res.error, true);
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
        <div class="stepcard"><div class="step-n">3</div><div><h3>Confirm below</h3><p>Enter the M-Pesa confirmation code and tap "I have sent the money". The admin will activate your boost.</p></div></div>
      </div>
      <label class="lbl">M-Pesa confirmation code <span style="font-weight:500">(optional but speeds up confirmation)</span></label>
      <input class="inp" id="bs-code" placeholder="e.g. SLK7AB12C9" style="text-transform:uppercase">
      <button class="btn btn-primary btn-block" id="bs-go" style="margin-top:16px">${ic('bolt')} I have sent the money</button>
      <p class="hint-t" style="margin-top:10px">Payments go directly to <b>${esc(payname)}</b>, not to HomeLinkKE. Rent and deposits are NEVER paid through this platform.</p>
    </div>` : ''}
    <div style="margin-top:14px"><a class="btn btn-outline" href="#/listing/${l.id}">${ic('back')} Back to listing</a></div>`;

  const go = v.querySelector('#bs-go');
  if (go) go.onclick = async () => {
    go.disabled = true;
    const res = await api('/listings/' + id + '/boost', { body: { mpesaCode: (v.querySelector('#bs-code').value || '').trim().toUpperCase() } });
    if (res.ok) { toast('Sent! The admin will confirm your payment shortly.'); viewBoost(id); }
    else { toast(res.error, true); go.disabled = false; }
  };
}

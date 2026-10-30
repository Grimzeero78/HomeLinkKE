// HomeLinKE — Home + Search views
const SEARCH = { q: '', town: '', ptype: '', min: '', max: '', furnishing: '', amenities: [], sort: 'new' };

async function viewHome() {
  const v = document.getElementById('view');
  const gen = routeGen;
  const myTown = getMyTown();
  const hasPos = !!getMyPos();
  v.innerHTML = `
    <section class="hero">
      <div class="hero-leaf"></div>
      <h1>Find a house anywhere in Kenya</h1>
      <p>Bedsitters, apartments and family houses in every town — chat with the landlord directly, view first, pay later.</p>
      <div class="hero-search">
        <input class="inp" id="hero-q" placeholder="Search town, estate, landmark…">
        <button class="btn btn-primary" id="hero-go">${ic('search')}</button>
      </div>
      <div class="hero-chips">${TOWNS.filter(t => t.big).map(t => `<button class="chip ${t.n === myTown ? 'on' : ''}" data-area="${esc(t.n)}">${esc(t.n)}</button>`).join('')}</div>
    </section>
    <div class="sec" id="home-nearby"></div>
    <div class="sec" id="home-boosted"></div>
    <div class="sec" id="home-newest"></div>
    <div class="sec">
      <div class="sec-h"><h2>How HomeLinKE works</h2></div>
      <div class="steps3">
        <div class="stepcard"><div class="step-n">1</div><div><h3>Search & compare</h3><p>Real prices, real photos, exact map pins — in Nairobi, Mombasa, Nanyuki or any town in Kenya.</p></div></div>
        <div class="stepcard"><div class="step-n">2</div><div><h3>Chat with the landlord</h3><p>Message in the app or tap WhatsApp — agree on a viewing time. No agents, no middlemen.</p></div></div>
        <div class="stepcard"><div class="step-n">3</div><div><h3>View first, pay later</h3><p>Never send money before you have seen the house in person. That is the HomeLinKE rule.</p></div></div>
      </div>
    </div>
    <div class="sec"><div class="notice notice-g">${ic('shield')}<span>HomeLinKE never collects rent. Any payment happens face-to-face with the landlord after a viewing. Report anything suspicious.</span></div></div>
    <div class="sec" id="home-cta"></div>`;

  const go = q => { SEARCH.q = q; SEARCH.town = ''; location.hash = '#/search'; };
  v.querySelector('#hero-go').onclick = () => go(v.querySelector('#hero-q').value);
  v.querySelector('#hero-q').addEventListener('keydown', e => { if (e.key === 'Enter') go(e.target.value); });
  v.querySelectorAll('.hero-chips .chip').forEach(c => c.onclick = () => { setMyTown(c.dataset.area); SEARCH.town = c.dataset.area; SEARCH.q = ''; location.hash = '#/search'; });

  // ---- "Houses near you": ask for GPS once, then sort by real distance ----
  const nearEl = v.querySelector('#home-nearby');
  if (!hasPos && !myTown) {
    nearEl.innerHTML = `<div class="sec-block" style="text-align:center;padding:20px 16px">
      <h3 style="font-size:16px">${ic('pin')} Houses around you</h3>
      <p class="hint-t" style="margin:6px 0 12px">Allow location and HomeLinKE shows vacant houses nearest to you first — in any town.</p>
      <button class="btn btn-primary" id="nb-ask">${ic('pin')} Use my location</button>
      <p class="hint-t" style="margin-top:10px">Prefer not to? Just pick your town below the search bar.</p>
    </div>`;
    nearEl.querySelector('#nb-ask').onclick = () => askLocation(ok => { if (ok) viewHome(); });
  } else {
    nearEl.innerHTML = `<div class="sec-h"><h2>${ic('pin')} Houses near ${hasPos ? 'you' : esc(myTown)}</h2><a href="#/map">Open map →</a></div>${skeletonGrid(4)}`;
  }

  // boosted-in-your-town + newest (the API ranks boosts from your town on top)
  const p = new URLSearchParams({ limit: '60', sort: 'new', bt: myTown });
  const [all] = await Promise.all([api('/listings?' + p.toString())]);
  if (stale(gen)) return;
  const items = (all.ok && all.items) || [];
  const pos = getMyPos();
  const boostedItems = items.filter(l => l.boostedUntil && l.boostedUntil > Date.now() && (!myTown || l.town === myTown));

  const bEl = v.querySelector('#home-boosted');
  if (boostedItems.length) bEl.innerHTML = `<div class="sec-h"><h2>${ic('bolt')} Boosted in ${esc(myTown || 'Kenya')}</h2></div>
    <div class="grid">${boostedItems.slice(0, 4).map(listingCard).join('')}</div>`;
  else bEl.innerHTML = '';

  if (pos) {
    const withD = items.filter(l => l.lat != null && l.lng != null)
      .map(l => ({ l, d: distMeters(pos, l) })).sort((a, b) => a.d - b.d).slice(0, 8);
    nearEl.innerHTML = `<div class="sec-h"><h2>${ic('pin')} Houses near you</h2><a href="#/map">Open map →</a></div>`
      + (withD.length ? `<div class="grid">${withD.map(x => listingCard(x.l)).join('')}</div>`
        : `<div class="empty">${ic('pin')}<h3>Nothing pinned near you yet</h3><p>Landlords in your area have not posted yet. Try browsing ${esc(myTown || 'your town')} or search another town.</p></div>`);
  } else if (myTown) {
    const inTown = items.filter(l => l.town === myTown).slice(0, 8);
    nearEl.innerHTML = `<div class="sec-h"><h2>Houses in ${esc(myTown)}</h2><a href="#/search">See all →</a></div>`
      + (inTown.length ? `<div class="grid">${inTown.map(listingCard).join('')}</div>`
        : `<div class="empty">${ic('pin')}<h3>No houses in ${esc(myTown)} yet</h3><p>Be the first — or search another town. New houses are posted every week.</p></div>`);
  }

  v.querySelector('#home-newest').innerHTML = items.length
    ? `<div class="sec-h"><h2>Newest in Kenya</h2><a href="#/search">See all →</a></div><div class="grid">${items.slice(0, 8).map(listingCard).join('')}</div>`
    : emptyBox('No listings yet', state.user && state.user.role === 'LANDLORD'
        ? 'Be the first! Post your vacant house — it takes 2 minutes.'
        : 'Check back soon — landlords across Kenya are posting vacant houses every week.');

  const cta = v.querySelector('#home-cta');
  if (!state.user) {
    cta.innerHTML = `<div class="sec-block" style="background:var(--pine);color:#fff;border:none">
      <h3 style="color:#fff">Have a vacant house?</h3>
      <p style="font-size:13.5px;color:#d8e8dd;margin-bottom:14px">Post it on HomeLinKE and reach renters in every town in Kenya. First 2 listings are free.</p>
      <a class="btn btn-primary" href="#/register">List your property</a></div>`;
  } else if (state.user.role === 'LANDLORD') {
    cta.innerHTML = `<div class="sec-block" style="background:var(--pine);color:#fff;border:none">
      <h3 style="color:#fff">Get more renters to your houses</h3>
      <p style="font-size:13.5px;color:#d8e8dd;margin-top:8px"><b>1. Get verified</b> — upload your ID and ownership proof in your Profile to earn the green badge and post up to 5 listings instead of 2.</p>
      <p style="font-size:13.5px;color:#d8e8dd;margin-bottom:14px"><b>2. Boost</b> — KES ${BOOST.amountKes} pins a listing at the top of results in <b>your town</b> for ${BOOST.days} days. Renters browsing your town see it first — with an orange BOOSTED badge.</p>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        ${state.user.verifyStatus !== 'APPROVED' ? `<a class="btn btn-primary" href="#/profile">${ic('shield')} Get verified</a>` : ''}
        <a class="btn btn-outline" href="#/mylistings">${ic('doc')} My listings</a>
      </div></div>`;
  }
}

async function viewSearch() {
  const v = document.getElementById('view');
  const gen = routeGen;
  if (SEARCH.town === '') SEARCH.town = getMyTown();
  v.innerHTML = `
    <div class="filterbar">
      <input class="inp" id="s-q" placeholder="Search town, estate…" value="${esc(SEARCH.q)}">
      <button class="btn btn-outline" id="s-toggle">${ic('gear')}<span class="hide-p">Filters</span></button>
      <button class="btn btn-green" id="s-go">${ic('search')}</button>
    </div>
    <div class="filters hide" id="s-filters">
      <h3>Town</h3><div class="chips" id="f-town">${['<button class="chip" data-v="">Anywhere in Kenya</button>'].concat(TOWNS.map(t => `<button class="chip" data-v="${esc(t.n)}">${esc(t.n)}</button>`)).join('')}</div>
      <h3>Property type</h3><div class="chips" id="f-type">${['<button class="chip" data-v="">Any</button>'].concat(TYPES.map(t => `<button class="chip" data-v="${esc(t)}">${esc(t)}</button>`)).join('')}</div>
      <h3>Price (KES)</h3>
      <div style="display:flex;gap:8px"><input class="inp" id="f-min" type="number" placeholder="Min" value="${esc(SEARCH.min)}"><input class="inp" id="f-max" type="number" placeholder="Max" value="${esc(SEARCH.max)}"></div>
      <h3>Amenities</h3>
      <label class="check"><input type="checkbox" data-a="water" ${SEARCH.amenities.includes('water') ? 'checked' : ''}> Water included</label>
      <label class="check"><input type="checkbox" data-a="wifi" ${SEARCH.amenities.includes('wifi') ? 'checked' : ''}> WiFi included</label>
      <label class="check"><input type="checkbox" data-a="ensuite" ${SEARCH.amenities.includes('ensuite') ? 'checked' : ''}> Own bathroom (en-suite)</label>
      <label class="check"><input type="checkbox" data-a="kitchen" ${SEARCH.amenities.includes('kitchen') ? 'checked' : ''}> Own kitchen</label>
      <label class="check"><input type="checkbox" data-a="parking" ${SEARCH.amenities.includes('parking') ? 'checked' : ''}> Parking</label>
      <label class="check"><input type="checkbox" data-a="guard" ${SEARCH.amenities.includes('guard') ? 'checked' : ''}> Security guard</label>
      <label class="check"><input type="checkbox" data-a="backup" ${SEARCH.amenities.includes('backup') ? 'checked' : ''}> Backup power</label>
      <h3>Sort by</h3>
      <select class="inp" id="f-sort">
        <option value="new">Newest (boosted first)</option>
        <option value="near">Nearest to me</option>
        <option value="priceAsc">Price: low to high</option>
        <option value="priceDesc">Price: high to low</option>
      </select>
    </div>
    <div class="result-count" id="s-count"></div>
    <div id="s-results">${skeletonGrid(6)}</div>`;

  const sel = (id, key) => {
    const box = v.querySelector(id);
    [...box.children].forEach(c => { if (c.dataset.v === SEARCH[key]) c.classList.add('on'); });
    box.addEventListener('click', e => {
      const b = e.target.closest('.chip'); if (!b) return;
      [...box.children].forEach(c => c.classList.remove('on'));
      b.classList.add('on'); SEARCH[key] = b.dataset.v;
      if (key === 'town' && b.dataset.v) setMyTown(b.dataset.v);
      load();
    });
  };
  v.querySelector('#s-toggle').onclick = () => v.querySelector('#s-filters').classList.toggle('hide');
  v.querySelector('#s-go').onclick = () => { SEARCH.q = v.querySelector('#s-q').value; load(); };
  v.querySelector('#s-q').addEventListener('keydown', e => { if (e.key === 'Enter') { SEARCH.q = e.target.value; load(); } });
  ['#f-min', '#f-max'].forEach(s => v.querySelector(s).addEventListener('change', () => {
    SEARCH.min = v.querySelector('#f-min').value; SEARCH.max = v.querySelector('#f-max').value; load();
  }));
  v.querySelector('#f-sort').value = SEARCH.sort;
  v.querySelector('#f-sort').onchange = e => { SEARCH.sort = e.target.value; load(); };
  v.querySelectorAll('#s-filters input[data-a]').forEach(cb => cb.onchange = () => {
    const a = cb.dataset.a;
    if (cb.checked) { if (!SEARCH.amenities.includes(a)) SEARCH.amenities.push(a); }
    else SEARCH.amenities = SEARCH.amenities.filter(x => x !== a);
    load();
  });
  sel('#f-town', 'town'); sel('#f-type', 'ptype');

  async function load() {
    const params = new URLSearchParams();
    if (SEARCH.q) params.set('q', SEARCH.q);
    if (SEARCH.town) params.set('town', SEARCH.town);
    if (SEARCH.ptype) params.set('ptype', SEARCH.ptype);
    if (SEARCH.min) params.set('min', SEARCH.min);
    if (SEARCH.max) params.set('max', SEARCH.max);
    if (SEARCH.amenities.length) params.set('amenities', SEARCH.amenities.join(','));
    params.set('sort', SEARCH.sort === 'near' ? 'new' : SEARCH.sort);
    params.set('bt', SEARCH.town || getMyTown()); // boosts target the town being browsed
    params.set('limit', 100);
    const r = await api('/listings?' + params.toString());
    if (stale(gen)) return;
    const box = v.querySelector('#s-results');
    if (!box) return; // view replaced while fetching
    if (!r.ok) { box.innerHTML = emptyBox('Search failed', r.error || 'Try again'); return; }
    let items = r.items;
    if (SEARCH.sort === 'near') {
      const pos = getMyPos();
      if (!pos) { toast('Allow location first — tap "Use my location" on the home page', true); }
      else items = items.filter(l => l.lat != null && l.lng != null)
        .map(l => ({ l, d: distMeters(pos, l) })).sort((a, b) => a.d - b.d).map(x => x.l);
    }
    const cnt = v.querySelector('#s-count');
    if (cnt) cnt.textContent = items.length + (items.length === 1 ? ' house found' : ' houses found');
    box.innerHTML = items.length ? `<div class="grid">${items.map(listingCard).join('')}</div>`
      : emptyBox('Nothing matched', 'Try another town, a wider price range, or remove some filters.');
  }
  load();
}

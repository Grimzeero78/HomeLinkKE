// HomeLinkKE — Login / Register / Setup / Profile
function authRedirect() { location.hash = state.user && state.user.role === 'ADMIN' ? '#/admin' : '#/home'; }

// target: optional hash to go to after auth — registration sends new users to the welcome guide
async function afterAuth(res, target) {
  if (!res.ok) { toast(res.error, true); return; }
  token.set(res.token);
  state.user = res.user;
  buildNav();
  toast('Welcome, ' + (res.user.name || res.user.username) + '!');
  if (target) location.hash = target; else authRedirect();
  maybeStudentCaution();
}

function viewAuth(tab) {
  const v = document.getElementById('view');
  const isReg = tab === 'register';
  v.innerHTML = `<div class="auth-wrap"><div class="auth-card">
    <div class="auth-brand">
      <img class="auth-logo" src="/icons/icon-192.png" alt="HomeLinkKE logo" width="60" height="60">
      <div class="auth-name">Home<b>Link</b>KE</div>
      <p class="auth-tag">${isReg
        ? 'Create a free account — find a house anywhere in Kenya or list your own.'
        : 'Vacant houses &amp; apartments across Kenya — chat with landlords directly, never pay before viewing.'}</p>
    </div>
    <div class="seg" style="margin:16px 0">
      <button id="t-login" class="${isReg ? '' : 'on'}">Sign in</button>
      <button id="t-reg" class="${isReg ? 'on' : ''}">Create account</button>
    </div>
    <div id="auth-body">${isReg ? regForm() : loginForm()}</div>
    <div class="auth-alt">${isReg ? 'Already have an account? <a href="#/login">Sign in</a>' : 'New to HomeLinkKE? <a href="#/register">Create an account</a>'}</div>
  </div></div>`;

  v.querySelector('#t-login').onclick = () => viewAuth('login');
  v.querySelector('#t-reg').onclick = () => viewAuth('register');
  wireLogin(v); wireReg(v);
}

function loginForm() {
  return `
    <label class="lbl">Username</label><input class="inp" id="li-u" autocomplete="username" placeholder="your username">
    <label class="lbl">Password</label><input class="inp" id="li-p" type="password" autocomplete="current-password" placeholder="••••••••">
    <button class="btn btn-green btn-block" id="li-go" style="margin-top:16px">Sign in</button>
    <button class="btn btn-ghost btn-block" id="li-forgot" style="margin-top:6px;font-size:13px">Forgot password?</button>`;
}

function wireLogin(v) {
  const go = v.querySelector('#li-go'); if (!go) return;
  const submit = async () => {
    go.disabled = true;
    const res = await api('/login', { body: { username: v.querySelector('#li-u').value, password: v.querySelector('#li-p').value } });
    go.disabled = false;
    afterAuth(res);
  };
  go.onclick = submit;
  v.querySelector('#li-p').addEventListener('keydown', e => { if (e.key === 'Enter') submit(); });
  v.querySelector('#li-forgot').onclick = () => {
    modal(`<h3>Password hint</h3>
      <p class="hint-t">Enter your username and we will show you the hint you saved when registering.</p>
      <input class="inp" id="fg-u" placeholder="username" style="margin-top:10px">
      <div id="fg-out"></div>
      <button class="btn btn-green btn-block" style="margin-top:14px" id="fg-go">Show my hint</button>`,
      m => m.querySelector('#fg-go').onclick = async () => {
        const r = await api('/hint/' + encodeURIComponent(m.querySelector('#fg-u').value.trim().toLowerCase()));
        m.querySelector('#fg-out').innerHTML = r.ok
          ? `<div class="notice notice-g" style="margin-top:12px">${ic('shield')}<span>${r.hint ? 'Your hint: <b>' + esc(r.hint) + '</b>' : 'No account found with that username.'}</span></div>`
          : `<div class="notice notice-o" style="margin-top:12px">${ic('flag')}<span>${esc(r.error)}</span></div>`;
      });
  };
}

function regForm() {
  return `
    <label class="lbl">I am a…</label>
    <div class="seg" id="rg-role"><button type="button" class="on" data-v="SEEKER">Looking for a house</button><button type="button" data-v="LANDLORD">Landlord</button></div>
    <label class="lbl">Full name</label><input class="inp" id="rg-name" placeholder="e.g. Brian Mutua">
    <label class="lbl">WhatsApp number <span style="font-weight:500">(the other side reaches you here)</span></label>
    <input class="inp" id="rg-phone" inputmode="tel" placeholder="e.g. 0712 345 678 or 254712…">
    <label class="lbl">Username</label><input class="inp" id="rg-u" autocomplete="username" placeholder="3–20 letters, numbers or _">
    <label class="lbl">Password</label><input class="inp" id="rg-p" type="password" placeholder="At least 6 characters">
    <label class="lbl">Confirm password</label><input class="inp" id="rg-p2" type="password" placeholder="Type the password again">
    <label class="lbl">Password hint</label>
    <input class="inp" id="rg-hint" placeholder="e.g. my nickname + year I finished school">
    <p class="hint-t">Shown to you if you forget your password. Don't make it the same as the password.</p>
    <button class="btn btn-green btn-block" id="rg-go" style="margin-top:18px">Create account</button>`;
}

function wireReg(v) {
  const seg = v.querySelector('#rg-role'); if (!seg) return;
  let role = 'SEEKER';
  seg.querySelectorAll('button').forEach(b => b.onclick = () => {
    seg.querySelectorAll('button').forEach(x => x.classList.remove('on'));
    b.classList.add('on'); role = b.dataset.v;
  });
  v.querySelector('#rg-go').onclick = async () => {
    const btn = v.querySelector('#rg-go'); btn.disabled = true;
    const res = await api('/register', {
      body: {
        role, name: v.querySelector('#rg-name').value, phone: v.querySelector('#rg-phone').value,
        username: v.querySelector('#rg-u').value, password: v.querySelector('#rg-p').value,
        confirm: v.querySelector('#rg-p2').value, hint: v.querySelector('#rg-hint').value,
      }
    });
    btn.disabled = false;
    afterAuth(res, '#/welcome');
  };
}

// ---------- first-run admin setup ----------
async function viewSetup() {
  const v = document.getElementById('view');
  const gen = routeGen;
  const r = await api('/setup');
  if (stale(gen)) return;
  if (!r.ok || !r.available) { location.hash = '#/login'; return; }
  v.innerHTML = `<div class="auth-wrap"><div class="auth-card">
    <div class="auth-brand">
      <img class="auth-logo" src="/icons/icon-192.png" alt="HomeLinkKE logo" width="60" height="60">
      <div class="auth-name">Home<b>Link</b>KE</div>
      <p class="auth-tag">One-time setup — secure your platform before renters and landlords join.</p>
    </div>
    <span class="pill pill-o" style="margin-bottom:10px">${ic('shield')} One-time setup</span>
    <h1>Create the admin account</h1>
    <p class="auth-sub">This page only works once — the first account created here becomes the platform Admin. Do this right after deploying.</p>
    <label class="lbl">Admin name</label><input class="inp" id="su-name" placeholder="e.g. Isaac">
    <label class="lbl">WhatsApp number</label><input class="inp" id="su-phone" inputmode="tel" placeholder="e.g. 2547…">
    <label class="lbl">Username</label><input class="inp" id="su-u" placeholder="admin">
    <label class="lbl">Password</label><input class="inp" id="su-p" type="password" placeholder="At least 6 characters">
    <label class="lbl">Confirm password</label><input class="inp" id="su-p2" type="password">
    <label class="lbl">Password hint</label><input class="inp" id="su-hint">
    <button class="btn btn-green btn-block" id="su-go" style="margin-top:18px">Create admin & sign in</button>
  </div></div>`;
  v.querySelector('#su-go').onclick = async () => {
    const btn = v.querySelector('#su-go'); btn.disabled = true;
    const res = await api('/setup', {
      body: {
        name: v.querySelector('#su-name').value, phone: v.querySelector('#su-phone').value,
        username: v.querySelector('#su-u').value, password: v.querySelector('#su-p').value,
        confirm: v.querySelector('#su-p2').value, hint: v.querySelector('#su-hint').value,
      }
    });
    btn.disabled = false;
    afterAuth(res);
  };
}

// settings-style row (port of the prototype prow)
function prow(icon, title, sub, href) {
  return `<a class="prow" href="${href}">${ic(icon)}<span class="mid"><b>${esc(title)}</b>${sub ? `<small>${esc(sub)}</small>` : ''}</span>${ic('chev', 'chev')}</a>`;
}

// ---------- profile ----------
// Details are shown READ-ONLY; the Edit button opens the edit form (Save / Cancel).
async function viewProfile(edit) {
  if (!state.user) { location.hash = '#/login'; return; }
  const v = document.getElementById('view');
  const u = state.user;
  const isLandlord = u.role === 'LANDLORD';
  const roleTxt = u.role === 'ADMIN' ? 'Admin' : isLandlord ? 'Landlord' : 'Renter';

  // ---- read-only view ----
  if (!edit) {
    v.innerHTML = `<div class="sec-h"><h2>My profile</h2></div>
    <div class="auth-card">
      <div class="owner-row">
        <div class="avatar">${esc((u.name || u.username)[0].toUpperCase())}</div>
        <div><div class="nm" style="font-weight:800;font-size:16px">${esc(u.name || u.username)}</div>
        <div class="sb">@${esc(u.username)} · ${roleTxt} · joined ${fmtDate(u.createdAt)}</div></div>
      </div>
      <div style="margin-top:14px">
        <div class="kv"><span class="k">Full name</span><span class="v">${esc(u.name || '—')}</span></div>
        <div class="kv"><span class="k">WhatsApp number</span><span class="v">${esc(u.phone || '—')}</span></div>
        <div class="kv"><span class="k">Account</span><span class="v">${roleTxt}</span></div>
      </div>
      <button class="btn btn-green" id="pf-edit" style="margin-top:16px">${ic('edit')} Edit profile</button>
    </div>`;
    v.querySelector('#pf-edit').onclick = () => viewProfile(true);
  }

  // ---- edit form ----
  if (edit) {
    v.innerHTML = `<div class="sec-h"><h2>Edit profile</h2></div>
    <div class="auth-card">
      <label class="lbl">Full name</label><input class="inp" id="pf-name" value="${esc(u.name)}">
      <label class="lbl">WhatsApp number <span style="font-weight:500">(shown to the other side)</span></label>
      <input class="inp" id="pf-phone" inputmode="tel" value="${esc(u.phone)}">
      <div style="display:flex;gap:9px;margin-top:16px">
        <button class="btn btn-outline" id="pf-cancel" style="flex:1">Cancel</button>
        <button class="btn btn-green" id="pf-save" style="flex:1">Save changes</button>
      </div>
    </div>`;
    v.querySelector('#pf-cancel').onclick = () => viewProfile(false);
    v.querySelector('#pf-save').onclick = async () => {
      const body = { name: v.querySelector('#pf-name').value, phone: v.querySelector('#pf-phone').value };
      const res = await api('/me', { method: 'PUT', body });
      if (res.ok) { state.user = res.user; buildNav(); toast('Profile saved'); viewProfile(false); }
      else toast(res.error, true);
    };
  }

  const admRow = u.role === 'ADMIN'
    ? `<a class="prow" href="#/admin">${ic('gear')}<span class="mid"><b>Admin panel</b><small>Verifications, boosts, reports, users</small></span><span class="bn-badge" data-adm-badge="total" hidden></span>${ic('chev', 'chev')}</a>` : '';

  const tools = document.createElement('div');
  tools.innerHTML = `
    ${isLandlord ? landlordVerifyCard(u) : ''}

    <div class="plabel">${isLandlord ? 'Landlord tools' : 'Quick actions'}</div>
    <div class="prowbox">
      ${isLandlord ? prow('doc', 'My listings', 'Edit, mark taken, or boost your rooms', '#/mylistings')
        + prow('plus', 'Post a new listing', 'Free plan: 2 listings · verified: 5', '#/new') : ''}
      ${admRow}
      ${prow('heart', 'Favourites', 'Rooms you saved for later', '#/favorites')}
      ${prow('doc', 'Getting started guide', 'How it works — the guide from your first day', '#/welcome')}
      ${prow('shield', 'Privacy & safety', 'How HomeLinkKE handles your data', '#/privacy')}
    </div>
    <div class="plabel">Settings</div>
    <div class="prowbox">
      <button class="prow" data-theme-toggle type="button">${ic('gear')}<span class="mid"><b>Theme <span class="theme-state">System</span></b><small>Light, dark, or follow this device's setting</small></span></button>
      <button class="prow danger" id="pf-out">${ic('out')}<span class="mid"><b>Sign out</b><small>End this session on this device</small></span></button>
    </div>`;
  v.appendChild(tools);
  applyTheme(currentTheme()); // sync the toggle labels/state (light / dark / system)

  tools.querySelector('#pf-out').onclick = async () => {
    await api('/logout', { method: 'POST' });
    token.set(null); state.user = null; buildNav();
    location.hash = '#/home'; toast('Signed out');
  };

  if (state.user && state.user.role === 'ADMIN') refreshAdminCounts();
  wireVerifyCard(v);
}

function landlordVerifyCard(u) {
  const st = u.verifyStatus;
  const pill = st === 'APPROVED' ? '<span class="pill pill-g">Verified landlord — up to 5 listings</span>'
    : st === 'PENDING' ? '<span class="pill pill-o">Verification under review</span>'
    : st === 'REJECTED' ? `<span class="pill pill-r">Rejected${u.verifyNote ? ': ' + esc(u.verifyNote) : ''}</span>`
    : '<span class="pill pill-x">Not verified — 2 listing limit</span>';
  const needDocs = st === 'NONE' || st === 'REJECTED';
  return `<div class="auth-card" style="margin-top:14px" id="verify-card">
    <h3 class="font-disp" style="font-size:16px">Landlord verification</h3>
    <div style="margin:8px 0 4px">${pill}</div>
    <p class="hint-t" style="margin-bottom:8px">Verified landlords get a green badge on every listing and can post up to 5 listings. Upload a photo of your <b>National ID</b> and a proof of ownership (title deed, allotment letter, or a signed note from the compound owner).</p>
    ${needDocs ? `
      <div class="photo-grid" style="margin-top:10px">
        <div class="photo-cell" id="doc-id">${docCell('ID photo')}</div>
        <div class="photo-cell" id="doc-own">${docCell('Ownership doc')}</div>
      </div>
      <button class="btn btn-green btn-block" id="vf-send" style="margin-top:14px">Submit for verification</button>` : ''}
  </div>`;
}

function docCell(label) {
  return `<div class="ph-doc" style="width:100%;height:100%;display:grid;place-items:center;background:var(--card2);color:var(--ink2);font-size:11.5px;font-weight:700;text-align:center;cursor:pointer;padding:6px">
    ${ic('camera')}<span style="margin-top:4px">${esc(label)}</span></div>`;
}

function wireVerifyCard(v) {
  const card = v.querySelector('#verify-card'); if (!card) return;
  const docs = { docId: '', docOwn: '' };
  ['doc-id', 'doc-own'].forEach(key => {
    const cell = card.querySelector('#' + key);
    cell.onclick = async () => {
      const inp = document.createElement('input');
      inp.type = 'file'; inp.accept = 'image/*';
      inp.onchange = async () => {
        if (!inp.files[0]) return;
        toast('Processing image…');
        try {
          docs[key === 'doc-id' ? 'docId' : 'docOwn'] = await compressTo(inp.files[0], 260, 1400, 0.78);
          cell.innerHTML = `<img src="${docs[key === 'doc-id' ? 'docId' : 'docOwn']}" style="width:100%;height:100%;object-fit:cover">`;
        } catch (e) { toast(e.message, true); }
      };
      inp.click();
    };
  });
  card.querySelector('#vf-send').onclick = async () => {
    if (!docs.docId || !docs.docOwn) { toast('Upload both photos first', true); return; }
    const btn = card.querySelector('#vf-send'); btn.disabled = true;
    const res = await api('/verify', { body: docs });
    btn.disabled = false;
    if (res.ok) { toast('Submitted! The admin will review your documents.'); state.user.verifyStatus = 'PENDING'; viewProfile(); }
    else toast(res.error, true);
  };
}

// ---------- first-time welcome & guide (shown right after creating an account) ----------
// Role-aware: seekers get the anti-scam warning + how it works; landlords get the
// verify → post → boost guide. Reachable any time from Profile → Getting started.
function viewWelcome() {
  const v = document.getElementById('view');
  const isLL = state.user && state.user.role === 'LANDLORD';
  const hi = state.user && state.user.name ? ', ' + esc(state.user.name.split(' ')[0]) : '';
  const seeker = `
    <div class="notice notice-o" style="margin-top:14px">
      ${ic('shield')}<span><b>Never send money before you SEE the house.</b>
      No deposit, no booking fee, no reservation — nothing. Visit the house first, then pay the landlord directly.</span>
    </div>
    <div class="sec-block"><h3>How HomeLinkKE works</h3>
      <ol class="guide-list">
        <li><b>Search</b> — type a town in the search bar, or tap <b>Use my location</b> to see vacant houses nearest to you first.</li>
        <li><b>Open &amp; compare</b> — check the photos, rent, deposit, water and electricity on every listing before you chat.</li>
        <li><b>Chat</b> — message the landlord in the app or on WhatsApp. Ask anything — when to view, what is included.</li>
        <li><b>Visit &amp; view</b> — go see the house in daylight, ideally with a friend. A real landlord will welcome this.</li>
        <li><b>Pay only after viewing</b> — deposit and rent go directly to the landlord, never through HomeLinkKE.</li>
      </ol>
    </div>
    <div class="sec-block"><h3>Red flags — walk away</h3>
      <ul class="guide-list">
        <li>Anyone rushing you to send M-Pesa for a house you have not seen.</li>
        <li>“Pay first to book” stories, or rent too cheap for that area.</li>
        <li>Refusing a video call or a physical viewing.</li>
      </ul>
      <p class="hint-t">See a fake listing? Open it and tap <b>Report</b> — every report is reviewed by the admin.</p>
    </div>
    <a class="btn btn-green btn-block" href="#/home">${ic('pin')} Find houses near me</a>`;
  const landlord = `
    <div class="sec-block"><h3>Your 4 steps to renting out faster</h3>
      <ol class="guide-list">
        <li><b>Get verified</b> — Profile → verification: upload your ID and an ownership photo. The admin approves it, you earn the green badge and <b>5 listings instead of 2</b>. Renters trust the badge — verified landlords get more chats.</li>
        <li><b>Post your house</b> — tap <b>Post a new listing</b>: 8 quick steps. Pick the town, pin your exact gate on the Google map, add 3+ clear daylight photos.</li>
        <li><b>Boost for KES ${BOOST.amountKes}</b> — your listing sits at the <b>top for ${BOOST.days} days</b> for every renter browsing your town. Pay by M-Pesa, enter the code, and the admin turns it on.</li>
        <li><b>Reply fast</b> — houses whose landlord answers quickly rent much faster. Chats land in your Chats tab.</li>
      </ol>
    </div>
    <div class="notice notice-g" style="margin-top:14px">
      ${ic('shield')}<span><b>Be the landlord renters trust:</b> never ask for money before a viewing, and meet tenants at the house in daylight. HomeLinkKE never collects money on your behalf.</span>
    </div>
    <div style="display:flex;gap:10px;margin-top:16px">
      <a class="btn btn-green" style="flex:1" href="#/new">${ic('plus')} Post my first house</a>
      <a class="btn btn-outline" style="flex:1" href="#/profile">${ic('shield')} Verify me</a>
    </div>`;
  v.innerHTML = `
    <div class="auth-wrap" style="max-width:640px"><div class="auth-card">
      <div class="auth-brand">
        <img class="auth-logo" src="/icons/icon-192.png" alt="HomeLinkKE" width="54" height="54">
        <div class="auth-name">Welcome to Home<b>Link</b>KE${hi}!</div>
        <p class="auth-tag">${isLL ? 'Your account is ready — here is how to rent out fast and safe.' : 'Your account is ready — here is how to find a house safely.'}</p>
      </div>
      ${isLL ? landlord : seeker}
    </div></div>`;
}

// HomeLinkKE — Admin panel: verifications, boosts, reports, listings, users, settings
// Sections with something waiting show an orange notification badge on their tab
// (live — the badge poll refreshes them, see refreshAdminCounts in ui.js).
const ADM_TABS = [['overview', 'Overview'], ['verifications', 'Verifications'], ['boosts', 'Boosts'], ['reports', 'Reports'], ['listings', 'Listings'], ['users', 'Users'], ['settings', 'Settings']];
const ADM_TAB_BADGE = { verifications: 'verifications', boosts: 'boosts', reports: 'reports' };

async function viewAdmin(tab) {
  if (!state.user || state.user.role !== 'ADMIN') { location.hash = '#/login'; return; }
  tab = ADM_TABS.some(t => t[0] === tab) ? tab : 'overview';
  const v = document.getElementById('view');
  v.innerHTML = `<div class="sec-h"><h2>Admin</h2></div>
    <div class="adm-tabs">${ADM_TABS.map(t => `<button class="chip ${t[0] === tab ? 'on' : ''}" data-t="${t[0]}">${t[1]}${ADM_TAB_BADGE[t[0]] ? `<span class="adm-dot" data-adm-badge="${ADM_TAB_BADGE[t[0]]}" hidden></span>` : ''}</button>`).join('')}</div>
    <div id="adm-body"><div class="skel" style="height:120px"></div></div>`;
  v.querySelectorAll('.adm-tabs .chip').forEach(c => c.onclick = () => { location.hash = '#/admin/' + c.dataset.t; });
  const body = v.querySelector('#adm-body');
  refreshAdminCounts(); // light up the tab badges right away

  if (tab === 'overview') {
    const r = await api('/admin/stats');
    if (!r.ok) { body.innerHTML = emptyBox('Error', r.error); return; }
    const s = r.stats;
    body.innerHTML = `<div class="stat-grid">
      <div class="stat"><div class="n">${s.users}</div><div class="k">Users</div></div>
      <div class="stat"><div class="n">${s.landlords}</div><div class="k">Landlords</div></div>
      <div class="stat"><div class="n">${s.listings}</div><div class="k">Listings</div></div>
      <div class="stat"><div class="n">${s.available}</div><div class="k">Available now</div></div>
      <div class="stat"><div class="n">${s.verifications}</div><div class="k">Verifications waiting</div></div>
      <div class="stat"><div class="n">${s.boosts}</div><div class="k">Boosts to confirm</div></div>
      <div class="stat"><div class="n">${s.reports}</div><div class="k">Open reports</div></div>
      <div class="stat"><div class="n">${s.views}</div><div class="k">Total views</div></div>
    </div>
    <div class="notice notice-g" style="margin-top:14px">${ic('shield')}<span>Orange badges on <b>Verifications</b>, <b>Boosts</b> and <b>Reports</b> mean someone is waiting on you — they update live.</span></div>`;
  }

  if (tab === 'verifications') {
    const r = await api('/admin/verifications');
    if (!r.ok) { body.innerHTML = emptyBox('Error', r.error); return; }
    body.innerHTML = r.items.length ? r.items.map(u => `
      <div class="row-card" data-u="${u.id}">
        <div class="row-top"><div>
          <div class="row-title">${esc(u.name)} <span style="color:var(--ink3);font-weight:600">@${esc(u.username)}</span></div>
          <div class="row-sub">${esc(u.phone)} · requested ${timeAgo(u.created_at)}</div></div></div>
        <div class="doc-thumbs">
          ${u.doc_id ? `<img src="${u.doc_id}" data-full="${u.doc_id}" alt="ID" title="Tap to open full size">` : ''}
          ${u.doc_own ? `<img src="${u.doc_own}" data-full="${u.doc_own}" alt="Ownership doc" title="Tap to open full size">` : ''}
        </div>
        <p class="hint-t" style="margin-top:6px">Tap a document to open it full size. Compare the face to the ID and the name to the ownership document.</p>
        <div class="row-acts">
          <button class="btn btn-green btn-sm" data-dec="approve">Approve</button>
          <button class="btn btn-danger btn-sm" data-dec="reject">Reject</button>
        </div>
      </div>`).join('') : emptyBox('No pending verifications', 'Landlord verification requests will appear here.');
    body.querySelectorAll('.doc-thumbs img').forEach(im => im.onclick = () => lightbox(im.dataset.full));
    body.querySelectorAll('[data-dec]').forEach(b => b.onclick = async () => {
      const card = b.closest('[data-u]');
      if (b.dataset.dec === 'reject') {
        modal(`<h3>Reject verification</h3><label class="lbl">Reason shown to the landlord</label>
          <input class="inp" id="rj-note" placeholder="e.g. ID photo is blurred">
          <button class="btn btn-primary btn-block" style="margin-top:14px" id="rj-go">Reject</button>`,
          m => m.querySelector('#rj-go').onclick = async () => {
            const res = await api('/admin/verify/' + card.dataset.u, { body: { decision: 'reject', note: m.querySelector('#rj-note').value } });
            closeModal(); if (res.ok) { toast('Rejected'); viewAdmin('verifications'); } else toast(res.error, true);
          });
      } else {
        const res = await api('/admin/verify/' + card.dataset.u, { body: { decision: 'approve' } });
        if (res.ok) { toast('Approved — the landlord is now verified'); viewAdmin('verifications'); } else toast(res.error, true);
      }
    });
  }

  if (tab === 'boosts') {
    const r = await api('/admin/boosts');
    if (!r.ok) { body.innerHTML = emptyBox('Error', r.error); return; }
    const paybill = state.settings.paybill_number || '0143374333';
    body.innerHTML = r.items.length ? r.items.map(b => `
      <div class="row-card" data-b="${b.id}">
        <div class="row-title">${esc(b.ltitle)}</div>
        <div class="row-sub">by @${esc(b.uname)} · targets <b>${esc(b.town || '—')}</b> · requested ${timeAgo(b.createdAt)}
          ${b.mpesaCode ? ` · M-Pesa code: <b>${esc(b.mpesaCode)}</b>` : ''}</div>
        <p class="hint-t" style="margin-top:6px">Check that KES 200 arrived on ${esc(paybill)} (Isaac Bridget) for this code, then activate.</p>
        <div class="row-acts">
          <button class="btn btn-green btn-sm" data-d="approve">${ic('check')} Confirm & boost 7 days</button>
          <button class="btn btn-danger btn-sm" data-d="decline">Decline</button>
        </div>
      </div>`).join('') : emptyBox('No pending boosts', 'Boost payments awaiting confirmation will appear here.');
    body.querySelectorAll('[data-d]').forEach(b => b.onclick = async () => {
      const res = await api('/admin/boosts/' + b.closest('[data-b]').dataset.b, { body: { decision: b.dataset.d } });
      if (res.ok) { toast(b.dataset.d === 'approve' ? 'Boost activated for 7 days' : 'Declined'); viewAdmin('boosts'); } else toast(res.error, true);
    });
  }

  if (tab === 'reports') {
    const r = await api('/admin/reports');
    if (!r.ok) { body.innerHTML = emptyBox('Error', r.error); return; }
    body.innerHTML = r.items.length ? r.items.map(rep => `
      <div class="row-card" data-r="${rep.id}">
        <div class="row-top"><div>
          <div class="row-title">${esc(rep.reason)}</div>
          <div class="row-sub">on <a href="#/listing/${rep.listingId}" style="color:var(--ember);font-weight:700">${esc(rep.ltitle)}</a>
           ${rep.uname ? ' · by @' + esc(rep.uname) : ''} · ${timeAgo(rep.createdAt)}</div>
          ${rep.note ? `<div class="row-sub" style="margin-top:4px">"${esc(rep.note)}"</div>` : ''}
          <div class="row-sub" style="margin-top:4px">Listing status: ${esc(rep.lstatus)}</div>
        </div></div>
        <div class="row-acts">
          <button class="btn btn-outline btn-sm" data-a="remove">${ic('eye')} Hide listing</button>
          <button class="btn btn-danger btn-sm" data-a="delete">${ic('trash')} Delete forever</button>
          <button class="btn btn-outline btn-sm" data-a="dismiss">Dismiss report</button>
        </div>
      </div>`).join('') : emptyBox('No open reports', 'Student reports will appear here.');
    body.querySelectorAll('[data-a]').forEach(b => b.onclick = async () => {
      const act = b.dataset.a, rid = b.closest('[data-r]').dataset.r;
      if (act === 'delete') {
        confirmDlg('Delete this listing forever?',
          'It will be wiped completely — the listing, its photos and every chat about it. It will NOT remain on any list, and the report closes with it. This cannot be undone.',
          'Delete forever', async () => {
            const res = await api('/admin/reports/' + rid, { body: { action: 'delete' } });
            if (res.ok) { toast('Deleted for good'); viewAdmin('reports'); } else toast(res.error, true);
          }, true);
        return;
      }
      const res = await api('/admin/reports/' + rid, { body: { action: act } });
      if (res.ok) { toast('Done'); viewAdmin('reports'); } else toast(res.error, true);
    });
  }

  if (tab === 'listings') {
    const r = await api('/admin/listings');
    if (!r.ok) { body.innerHTML = emptyBox('Error', r.error); return; }
    body.innerHTML = r.items.length ? r.items.map(l => `
      <div class="row-card" data-l="${l.id}">
        <div class="row-top"><div>
          <div class="row-title"><a href="#/listing/${l.id}">${esc(l.title)}</a></div>
          <div class="row-sub">${kes(l.rent)} · ${esc(l.town || '—')}${l.area ? ' · ' + esc(l.area) : ''} · @${esc(l.owner)} · ${l.views} views · ${timeAgo(l.createdAt)}</div></div>
          <span class="pill ${l.status === 'AVAILABLE' ? 'pill-g' : l.status === 'TAKEN' ? 'pill-x' : 'pill-r'}">${esc(l.status)}</span>
        </div>
        <div class="row-acts">
          ${l.status !== 'REMOVED'
            ? `<button class="btn btn-outline btn-sm" data-x="remove">${ic('eye')} Hide</button>`
            : `<button class="btn btn-outline btn-sm" data-x="restore">${ic('check')} Restore</button>`}
          <button class="btn btn-danger btn-sm" data-x="delete">${ic('trash')} Delete forever</button>
        </div>
      </div>`).join('') : emptyBox('No listings', 'Nothing has been posted yet.');
    body.querySelectorAll('[data-x]').forEach(b => b.onclick = async () => {
      const id = b.closest('[data-l]').dataset.l;
      if (b.dataset.x === 'delete') {
        confirmDlg('Delete this listing forever?',
          'It will be wiped completely — the listing, its photos and every chat about it. It will NOT remain on any list. This cannot be undone.',
          'Delete forever', async () => {
            const res = await api('/admin/listings/' + id + '/delete', { method: 'POST', body: {} });
            if (res.ok) { toast('Deleted for good'); viewAdmin('listings'); } else toast(res.error, true);
          }, true);
        return;
      }
      const res = await api('/admin/listings/' + id + '/' + b.dataset.x, { method: 'POST', body: {} });
      if (res.ok) { toast('Done'); viewAdmin('listings'); } else toast(res.error, true);
    });
  }

  if (tab === 'users') {
    const r = await api('/admin/users');
    if (!r.ok) { body.innerHTML = emptyBox('Error', r.error); return; }
    body.innerHTML = r.items.map(u => `
      <div class="row-card" data-u="${u.id}">
        <div class="row-top"><div>
          <div class="row-title">${esc(u.name)} <span style="color:var(--ink3);font-weight:600">@${esc(u.username)}</span></div>
          <div class="row-sub">${u.role === 'SEEKER' ? 'Renter' : esc(u.role)} · ${esc(u.phone)} · joined ${fmtDate(u.created_at)}</div></div>
          <div style="display:flex;flex-direction:column;gap:5px;align-items:flex-end">
            ${u.verify_status === 'APPROVED' ? '<span class="pill pill-g">Verified</span>' : ''}
            ${u.suspended ? '<span class="pill pill-r">Suspended</span>' : ''}
          </div>
        </div>
        ${u.role !== 'ADMIN' ? `<div class="row-acts">
          <button class="btn btn-outline btn-sm" data-s="${u.suspended ? 0 : 1}">
            ${u.suspended ? 'Unsuspend' : 'Suspend'}</button>
          <button class="btn btn-danger btn-sm" data-udel="${u.id}">${ic('trash')} Delete account</button>
        </div>` : ''}
      </div>`).join('');
    body.querySelectorAll('[data-s]').forEach(b => b.onclick = async () => {
      const res = await api('/admin/users/' + b.closest('[data-u]').dataset.u + '/suspend', { body: { on: b.dataset.s === '1' } });
      if (res.ok) { toast('Done'); viewAdmin('users'); } else toast(res.error, true);
    });
    body.querySelectorAll('[data-udel]').forEach(b => b.onclick = () => {
      const card = b.closest('[data-u]');
      confirmDlg('Delete this account forever?',
        'The user and everything they own will be wiped — their listings, photos and all their chats. They will NOT remain on the list. This cannot be undone.',
        'Delete forever', async () => {
          const res = await api('/admin/users/' + card.dataset.u + '/delete', { method: 'POST', body: {} });
          if (res.ok) { toast('Account deleted for good'); viewAdmin('users'); } else toast(res.error, true);
        }, true);
    });
  }

  if (tab === 'settings') {
    body.innerHTML = `<div class="auth-card">
      <h3 class="font-disp" style="font-size:16px">Boost payment details</h3>
      <p class="hint-t" style="margin-bottom:6px">Landlords are told to send KES 200 to this M-Pesa number when boosting.</p>
      <label class="lbl">M-Pesa number</label><input class="inp" id="st-num" value="${esc(state.settings.paybill_number || '')}">
      <label class="lbl">Account name</label><input class="inp" id="st-name" value="${esc(state.settings.paybill_name || '')}">
      <button class="btn btn-green btn-block" id="st-save" style="margin-top:16px">Save settings</button>
    </div>`;
    body.querySelector('#st-save').onclick = async () => {
      const res = await api('/settings', {
        method: 'PUT',
        body: { paybill_number: body.querySelector('#st-num').value.trim(), paybill_name: body.querySelector('#st-name').value.trim() }
      });
      if (res.ok) {
        state.settings.paybill_number = body.querySelector('#st-num').value.trim();
        state.settings.paybill_name = body.querySelector('#st-name').value.trim();
        toast('Settings saved');
      } else toast(res.error, true);
    };
  }
}

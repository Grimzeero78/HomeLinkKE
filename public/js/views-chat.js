// HomeLinkKE — Chats: conversation list + live thread (2.5s polling)
// WhatsApp-style actions: long-press a bubble → Copy / Edit / Delete for me / Delete for everyone
// Unique: Quick-reply chips (one-tap common questions) — role aware
let chatTimer = null;

const QR_STUDENT = [
  'Is it still available?',
  'Can I view it this weekend?',
  'What is the total monthly cost?',
  'Is water included in the rent?',
];
const QR_LANDLORD = [
  'Yes, it is available.',
  'When would you like to come for viewing?',
  'Viewings: Mon–Sat, 8 AM – 6 PM.',
  'Deposit is one month rent.',
];

async function viewChats() {
  if (!state.user) { location.hash = '#/login'; return; }
  const v = document.getElementById('view');
  const gen = routeGen; // #view is never replaced — only its innerHTML — so guard with the route token
  v.innerHTML = `<div class="sec-h"><h2>Chats</h2></div><div class="skel" style="height:74px"></div><div class="skel" style="height:74px"></div>`;
  const load = async () => {
    const r = await api('/convs');
    if (stale(gen)) return;            // user navigated elsewhere — never paint over the new page
    if (!r.ok) { v.innerHTML = emptyBox('Could not load chats', r.error); return; }
    if (!r.items.length) {
      v.innerHTML = `<div class="sec-h"><h2>Chats</h2></div>` + emptyBox('No chats yet',
        'Open any listing and tap "Message in app" to start talking to the landlord.');
      return;
    }
    v.innerHTML = `<div class="sec-h"><h2>Chats</h2></div>` + r.items.map(c => `
      <a class="conv-row" href="#/chat/${c.id}">
        <div class="conv-av avatar" style="border-radius:50%">${esc((c.otherName || '?')[0].toUpperCase())}
          ${c.unread ? `<span class="conv-un">${c.unread > 9 ? '9+' : c.unread}</span>` : ''}</div>
        <div class="conv-main">
          <div class="conv-top"><span class="conv-name">${esc(c.otherName || 'User')}</span>
            <span class="conv-time">${timeAgo(c.lastAt)}</span></div>
          <div class="conv-sub"><span class="conv-last">${esc(c.lastMsg || 'New conversation')}</span>
            <span class="conv-listing">${kes(c.lrent)}/${perShort(c.lperiod)}</span></div>
        </div>
      </a>`).join('');
    refreshUnread();
  };
  await load();
  clearInterval(chatTimer);
  chatTimer = setInterval(() => { if (!document.hidden) load(); }, 12000);
  onLeave(() => clearInterval(chatTimer));
}

async function viewThread(id) {
  if (!state.user) { location.hash = '#/login'; return; }
  const v = document.getElementById('view');
  const gen = routeGen;
  v.innerHTML = `<div class="pageload"><div class="skel" style="height:70px"></div><div class="skel" style="height:300px"></div></div>`;

  const info = await api('/convs/' + id);
  if (stale(gen)) return; // tapped Map/Chat while loading — don't repaint this thread over it
  if (!info.ok) { v.innerHTML = emptyBox('Conversation not found', info.error); return; }
  const { listing, other } = info;
  const me = state.user.id;
  const iAmLandlord = state.user.role === 'LANDLORD';

  const quickReplies = (iAmLandlord ? QR_LANDLORD : QR_STUDENT).map(q =>
    `<button type="button" class="qr-chip">${esc(q)}</button>`).join('');

  v.innerHTML = `
    <div class="thread-head">
      <button class="back-m" id="th-back">${ic('back')}</button>
      <div class="avatar" style="width:38px;height:38px;font-size:14px">${esc((other.name || '?')[0].toUpperCase())}</div>
      <div style="flex:1;min-width:0">
        <div style="font-weight:800;font-size:14.5px">${esc(other.name || other.username)}
          ${other.verifyStatus === 'APPROVED' ? `<span class="vbadge">${ic('shield')}</span>` : ''}</div>
        <div style="font-size:11.5px;color:var(--ink2)">${esc(listing.title)} · ${kes(listing.rent)}/${perShort(listing.period)}</div>
      </div>
      ${other.phone ? `<a class="btn btn-green btn-sm" href="tel:${esc(other.phone)}">${ic('phone')}</a>
      <a class="btn btn-primary btn-sm" target="_blank" rel="noopener" href="${waLink(other.phone, 'Hi! About “' + listing.title + '” on HomeLinkKE…')}">${ic('wa')}</a>` : ''}
      <button class="back-m" id="th-report" title="Report" style="flex:none">${ic('flag')}</button>
    </div>
    <div class="thread">
      <div class="thread-msgs" id="th-msgs"></div>
      <div class="qr-row" id="th-qr">${quickReplies}</div>
      <div class="edit-bar" id="th-editbar" hidden>
        <span style="flex:1">${ic('edit')} Editing message</span>
        <button type="button" class="edit-x" id="th-editcancel">${ic('x')} Cancel</button>
      </div>
      <div class="thread-bar">
        <input class="inp" id="th-inp" placeholder="Type a message…" autocomplete="off">
        <button class="btn btn-green" id="th-send" style="flex:none">${ic('send')}</button>
      </div>
    </div>
    <p class="hint-t" style="margin-top:8px">${ic('shield')} Agree on a viewing first. Never send money before you have seen the room.</p>`;

  v.querySelector('#th-back').onclick = () => { location.hash = '#/chats'; };
  v.querySelector('#th-report').onclick = () => openReport(info.listing.id || info.conv.listingId);

  const msgsEl = v.querySelector('#th-msgs');
  const inp = v.querySelector('#th-inp');
  const editBar = v.querySelector('#th-editbar');
  let lastId = 0;
  let editingMid = null; // message currently being edited

  const timeStr = ts => new Date(ts).toLocaleTimeString('en-KE', { hour: '2-digit', minute: '2-digit' });

  function bubble(m) {
    const mine = m.senderId === me;
    if (m.deleted) {
      return `<div class="bub ${mine ? 'me' : ''} bub-del" data-mid="${m.id}" data-ts="${m.createdAt}">
        ${ic('x')}<i>${mine ? 'You deleted this message' : 'This message was deleted'}</i>
        <span class="bub-time">${timeStr(m.createdAt)}</span></div>`;
    }
    // WhatsApp-style ticks: ✓ sent, ✓✓ read (blue) — driven by readAt from the server
    const tick = mine ? `<span class="bub-tick${m.readAt ? ' rd' : ''}">${m.readAt ? '✓✓' : '✓'}</span>` : '';
    return `<div class="bub ${mine ? 'me' : ''}" data-mid="${m.id}" data-ts="${m.createdAt}" data-text="${esc(m.text)}">${esc(m.text)}${m.edited ? '<span class="bub-ed">edited</span>' : ''}<span class="bub-time">${timeStr(m.createdAt)}${tick}</span></div>`;
  }

  // replace EVERY bubble for this message id (there can be more than one after races) —
  // leaving a stale duplicate behind was the “deleted but still showing text” bug
  function retypeBubble(m) {
    msgsEl.querySelectorAll(`.bub[data-mid="${m.id}"]`).forEach(b => {
      const tmp = document.createElement('div');
      tmp.innerHTML = bubble(m);
      b.replaceWith(tmp.firstElementChild);
    });
  }

  // ONE place to add messages: if a bubble for this id already exists, refresh it instead of
  // inserting a duplicate. The old code inserted blindly, so a poll that raced with a send
  // rendered the same message twice — the “enter sends 2 messages” report.
  function addMsg(m) {
    if (msgsEl.querySelector(`.bub[data-mid="${m.id}"]`)) { retypeBubble(m); return; }
    msgsEl.insertAdjacentHTML('beforeend', bubble(m));
  }

  // ----- message actions (long-press on touch, right-click on desktop) -----
  function openBubMenu(bub) {
    if (bub.classList.contains('bub-del')) return;
    const mid = +bub.dataset.mid;
    const mine = bub.classList.contains('me');
    const fresh = Date.now() - (+bub.dataset.ts) < 15 * 60_000;
    const item = (icon, label, act, danger) =>
      `<button type="button" class="bact ${danger ? 'bact-d' : ''}" data-act="${act}">${ic(icon)} ${label}</button>`;
    const acts = [item('doc', 'Copy', 'copy')];
    if (mine && fresh) acts.push(item('edit', 'Edit', 'edit'));
    acts.push(item('eye', 'Delete for me', 'delme'));
    if (mine) acts.push(item('trash', 'Delete for everyone', 'delall', true));
    modal(`<h3 style="font-size:15px;margin-bottom:10px">Message actions</h3>
      <div class="bubble-text-prev">${esc(bub.dataset.text || '')}</div>
      <div style="display:flex;flex-direction:column;gap:6px;margin-top:12px">${acts.join('')}</div>`,
      m => {
        m.querySelectorAll('.bact').forEach(b => b.onclick = () => {
          const act = b.dataset.act;
          closeModal();
          if (act === 'copy') copyText(bub.dataset.text || '');
          else if (act === 'edit') startEdit(bub);
          else if (act === 'delme') deleteForMe(mid);
          else if (act === 'delall') confirmDlg('Delete for everyone?',
            'This message will be removed for both of you. This cannot be undone.',
            'Delete', () => deleteForAll(mid, +bub.dataset.ts), true);
        });
      });
  }

  async function copyText(t) {
    try { await navigator.clipboard.writeText(t); toast('Copied to clipboard'); }
    catch (e) {
      const ta = document.createElement('textarea');
      ta.value = t; document.body.appendChild(ta); ta.select();
      try { document.execCommand('copy'); toast('Copied to clipboard'); } catch (e2) { toast('Could not copy', true); }
      ta.remove();
    }
  }

  function startEdit(bub) {
    editingMid = +bub.dataset.mid;
    inp.value = bub.dataset.text || '';
    editBar.hidden = false;
    inp.focus();
    inp.scrollIntoView({ block: 'nearest' });
  }
  function cancelEdit() {
    editingMid = null;
    inp.value = '';
    editBar.hidden = true;
  }
  v.querySelector('#th-editcancel').onclick = cancelEdit;

  async function deleteForMe(mid) {
    const r = await api('/convs/' + id + '/messages/' + mid + '?scope=me', { method: 'DELETE' });
    if (!r.ok) { toast(r.error, true); return; }
    msgsEl.querySelectorAll(`.bub[data-mid="${mid}"]`).forEach(b => b.remove());
  }
  async function deleteForAll(mid, ts) {
    const r = await api('/convs/' + id + '/messages/' + mid + '?scope=all', { method: 'DELETE' });
    if (!r.ok) { toast(r.error, true); return; }
    retypeBubble({ id: mid, senderId: me, createdAt: ts, deleted: 1 });
  }

  let lpTimer = null;
  msgsEl.addEventListener('contextmenu', e => {
    const b = e.target.closest('.bub');
    if (!b) return;
    e.preventDefault();
    openBubMenu(b);
  });
  msgsEl.addEventListener('touchstart', e => {
    const b = e.target.closest('.bub');
    if (!b || b.classList.contains('bub-del')) return;
    lpTimer = setTimeout(() => { lpTimer = null; if (navigator.vibrate) navigator.vibrate(25); openBubMenu(b); }, 450);
  }, { passive: true });
  ['touchend', 'touchmove', 'touchcancel'].forEach(ev =>
    msgsEl.addEventListener(ev, () => { if (lpTimer) { clearTimeout(lpTimer); lpTimer = null; } }, { passive: true }));

  // ----- quick replies: tap to fill the input (edit before sending if you like) -----
  v.querySelectorAll('.qr-chip').forEach(chip => chip.onclick = () => {
    cancelEdit();          // clears edit state + input first
    inp.value = chip.textContent;
    inp.focus();
    inp.scrollIntoView({ block: 'nearest' });
  });

  async function poll(initial) {
    if (!msgsEl.isConnected) return; // thread left the DOM (navigated away) — nothing to update
    const r = await api('/convs/' + id + '/messages?after=' + lastId);
    if (!msgsEl.isConnected) return;
    if (!r.ok) return;
    const nearBottom = msgsEl.scrollHeight - msgsEl.scrollTop - msgsEl.clientHeight < 160;
    if (r.items.length) {
      r.items.forEach(m => { lastId = Math.max(lastId, m.id); addMsg(m); });
      if (initial || nearBottom) msgsEl.scrollTop = msgsEl.scrollHeight;
    }
    // sync tail: edits / deletes / read receipts that happened AFTER we first drew a bubble
    // (the old poll only fetched messages newer than lastId, so the other side's
    //  "delete for everyone" or an edit never reached an open thread)
    if (r.sync && r.sync.length) {
      r.sync.forEach(m => {
        if (msgsEl.querySelector(`.bub[data-mid="${m.id}"]`)) retypeBubble(m);
      });
    }
    // typing indicator (other side typed within the last 6s)
    const ex = msgsEl.querySelector('.typing');
    if (r.otherTyping && !ex) {
      msgsEl.insertAdjacentHTML('beforeend', '<div class="typing"><i></i><i></i><i></i></div>');
      if (initial || nearBottom) msgsEl.scrollTop = msgsEl.scrollHeight;
    } else if (!r.otherTyping && ex) ex.remove();
    refreshUnread();
  }

  // tell the other side we are typing (throttled to one ping per 2.5s)
  let lastTypingSent = 0;
  inp.addEventListener('input', () => {
    const now = Date.now();
    if (now - lastTypingSent > 2500) { lastTypingSent = now; api('/convs/' + id + '/typing', { body: {} }); }
  });

  let sending = false;
  async function send() {
    if (sending) return;                 // one request at a time — no double POST on double-Enter
    const text = inp.value.trim();
    if (!text) return;
    sending = true;
    try {
      if (editingMid) {
        const r = await api('/convs/' + id + '/messages/' + editingMid, { method: 'PATCH', body: { text } });
        if (!r.ok) { toast(r.error, true); return; }
        const bub = msgsEl.querySelector(`.bub[data-mid="${editingMid}"]`);
        retypeBubble({ id: editingMid, senderId: me, createdAt: bub ? +bub.dataset.ts : Date.now(), text, edited: 1 });
        cancelEdit();
        return;
      }
      inp.value = '';
      const r = await api('/convs/' + id + '/messages', { body: { text } });
      if (!r.ok) { toast(r.error, true); inp.value = text; return; }
      addMsg({ senderId: me, text, createdAt: Date.now(), id: r.id });
      lastId = Math.max(lastId, r.id);
      msgsEl.scrollTop = msgsEl.scrollHeight;
    } finally {
      sending = false;
    }
  }
  v.querySelector('#th-send').onclick = send;
  inp.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.repeat) { e.preventDefault(); send(); } });

  await poll(true);
  clearInterval(chatTimer);
  // 4s while you are looking at the app; ~24s when the tab is in the background.
  // Deep background backoff is what keeps the API cheap enough to stay on
  // Cloudflare's free tier at 1000 users.
  let tickN = 0;
  chatTimer = setInterval(() => { tickN++; if (document.hidden && tickN % 6 !== 1) return; poll(false); }, 4000);
  onLeave(() => { clearInterval(chatTimer); });
}

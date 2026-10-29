// ============================================================
// HomeLinkKE API — Cloudflare Pages Functions (catch-all)
// File: functions/api/[[route]].js
// Binding required: D1 database bound as `DB`
// ============================================================

const DAY = 86400000;

const json = (o, s = 200) => new Response(JSON.stringify(o), {
  status: s,
  // nosniff: Pages _headers only apply to static assets — Functions must set it themselves
  headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' }
});
const ok = (o = {}) => json({ ok: true, ...o });
const bad = (error, s = 400) => json({ ok: false, error }, s);

// ---------- helpers ----------
const S = v => String(v == null ? '' : v).trim();
const N = v => { const n = Number(v); return Number.isFinite(n) ? n : 0; };
const bool = v => (v === true || v === 'true' || v === 1 || v === 'Yes') ? 1 : 0;

function b64e(buf) { let s = ''; const a = new Uint8Array(buf); for (let i = 0; i < a.length; i++) s += String.fromCharCode(a[i]); return btoa(s); }
function rand(len) {
  const a = new Uint8Array(len);
  crypto.getRandomValues(a);
  return b64e(a).replace(/[^a-zA-Z0-9]/g, '').slice(0, len);
}
async function hashPw(pw, salt) {
  const km = await crypto.subtle.importKey('raw', new TextEncoder().encode(pw), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt: new TextEncoder().encode(salt), iterations: 100000, hash: 'SHA-256' }, km, 256);
  return b64e(bits);
}

const pubUser = u => u ? {
  id: u.id, username: u.username, name: u.name, role: u.role, phone: u.phone,
  verifyStatus: u.verify_status, verifyNote: u.verify_note, suspended: !!u.suspended, createdAt: u.created_at
} : null;

async function getSession(request, env) {
  const h = request.headers.get('Authorization') || '';
  const t = h.startsWith('Bearer ') ? h.slice(7).trim() : '';
  if (!t) return null;
  return await env.DB.prepare(
    'SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ? AND s.expires_at > ?'
  ).bind(t, Date.now()).first();
}
async function newSession(env, uid) {
  const t = rand(40);
  await env.DB.prepare('INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)')
    .bind(t, uid, Date.now() + 30 * DAY).run();
  return t;
}

// strict image check: real raster types only. The old startsWith('data:image/') also let
// image/svg+xml through, which is a script-capable format when opened outside an <img>
const IMG_RE = /^data:image\/(png|jpe?g|webp|gif);base64,[A-Za-z0-9+/=]+$/;
const isImg = (d, max = 1200000) => typeof d === 'string' && d.length < max && IMG_RE.test(d);

// ---------- rate limiting (per isolate; cheap in-memory sliding window) ----------
const RL = new Map();
function rateLimit(key, max, windowMs) {
  const now = Date.now();
  // prune expired entries instead of wipe-all: a flood of unique keys used to reset
  // every counter (including login brute-force windows) once the map hit its cap
  if (RL.size > 8000) {
    for (const [k, e] of RL) { if (now - e[0] > e[2]) RL.delete(k); }
    if (RL.size > 20000) RL.clear(); // absolute memory cap
  }
  const e = RL.get(key);
  if (!e || now - e[0] > windowMs) { RL.set(key, [now, 1, windowMs]); return true; }
  e[1]++;
  return e[1] <= max;
}
const tooMany = () => bad('Too many requests — please slow down and try again shortly.', 429);
const ipOf = request => (request.headers.get('cf-connecting-ip') || 'unknown').split(',')[0].trim();

// constant-time string compare (password hashes)
function safeEq(a, b) {
  a = String(a); b = String(b);
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

// ---------- auto schema (runs once per isolate; makes deployment zero-config) ----------
const SCHEMA = String.raw`
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE COLLATE NOCASE,
  pass_hash TEXT NOT NULL,
  pass_hint TEXT NOT NULL DEFAULT '',
  name TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'SEEKER',
  phone TEXT NOT NULL DEFAULT '',
  verify_status TEXT NOT NULL DEFAULT 'NONE',
  doc_id TEXT NOT NULL DEFAULT '',
  doc_own TEXT NOT NULL DEFAULT '',
  verify_note TEXT NOT NULL DEFAULT '',
  suspended INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS listings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ownerId INTEGER NOT NULL,
  title TEXT NOT NULL,
  ptype TEXT NOT NULL DEFAULT 'Bedsitter',
  units INTEGER NOT NULL DEFAULT 1,
  furnishing TEXT NOT NULL DEFAULT 'Unfurnished',
  floor TEXT NOT NULL DEFAULT 'Ground',
  town TEXT NOT NULL DEFAULT '',
  area TEXT NOT NULL DEFAULT '',
  landmark TEXT NOT NULL DEFAULT '',
  lat REAL,
  lng REAL,
  road TEXT NOT NULL DEFAULT 'Tarmac',
  rent INTEGER NOT NULL,
  period TEXT NOT NULL DEFAULT 'Per Month',
  terms TEXT NOT NULL DEFAULT '',
  deposit INTEGER NOT NULL DEFAULT 0,
  fees TEXT NOT NULL DEFAULT 'None',
  negotiable INTEGER NOT NULL DEFAULT 0,
  water TEXT NOT NULL DEFAULT 'Included in rent',
  waterCost TEXT NOT NULL DEFAULT '',
  waterSched TEXT NOT NULL DEFAULT '',
  waterTank TEXT NOT NULL DEFAULT 'No',
  elec TEXT NOT NULL DEFAULT 'Own token meter',
  elecCost TEXT NOT NULL DEFAULT '',
  wifi TEXT NOT NULL DEFAULT 'Not available',
  wifiCost TEXT NOT NULL DEFAULT '',
  wifiProvider TEXT NOT NULL DEFAULT '',
  garbage TEXT NOT NULL DEFAULT 'Included',
  backup TEXT NOT NULL DEFAULT 'None',
  bath TEXT NOT NULL DEFAULT 'Shared',
  kitchen TEXT NOT NULL DEFAULT 'Shared',
  cooking TEXT NOT NULL DEFAULT 'Yes',
  balcony TEXT NOT NULL DEFAULT 'No',
  tile TEXT NOT NULL DEFAULT 'Tiled',
  ceiling TEXT NOT NULL DEFAULT 'Yes',
  wardrobe TEXT NOT NULL DEFAULT 'No',
  bed TEXT NOT NULL DEFAULT 'No',
  hotShower TEXT NOT NULL DEFAULT 'No',
  security TEXT NOT NULL DEFAULT '[]',
  tenantPref TEXT NOT NULL DEFAULT 'Anyone',
  pets TEXT NOT NULL DEFAULT 'No',
  availableFrom TEXT NOT NULL DEFAULT '',
  contactPhone TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'AVAILABLE',
  views INTEGER NOT NULL DEFAULT 0,
  boostedUntil INTEGER,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_listings_owner ON listings(ownerId);
CREATE INDEX IF NOT EXISTS idx_listings_created ON listings(createdAt);
CREATE INDEX IF NOT EXISTS idx_listings_town ON listings(town, status);
CREATE TABLE IF NOT EXISTS photos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  listingId INTEGER NOT NULL,
  url TEXT NOT NULL,
  thumb TEXT NOT NULL DEFAULT '',
  idx INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_photos_listing ON photos(listingId);
CREATE TABLE IF NOT EXISTS conversations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  listingId INTEGER NOT NULL,
  studentId INTEGER NOT NULL,
  landlordId INTEGER NOT NULL,
  lastMsg TEXT NOT NULL DEFAULT '',
  lastAt INTEGER NOT NULL DEFAULT 0,
  typingAt INTEGER,
  typingBy INTEGER,
  createdAt INTEGER NOT NULL,
  UNIQUE(listingId, studentId)
);
CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  convId INTEGER NOT NULL,
  senderId INTEGER NOT NULL,
  text TEXT NOT NULL,
  createdAt INTEGER NOT NULL,
  readAt INTEGER,
  edited INTEGER NOT NULL DEFAULT 0,
  deleted INTEGER NOT NULL DEFAULT 0,
  hiddenFor TEXT NOT NULL DEFAULT '[]'
);
CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(convId, id);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(convId, readAt);
CREATE INDEX IF NOT EXISTS idx_conv_student ON conversations(studentId, lastAt);
CREATE INDEX IF NOT EXISTS idx_conv_landlord ON conversations(landlordId, lastAt);
CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status, createdAt);
CREATE TABLE IF NOT EXISTS favorites (
  user_id INTEGER NOT NULL,
  listing_id INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, listing_id)
);
CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  listingId INTEGER NOT NULL,
  reporterId INTEGER,
  reason TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'OPEN',
  createdAt INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS boosts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  listingId INTEGER NOT NULL,
  userId INTEGER NOT NULL,
  town TEXT NOT NULL DEFAULT '',
  mpesaCode TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'PENDING',
  until INTEGER,
  createdAt INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL DEFAULT ''
);
INSERT OR IGNORE INTO settings (key, value) VALUES ('paybill_number','0143374333');
INSERT OR IGNORE INTO settings (key, value) VALUES ('paybill_name','Isaac Bridget');
INSERT OR IGNORE INTO settings (key, value) VALUES ('gmaps_key','');
`;

let schemaReady = null;
const SCHEMA_VER = '2';

async function ensureSchema(env) {
  if (!schemaReady) {
    schemaReady = (async () => {
      let ver = 0;
      try {
        const r = await env.DB.prepare("SELECT value FROM settings WHERE key = 'schema_ver'").first();
        if (r) ver = Number(r.value) || 0;
      } catch (e) { /* settings table missing — fresh install */ }
      if (ver < 1) {
        const stmts = SCHEMA.split('\n').filter(l => !l.trim().startsWith('--')).join('\n')
          .split(';').map(s => s.trim()).filter(Boolean);
        for (const st of stmts) await env.DB.prepare(st).run();
      }
      if (ver < 2) {
        // v2 — nationwide fields replace the old hostel-style ones (gender/curfew/visitors/alcohol/desk).
        // Fresh installs already have these columns from SCHEMA above, so the ALTERs no-op via catch.
        for (const [c, d] of [['tenantPref', 'Anyone'], ['pets', 'No'], ['hotShower', 'No']]) {
          try { await env.DB.prepare(`ALTER TABLE listings ADD COLUMN ${c} TEXT NOT NULL DEFAULT '${d}'`).run(); } catch (e) { /* column already exists */ }
        }
      }
      await env.DB.prepare("INSERT OR REPLACE INTO settings (key, value) VALUES ('schema_ver','" + SCHEMA_VER + "')").run();
    })().catch(e => { schemaReady = null; throw e; });
  }
  await schemaReady;
}

// ---------- listing field mapping (camelCase = D1 columns) ----------
const LSTR = ['title', 'ptype', 'furnishing', 'floor', 'town', 'area', 'landmark', 'road', 'period', 'terms',
  'water', 'waterCost', 'waterSched', 'elec', 'elecCost', 'wifiCost', 'wifiProvider', 'garbage', 'backup',
  'bath', 'kitchen', 'cooking', 'tenantPref', 'availableFrom', 'contactPhone'];
const LYNN = ['waterTank', 'negotiable', 'balcony', 'tile', 'ceiling', 'wardrobe', 'bed', 'hotShower', 'pets'];
const LNUM = ['units', 'rent', 'deposit'];

function listingCols(b, base) {
  // length caps: without them an authenticated landlord could store megabyte strings in
  // title/terms/etc and blow the D1 storage quota (or break card layouts) with one request
  const LCAPS = { title: 90, landmark: 120, terms: 1200, fees: 200, contactPhone: 20, availableFrom: 40, period: 40, waterSched: 80, wifiProvider: 40 };
  const out = {};
  for (const k of LSTR) if (b[k] !== undefined) out[k] = S(b[k]).slice(0, LCAPS[k] || 60);
  for (const k of LYNN) if (b[k] !== undefined) out[k] = S(b[k]).slice(0, 12); // Yes/No-style fields
  for (const k of LNUM) if (b[k] !== undefined) out[k] = Math.min(k === 'units' ? 1000 : 10000000, Math.max(0, N(b[k])));
  if (b.wifi !== undefined) out.wifi = S(b.wifi);
  if (b.lat !== undefined) out.lat = b.lat === '' || b.lat === null ? null : N(b.lat);
  if (b.lng !== undefined) out.lng = b.lng === '' || b.lng === null ? null : N(b.lng);
  if (b.security !== undefined) {
    out.security = JSON.stringify(Array.isArray(b.security) ? b.security.map(S).filter(Boolean) : []);
  }
  if (out.title !== undefined && out.title.length < 4) return { error: 'Title must be at least 4 characters' };
  if (out.rent !== undefined && out.rent < 1) return { error: 'Rent is required' };
  if (out.town !== undefined && !out.town) return { error: 'Choose the town' };
  void base;
  return { v: out };
}

async function attachThumbs(env, rows, keyField = 'id', outField = 'thumb') {
  if (!rows.length) return rows;
  const ids = [...new Set(rows.map(r => r[keyField]))];
  const qs = ids.map(() => '?').join(',');
  const res = await env.DB.prepare(
    `SELECT p.listingId, COALESCE(NULLIF(p.thumb, ''), p.url) AS url FROM photos p
     JOIN (SELECT listingId, MIN(idx) AS mIdx FROM photos WHERE listingId IN (${qs}) GROUP BY listingId) t
     ON p.listingId = t.listingId AND p.idx = t.mIdx`).bind(...ids).all();
  const m = {};
  (res.results || []).forEach(p => { m[p.listingId] = p.url; });
  rows.forEach(r => { r[outField] = m[r[keyField]] || ''; });
  return rows;
}

const CARD_COLS = `l.id, l.title, l.ptype, l.units, l.rent, l.period, l.town, l.area, l.landmark, l.lat, l.lng,
  l.furnishing, l.water, l.elec, l.wifi, l.bath, l.kitchen, l.backup, l.garbage, l.tenantPref, l.availableFrom,
  l.status, l.views, l.boostedUntil, l.createdAt, o.verify_status AS ownerVerified`;

function like(v) { return '%' + S(v).replace(/[%_]/g, ' ') + '%'; }

async function queryListings(env, url, opts = {}) {
  const w = ["l.status != 'REMOVED'", 'o.suspended = 0'];
  const p = [];
  const add = (cond, ...vals) => { w.push(cond); p.push(...vals); };
  const q = url.searchParams;

  if (opts.mine && opts.user) { w.length = 0; w.push('l.ownerId = ?'); p.push(opts.user.id); }
  const s = S(q.get('q'));
  if (s) add('(l.title LIKE ? OR l.town LIKE ? OR l.area LIKE ? OR l.landmark LIKE ?)', like(s), like(s), like(s), like(s));
  if (q.get('town')) add('l.town = ?', S(q.get('town')));
  if (q.get('area')) add('l.area LIKE ?', like(q.get('area')));
  if (q.get('ptype')) add('l.ptype = ?', S(q.get('ptype')));
  if (q.get('furnishing')) add('l.furnishing = ?', S(q.get('furnishing')));
  const min = N(q.get('min')), max = N(q.get('max'));
  if (min > 0) add('l.rent >= ?', min);
  if (max > 0) add('l.rent <= ?', max);
  if (opts.mine && S(q.get('status'))) add('l.status = ?', S(q.get('status')));
  for (const a of S(q.get('amenities')).split(',')) {
    if (a === 'water') add("l.water = 'Included in rent'");
    else if (a === 'elec') add("l.elec = 'Included in rent'");
    else if (a === 'wifi') add("l.wifi = 'Included in rent'");
    else if (a === 'ensuite') add("l.bath = 'Ensuite (own)'");
    else if (a === 'kitchen') add("l.kitchen = 'Own'");
    else if (a === 'guard') add("l.security LIKE '%Guard%'");
    else if (a === 'backup') add("l.backup != 'None'");
  }
  if (opts.exclude) add('l.id != ?', opts.exclude);
  if (opts.similarTo) {
    const base = await env.DB.prepare('SELECT town, ptype FROM listings WHERE id = ?').bind(opts.similarTo).first();
    if (base) add('(l.town = ? OR l.ptype = ?)', base.town, base.ptype);
  }

  // TOWN-TARGETED BOOSTS — the HomeLinkKE ranking rule:
  //   · a boost only jumps to the top for people browsing the boosted listing's OWN town
  //     (the client passes bt = the town the renter is currently browsing)
  //   · elsewhere the same boosted listing ranks as a normal, non-boosted row —
  //     so a Nanyuki boost never pushes a fresh Nairobi listing off a Nairobi renter's feed.
  const sort = S(q.get('sort')) || 'new';
  const bt = S(q.get('bt'));
  const boostCase = bt
    ? `CASE WHEN l.boostedUntil IS NOT NULL AND l.boostedUntil > ? AND l.town = ? THEN 0 ELSE 1 END`
    : `CASE WHEN l.boostedUntil IS NOT NULL AND l.boostedUntil > ? THEN 1 ELSE 1 END`;
  const ob = [Date.now()];
  if (bt) ob.push(bt);
  let order;
  if (sort === 'priceAsc') { order = `${boostCase}, l.rent ASC`; }
  else if (sort === 'priceDesc') { order = `${boostCase}, l.rent DESC`; }
  else { order = `${boostCase}, l.createdAt DESC`; }

  const lim = Math.min(100, Math.max(1, N(q.get('limit')) || 60));
  const sql = `SELECT ${CARD_COLS} FROM listings l JOIN users o ON o.id = l.ownerId
    WHERE ${w.join(' AND ')} ORDER BY ${order} LIMIT ?`;
  const rows = (await env.DB.prepare(sql).bind(...p, ...ob, lim).all()).results || [];
  await attachThumbs(env, rows);
  return rows;
}

// ---------- main entry ----------
export async function onRequest(context) {
  const { request, env } = context;
  const url = new URL(request.url);
  const seg = url.pathname.replace(/^\/api\/?/, '').split('/').filter(Boolean);
  const method = request.method;
  const json_ = () => request.json().catch(() => ({}));

  try {
    // request body cap: the heaviest legit request is 8 photos + 8 thumbs ≈ 11 MB.
    // Without this cap an attacker could stream arbitrarily large bodies at the API.
    const cl = +(request.headers.get('content-length') || 0);
    if (cl > 16_000_000) return bad('Request too large', 413);
    if (!env.DB) return bad('Database not connected. Add the D1 binding named "DB" in Cloudflare Pages settings.', 500);
    await ensureSchema(env);
    const user = await getSession(request, env);
    const need = (roles) => {
      if (!user) throw Object.assign(new Error('Please sign in first'), { status: 401 });
      if (user.suspended) throw Object.assign(new Error('This account has been suspended. Contact support.'), { status: 403 });
      if (roles && !roles.includes(user.role)) throw Object.assign(new Error('You are not allowed to do that'), { status: 403 });
      return user;
    };
    const p0 = seg[0] || '';

    // ============ SETUP (first admin) ============
    if (p0 === 'setup') {
      if (method === 'POST' && !rateLimit('setup:' + ipOf(request), 5, 3600_000)) return tooMany();
      const admins = await env.DB.prepare("SELECT COUNT(*) AS n FROM users WHERE role = 'ADMIN'").first();
      if (method === 'GET') return ok({ available: !admins.n });
      if (admins.n) return bad('Setup is closed — an admin already exists.', 403);
      // race-proof lock: only one concurrent setup can insert this unique row
      try {
        await env.DB.prepare("INSERT INTO settings (key, value) VALUES ('admin_locked', '1')").run();
      } catch (e) {
        return bad('Setup is closed — an admin already exists.', 403);
      }
      const releaseLock = () => env.DB.prepare("DELETE FROM settings WHERE key = 'admin_locked'").run();
      const b = await json_();
      const username = S(b.username).toLowerCase();
      if (!/^[a-z0-9_]{3,20}$/.test(username)) { await releaseLock(); return bad('Username must be 3–20 letters, numbers or underscore'); }
      if (S(b.password).length < 6) { await releaseLock(); return bad('Password must be at least 6 characters'); }
      if (b.password !== b.confirm) { await releaseLock(); return bad('Passwords do not match'); }
      if (!S(b.hint)) { await releaseLock(); return bad('Password hint is required'); }
      const dup = await env.DB.prepare('SELECT id FROM users WHERE username = ?').bind(username).first();
      if (dup) { await releaseLock(); return bad('That username is taken'); }
      const salt = rand(16);
      const hash = await hashPw(S(b.password), salt);
      const r = await env.DB.prepare(
        "INSERT INTO users (username, pass_hash, pass_hint, name, role, phone, created_at) VALUES (?,?,?,?,?,?,?)")
        .bind(username, salt + '$' + hash, S(b.hint).slice(0, 120), (S(b.name) || 'Admin').slice(0, 60), 'ADMIN', S(b.phone), Date.now()).run();
      const token = await newSession(env, r.meta.last_row_id);
      const u = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(r.meta.last_row_id).first();
      return ok({ token, user: pubUser(u) });
    }

    // ============ AUTH ============
    if (p0 === 'register' && method === 'POST') {
      if (!rateLimit('reg:' + ipOf(request), 8, 3600_000)) return tooMany();
      const b = await json_();
      const username = S(b.username).toLowerCase();
      const password = S(b.password);
      const role = b.role === 'LANDLORD' ? 'LANDLORD' : 'SEEKER';
      if (!/^[a-z0-9_]{3,20}$/.test(username)) return bad('Username must be 3–20 letters, numbers or underscore');
      if (password.length < 6) return bad('Password must be at least 6 characters');
      if (password !== S(b.confirm)) return bad('Passwords do not match');
      if (!S(b.hint)) return bad('Password hint is required (it helps you recover your account)');
      if (S(b.hint).toLowerCase() === password.toLowerCase()) return bad('Hint must be different from the password');
      if (!S(b.name)) return bad('Your name is required');
      // Kenyan phone formats accepted: 07xx/01xx, +2547xx/2547xx, spaces & dashes stripped.
      // Normalised to 2547… form so WhatsApp links always work.
      let phone = S(b.phone).replace(/[\s-]/g, '');
      let m0 = phone.match(/^0([17]\d{8})$/); if (m0) phone = '254' + m0[1];
      m0 = phone.match(/^\+254([17]\d{8})$/); if (m0) phone = '254' + m0[1];
      if (!/^254[17]\d{8}$/.test(phone)) return bad('Enter a valid Kenyan phone / WhatsApp number, e.g. 0712 345 678');
      const dup = await env.DB.prepare('SELECT id FROM users WHERE username = ?').bind(username).first();
      if (dup) return bad('That username is taken');
      const salt = rand(16);
      const hash = await hashPw(password, salt);
      // caps stop storage abuse (a 5 MB hint/name used to be stored verbatim);
      // try/catch turns the UNIQUE race (double-submit) into a friendly 400 instead of a 500
      try {
        const r = await env.DB.prepare(
          'INSERT INTO users (username, pass_hash, pass_hint, name, role, phone, created_at) VALUES (?,?,?,?,?,?,?)')
          .bind(username, salt + '$' + hash, S(b.hint).slice(0, 120), S(b.name).slice(0, 60), role, phone, Date.now()).run();
        const token = await newSession(env, r.meta.last_row_id);
        const u = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(r.meta.last_row_id).first();
        return ok({ token, user: pubUser(u) });
      } catch (e) {
        if (String(e.message || '').includes('UNIQUE')) return bad('That username is taken');
        throw e;
      }
    }

    if (p0 === 'login' && method === 'POST') {
      const ip = ipOf(request);
      if (!rateLimit('login:' + ip, 15, 60_000)) return tooMany();
      const b = await json_();
      const uname = S(b.username).toLowerCase();
      if (uname && !rateLimit('loginu:' + uname, 8, 60_000)) return tooMany();
      const u = await env.DB.prepare('SELECT * FROM users WHERE username = ?').bind(uname).first();
      if (!u) return bad('Wrong username or password', 401);
      const [salt, hash] = String(u.pass_hash).split('$');
      const test = await hashPw(S(b.password), salt);
      if (!safeEq(test, hash)) return bad('Wrong username or password', 401);
      if (u.suspended) return bad('This account has been suspended. Contact support.', 403);
      if (Math.random() < 0.1) await env.DB.prepare('DELETE FROM sessions WHERE expires_at < ?').bind(Date.now()).run();
      const token = await newSession(env, u.id);
      return ok({ token, user: pubUser(u) });
    }

    if (p0 === 'logout' && method === 'POST') {
      const h = request.headers.get('Authorization') || '';
      if (h.startsWith('Bearer ')) {
        await env.DB.prepare('DELETE FROM sessions WHERE token = ?').bind(h.slice(7).trim()).run();
      }
      return ok();
    }

    if (p0 === 'hint' && method === 'GET' && seg[1]) {
      if (!rateLimit('hint:' + ipOf(request), 10, 60_000)) return tooMany();
      const u = await env.DB.prepare('SELECT pass_hint FROM users WHERE username = ?').bind(S(seg[1]).toLowerCase()).first();
      return ok({ hint: u ? u.pass_hint : '' });
    }

    if (p0 === 'me' && method === 'GET') {
      // the session itself must be valid and the account in good standing —
      // a forged/expired token or a suspended account must never see profile data
      if (!user) throw Object.assign(new Error('Please sign in first'), { status: 401 });
      if (user.suspended) throw Object.assign(new Error('This account has been suspended. Contact support.'), { status: 403 });
      return ok({ user: pubUser(user) });
    }

    if (p0 === 'me' && method === 'PUT') {
      const u = need();
      const b = await json_();
      const name = b.name !== undefined ? S(b.name) : u.name;
      let phone = b.phone !== undefined ? S(b.phone).replace(/[\s-]/g, '') : u.phone;
      let m0 = phone.match(/^0([17]\d{8})$/); if (m0) phone = '254' + m0[1];
      m0 = phone.match(/^\+254([17]\d{8})$/); if (m0) phone = '254' + m0[1];
      if (phone && !/^254[17]\d{8}$/.test(phone)) return bad('Enter a valid Kenyan phone / WhatsApp number');
      if (!name) return bad('Name is required');
      await env.DB.prepare('UPDATE users SET name = ?, phone = ? WHERE id = ?')
        .bind(name.slice(0, 60), phone, u.id).run();
      const nu = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(u.id).first();
      return ok({ user: pubUser(nu) });
    }

    // ============ LANDLORD VERIFICATION ============
    if (p0 === 'verify' && method === 'POST') {
      const u = need(['LANDLORD']);
      if (!rateLimit('verify:' + u.id, 5, 3600_000)) return tooMany();
      const b = await json_();
      if (!isImg(b.docId) || !isImg(b.docOwn)) return bad('Upload both your ID photo and your ownership document photo');
      await env.DB.prepare("UPDATE users SET doc_id = ?, doc_own = ?, verify_status = 'PENDING', verify_note = '' WHERE id = ?")
        .bind(b.docId, b.docOwn, u.id).run();
      return ok({ verifyStatus: 'PENDING' });
    }

    // ============ SETTINGS ============
    if (p0 === 'settings' && method === 'GET') {
      // public read is limited to the payment details shown on the boost page.
      // Everything else (admin_locked, schema_ver, any legacy key) is server-private —
      // the old endpoint leaked every row to anonymous visitors.
      const rows = (await env.DB.prepare("SELECT key, value FROM settings WHERE key IN ('paybill_number','paybill_name')").all()).results || [];
      const st = {};
      rows.forEach(r => { st[r.key] = r.value; });
      return ok({ settings: st });
    }
    if (p0 === 'settings' && method === 'PUT') {
      const u = need(['ADMIN']);
      const b = await json_();
      // gmaps_key removed: maps run keyless on OSM/Esri, and an unused key column that
      // anonymous users could once read is a leak waiting to happen
      const allowed = ['paybill_number', 'paybill_name'];
      for (const k of allowed) if (b[k] !== undefined) {
        await env.DB.prepare('INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value')
          .bind(k, S(b[k])).run();
      }
      return ok();
    }

    // ============ LISTINGS ============
    if (p0 === 'listings') {
      // detail
      if (seg[1] && !seg[2] && method === 'GET') {
        if (!rateLimit('read:' + ipOf(request), 240, 60_000)) return tooMany();
        const id = N(seg[1]);
        const l = await env.DB.prepare(
          `SELECT l.*, o.name AS ownerName, o.username AS ownerUsername, o.phone AS ownerPhone,
                  o.verify_status AS ownerVerify, o.created_at AS ownerSince
           FROM listings l JOIN users o ON o.id = l.ownerId WHERE l.id = ?`).bind(id).first();
        if (!l) return bad('Listing not found', 404);
        const isOwner = user && (user.id === l.ownerId || user.role === 'ADMIN');
        if (l.status === 'REMOVED' && !isOwner) return bad('Listing not found', 404);
        const photos = (await env.DB.prepare('SELECT id, url, thumb FROM photos WHERE listingId = ? ORDER BY idx').bind(id).all()).results || [];
        const similar = await queryListings(env, new URL('http://x/?limit=4'), { similarTo: id, exclude: id });
        const pub = { ...l };
        if (!user) { pub.ownerPhone = ''; pub.contactPhone = ''; } // contact details require sign-in (privacy promise made in the wizard)
        return ok({ listing: pub, photos, similar, isOwner: !!isOwner });
      }
      // create
      if (!seg[1] && method === 'POST') {
        const u = need(['LANDLORD']);
        const b = await json_();
        const { v, error } = listingCols(b);
        if (error) return bad(error);
        if (!v.rent || v.rent < 1) return bad('Rent is required');
        if (!v.title || v.title.length < 4) return bad('Title must be at least 4 characters');
        if (!v.town) return bad('Choose the town');
        const photos = Array.isArray(b.photos) ? b.photos.filter(x => isImg(x)) : [];
        if (photos.length < 3) return bad('Add at least 3 photos');
        if (photos.length > 8) return bad('Maximum 8 photos');
        const thumbsIn = Array.isArray(b.thumbs) ? b.thumbs : [];
        const cnt = (await env.DB.prepare("SELECT COUNT(*) AS n FROM listings WHERE ownerId = ? AND status != 'REMOVED'").bind(u.id).first()).n;
        const limit = u.verify_status === 'APPROVED' ? 5 : 2;
        if (cnt >= limit) return bad(u.verify_status === 'APPROVED'
          ? 'You have reached the 5-listing limit. Contact support to add more.'
          : 'Free plan: 2 listings. Get verified in your Profile to post up to 5.');
        const now = Date.now();
        const keys = Object.keys(v);
        const r = await env.DB.prepare(
          `INSERT INTO listings (ownerId, ${keys.join(', ')}, createdAt, updatedAt) VALUES (${Array(keys.length + 3).fill('?').join(', ')})`)
          .bind(u.id, ...keys.map(k => v[k]), now, now).run();
        const lid = r.meta.last_row_id;
        await env.DB.batch(photos.map((url, i) =>
          env.DB.prepare('INSERT INTO photos (listingId, url, thumb, idx) VALUES (?, ?, ?, ?)')
            .bind(lid, url, isImg(thumbsIn[i], 200000) ? thumbsIn[i] : '', i)));
        return ok({ id: lid });
      }
      // update
      if (seg[1] && !seg[2] && method === 'PUT') {
        const u = need(['LANDLORD']);
        const id = N(seg[1]);
        const own = await env.DB.prepare('SELECT * FROM listings WHERE id = ?').bind(id).first();
        if (!own || own.ownerId !== u.id) return bad('Listing not found', 404);
        const b = await json_();
        const { v, error } = listingCols(b, own);
        if (error) return bad(error);
        const keys = Object.keys(v);
        if (keys.length) {
          await env.DB.prepare(`UPDATE listings SET ${keys.map(k => k + ' = ?').join(', ')}, updatedAt = ? WHERE id = ?`)
            .bind(...keys.map(k => v[k]), Date.now(), id).run();
        }
        if (Array.isArray(b.photos)) {
          const photos = b.photos.filter(x => isImg(x));
          if (photos.length < 3) return bad('Keep at least 3 photos');
          if (photos.length > 8) return bad('Maximum 8 photos');
          const thumbsIn = Array.isArray(b.thumbs) ? b.thumbs : [];
          await env.DB.prepare('DELETE FROM photos WHERE listingId = ?').bind(id).run();
          await env.DB.batch(photos.map((url, i) =>
            env.DB.prepare('INSERT INTO photos (listingId, url, thumb, idx) VALUES (?, ?, ?, ?)')
              .bind(id, url, isImg(thumbsIn[i], 200000) ? thumbsIn[i] : '', i)));
        }
        return ok({ id });
      }
      // delete (soft)
      if (seg[1] && !seg[2] && method === 'DELETE') {
        const u = need(['LANDLORD', 'ADMIN']);
        const id = N(seg[1]);
        const own = await env.DB.prepare('SELECT * FROM listings WHERE id = ?').bind(id).first();
        if (!own) return bad('Listing not found', 404);
        if (user.role !== 'ADMIN' && own.ownerId !== u.id) return bad('Not your listing', 403);
        await env.DB.prepare("UPDATE listings SET status = 'REMOVED', updatedAt = ? WHERE id = ?").bind(Date.now(), id).run();
        return ok();
      }
      // status toggle
      if (seg[1] && seg[2] === 'status' && method === 'POST') {
        const u = need(['LANDLORD']);
        const id = N(seg[1]);
        const own = await env.DB.prepare('SELECT * FROM listings WHERE id = ?').bind(id).first();
        if (!own || own.ownerId !== u.id) return bad('Listing not found', 404);
        const b = await json_();
        const st = b.status === 'TAKEN' ? 'TAKEN' : 'AVAILABLE';
        await env.DB.prepare('UPDATE listings SET status = ?, updatedAt = ? WHERE id = ?').bind(st, Date.now(), id).run();
        return ok({ status: st });
      }
      // view counter (deduped per visitor per listing for 6 hours)
      if (seg[1] && seg[2] === 'view' && method === 'POST') {
        const id = N(seg[1]);
        if (rateLimit('view:' + ipOf(request) + ':' + id, 1, 6 * 3600_000)) {
          await env.DB.prepare('UPDATE listings SET views = views + 1 WHERE id = ?').bind(id).run();
        }
        return ok();
      }
      // report
      if (seg[1] && seg[2] === 'report' && method === 'POST') {
        const u = need();
        const b = await json_();
        if (!S(b.reason)) return bad('Choose a reason');
        if (!rateLimit('report:' + u.id, 5, 3600_000)) return tooMany();
        await env.DB.prepare('INSERT INTO reports (listingId, reporterId, reason, note, createdAt) VALUES (?,?,?,?,?)')
          .bind(N(seg[1]), u.id, S(b.reason), S(b.note).slice(0, 500), Date.now()).run();
        return ok();
      }
      // boost request
      if (seg[1] && seg[2] === 'boost' && method === 'POST') {
        const u = need(['LANDLORD']);
        const id = N(seg[1]);
        const own = await env.DB.prepare('SELECT * FROM listings WHERE id = ?').bind(id).first();
        if (!own || own.ownerId !== u.id) return bad('Listing not found', 404);
        if (own.boostedUntil && own.boostedUntil > Date.now()) return bad('This listing is already boosted');
        const pend = await env.DB.prepare("SELECT id FROM boosts WHERE listingId = ? AND status = 'PENDING'").bind(id).first();
        if (pend) return bad('You already have a boost awaiting confirmation');
        if (!rateLimit('boost:' + u.id, 5, 3600_000)) return tooMany();
        const b = await json_();
        await env.DB.prepare('INSERT INTO boosts (listingId, userId, town, mpesaCode, createdAt) VALUES (?,?,?,?,?)')
          .bind(id, u.id, S(own.town), S(b.mpesaCode).slice(0, 40), Date.now()).run();
        return ok();
      }
      // browse/search
      if (!seg[1] && method === 'GET') {
        if (!rateLimit('read:' + ipOf(request), 240, 60_000)) return tooMany();
        const rows = await queryListings(env, url, {});
        return ok({ items: rows });
      }
    }

    // ============ MY (landlord) ============
    if (p0 === 'my') {
      const u = need();
      if (seg[1] === 'listings' && method === 'GET') {
        const url2 = new URL('http://x/?mine=1&limit=100');
        const rows = await queryListings(env, url2, { mine: true, user: u });
        return ok({ items: rows });
      }
      if (seg[1] === 'favorites' && method === 'GET') {
        const rows = (await env.DB.prepare(
          `SELECT ${CARD_COLS}
           FROM favorites f JOIN listings l ON l.id = f.listing_id JOIN users o ON o.id = l.ownerId
           WHERE f.user_id = ? AND l.status != 'REMOVED' ORDER BY f.created_at DESC`).bind(u.id).all()).results || [];
        await attachThumbs(env, rows);
        return ok({ items: rows });
      }
      if (seg[1] === 'boosts' && method === 'GET') {
        const rows = (await env.DB.prepare(
          `SELECT b.*, l.title FROM boosts b JOIN listings l ON l.id = b.listingId
           WHERE b.userId = ? ORDER BY b.createdAt DESC LIMIT 20`).bind(u.id).all()).results || [];
        return ok({ items: rows });
      }
    }

    // ============ FAVORITES ============
    if (p0 === 'favorites' && seg[1] && method === 'POST') {
      const u = need();
      const lid = N(seg[1]);
      const lex = await env.DB.prepare("SELECT id FROM listings WHERE id = ? AND status != 'REMOVED'").bind(lid).first();
      if (!lex) return bad('Listing not found', 404);
      const ex = await env.DB.prepare('SELECT user_id FROM favorites WHERE user_id = ? AND listing_id = ?').bind(u.id, lid).first();
      if (ex) {
        await env.DB.prepare('DELETE FROM favorites WHERE user_id = ? AND listing_id = ?').bind(u.id, lid).run();
        return ok({ on: false });
      }
      await env.DB.prepare('INSERT OR IGNORE INTO favorites (user_id, listing_id, created_at) VALUES (?,?,?)').bind(u.id, lid, Date.now()).run();
      return ok({ on: true });
    }

    // ============ CHAT ============
    if (p0 === 'convs') {
      const u = need();
      // open or create
      if (!seg[1] && method === 'POST') {
        if (!rateLimit('conv:' + u.id, 10, 60_000)) return tooMany();
        const b = await json_();
        const lid = N(b.listingId);
        const l = await env.DB.prepare('SELECT * FROM listings WHERE id = ?').bind(lid).first();
        if (!l || l.status === 'REMOVED') return bad('Listing not found', 404);
        if (l.ownerId === u.id) return bad('This is your own listing');
        const ex = await env.DB.prepare('SELECT id FROM conversations WHERE listingId = ? AND studentId = ?').bind(lid, u.id).first();
        if (ex) return ok({ id: ex.id });
        const r = await env.DB.prepare(
          'INSERT INTO conversations (listingId, studentId, landlordId, createdAt) VALUES (?,?,?,?)')
          .bind(lid, u.id, l.ownerId, Date.now()).run();
        return ok({ id: r.meta.last_row_id });
      }
      // list
      if (!seg[1] && method === 'GET') {
        const rows = (await env.DB.prepare(
          `SELECT c.id, c.listingId, c.studentId, c.landlordId, c.lastMsg, c.lastAt,
                  st.name AS stName, lo.name AS loName, st.phone AS stPhone, lo.phone AS loPhone,
                  l.title AS ltitle, l.rent AS lrent, l.ptype AS lptype, l.status AS lstatus,
                  (SELECT COUNT(*) FROM messages m WHERE m.convId = c.id AND m.senderId != ? AND m.readAt IS NULL) AS unread
           FROM conversations c
           JOIN listings l ON l.id = c.listingId
           JOIN users st ON st.id = c.studentId
           JOIN users lo ON lo.id = c.landlordId
           WHERE c.studentId = ? OR c.landlordId = ?
           ORDER BY c.lastAt DESC LIMIT 100`).bind(u.id, u.id, u.id).all()).results || [];
        await attachThumbs(env, rows, 'listingId', 'thumb');
        rows.forEach(r => {
          r.otherName = r.studentId === u.id ? r.loName : r.stName;
          r.otherPhone = r.studentId === u.id ? r.loPhone : r.stPhone;
          r.amLandlord = r.landlordId === u.id;
          delete r.stName; delete r.loName; delete r.stPhone; delete r.loPhone;
        });
        return ok({ items: rows });
      }
      // thread info
      if (seg[1] && !seg[2] && method === 'GET') {
        const c = await env.DB.prepare('SELECT * FROM conversations WHERE id = ?').bind(N(seg[1])).first();
        if (!c || (c.studentId !== u.id && c.landlordId !== u.id && u.role !== 'ADMIN')) return bad('Conversation not found', 404);
        const l = await env.DB.prepare('SELECT id, title, rent, period, ptype, status, contactPhone FROM listings WHERE id = ?').bind(c.listingId).first();
        const other = await env.DB.prepare('SELECT id, name, username, phone, role, verify_status FROM users WHERE id = ?')
          .bind(c.studentId === u.id ? c.landlordId : c.studentId).first();
        // only the two parties mark messages read — an admin previewing a thread for
        // moderation must not corrupt the real recipient's read receipts
        if (c.studentId === u.id || c.landlordId === u.id) {
          await env.DB.prepare('UPDATE messages SET readAt = ? WHERE convId = ? AND senderId != ? AND readAt IS NULL')
            .bind(Date.now(), c.id, u.id).run();
        }
        const otherTyping = !!(c.typingBy && c.typingBy !== u.id && c.typingAt && Date.now() - c.typingAt < 6000);
        // slim projection: the old pubUser() leaked verifyNote (the admin's PRIVATE
        // verification comments, e.g. why docs were rejected) to the chat counterpart
        const otherPub = other ? {
          id: other.id, name: other.name, username: other.username, phone: other.phone,
          role: other.role, verifyStatus: other.verify_status
        } : null;
        return ok({
          conv: { id: c.id, listingId: c.listingId },
          listing: l, other: otherPub, otherTyping
        });
      }
      // messages
      if (seg[1] && seg[2] === 'messages') {
        const cid = N(seg[1]);
        const c = await env.DB.prepare('SELECT * FROM conversations WHERE id = ?').bind(cid).first();
        if (!c || (c.studentId !== u.id && c.landlordId !== u.id && u.role !== 'ADMIN')) return bad('Conversation not found', 404);
        if (method === 'GET') {
          const after = N(new URL(request.url).searchParams.get('after'));
          const hidCond = "(hiddenFor IS NULL OR hiddenFor = '' OR hiddenFor = '[]' OR hiddenFor NOT LIKE ?)";
          const rows = (await env.DB.prepare(
            `SELECT * FROM (SELECT * FROM messages WHERE convId = ? AND id > ? AND ${hidCond} ORDER BY id DESC LIMIT 300) ORDER BY id ASC`)
            .bind(cid, after, '%"' + u.id + '"%').all()).results || [];
          rows.forEach(m => {
            if (m.deleted) m.text = '';           // tombstone — never leak deleted text
            delete m.hiddenFor;
          });
          // mark read ONLY when something new arrived AND the viewer is one of the two
          // parties (an admin previewing must not mark the student's chat as read);
          // running this UPDATE on every 3s poll with zero new rows also burned D1 writes
          if (rows.length && (c.studentId === u.id || c.landlordId === u.id)) {
            await env.DB.prepare('UPDATE messages SET readAt = ? WHERE convId = ? AND senderId != ? AND readAt IS NULL')
              .bind(Date.now(), cid, u.id).run();
          }
          // sync tail: the newest messages with their edited/deleted/read state so an OPEN thread
          // sees the other side's edits, deletions and read receipts (poll ?after= can't carry these)
          const sync = (await env.DB.prepare(
            `SELECT * FROM (SELECT * FROM messages WHERE convId = ? AND ${hidCond} ORDER BY id DESC LIMIT 12) ORDER BY id ASC`)
            .bind(cid, '%"' + u.id + '"%').all()).results || [];
          sync.forEach(m => {
            if (m.deleted) m.text = '';
            delete m.hiddenFor;
          });
          const otherTyping = !!(c.typingBy && c.typingBy !== u.id && c.typingAt && Date.now() - c.typingAt < 6000);
          return ok({ items: rows, sync, me: u.id, otherTyping });
        }
        if (method === 'POST') {
          if (!rateLimit('msg:' + u.id, 30, 60_000)) return tooMany();
          const b = await json_();
          const text = S(b.text).slice(0, 2000);
          if (!text) return bad('Type a message');
          const r = await env.DB.prepare('INSERT INTO messages (convId, senderId, text, createdAt) VALUES (?,?,?,?)')
            .bind(cid, u.id, text, Date.now()).run();
          await env.DB.prepare('UPDATE conversations SET lastAt = ?, lastMsg = ?, typingAt = NULL, typingBy = NULL WHERE id = ?')
            .bind(Date.now(), text.slice(0, 80), cid).run();
          return ok({ id: r.meta.last_row_id });
        }
        // edit own message (WhatsApp: within a time window)
        if (seg[3] && method === 'PATCH') {
          const mid = N(seg[3]);
          const m = await env.DB.prepare('SELECT * FROM messages WHERE id = ? AND convId = ?').bind(mid, cid).first();
          if (!m || m.deleted || m.senderId !== u.id) return bad('Message not found', 404);
          if (Date.now() - m.createdAt > 15 * 60_000) return bad('Messages can only be edited within 15 minutes');
          if (!rateLimit('msg:' + u.id, 30, 60_000)) return tooMany();
          const b = await json_();
          const text = S(b.text).slice(0, 2000);
          if (!text) return bad('Type a message');
          await env.DB.prepare('UPDATE messages SET text = ?, edited = 1 WHERE id = ?').bind(text, mid).run();
          const last = await env.DB.prepare('SELECT MAX(id) AS mid FROM messages WHERE convId = ?').bind(cid).first();
          if (last && last.mid === mid) {
            await env.DB.prepare('UPDATE conversations SET lastMsg = ? WHERE id = ?').bind(text.slice(0, 80), cid).run();
          }
          return ok({});
        }
        // delete for me (hide only for this viewer) / delete for everyone (sender only)
        if (seg[3] && method === 'DELETE') {
          const mid = N(seg[3]);
          const m = await env.DB.prepare('SELECT * FROM messages WHERE id = ? AND convId = ?').bind(mid, cid).first();
          if (!m || m.deleted) return bad('Message not found', 404);
          const scope = S(new URL(request.url).searchParams.get('scope')) === 'all' ? 'all' : 'me';
          if (scope === 'all') {
            if (m.senderId !== u.id) return bad('You can only delete your own messages for everyone', 403);
            await env.DB.prepare('UPDATE messages SET deleted = 1, text = ? WHERE id = ?').bind('', mid).run();
            const last = await env.DB.prepare('SELECT MAX(id) AS mid FROM messages WHERE convId = ?').bind(cid).first();
            if (last && last.mid === mid) {
              await env.DB.prepare('UPDATE conversations SET lastMsg = ? WHERE id = ?').bind('Message deleted', cid).run();
            }
          } else {
            let arr = [];
            try { arr = JSON.parse(m.hiddenFor || '[]'); } catch (e) { arr = []; }
            if (!Array.isArray(arr)) arr = [];
            if (!arr.includes(String(u.id))) {
              arr.push(String(u.id)); // string ids → LIKE-safe
              await env.DB.prepare('UPDATE messages SET hiddenFor = ? WHERE id = ?').bind(JSON.stringify(arr), mid).run();
            }
          }
          return ok({});
        }
      }
      // typing ping (throttled client-side; membership required)
      if (seg[1] && seg[2] === 'typing' && method === 'POST') {
        const cid = N(seg[1]);
        const c = await env.DB.prepare('SELECT * FROM conversations WHERE id = ?').bind(cid).first();
        if (!c || (c.studentId !== u.id && c.landlordId !== u.id)) return bad('Conversation not found', 404);
        if (!rateLimit('typ:' + u.id, 30, 60_000)) return tooMany();
        // skip the write when this user's typing flag is already fresh — saves thousands of
        // pointless D1 writes per day (typing pings are the #1 write amplifier in chat apps)
        if (!(c.typingBy === u.id && c.typingAt && Date.now() - c.typingAt < 4000)) {
          await env.DB.prepare('UPDATE conversations SET typingAt = ?, typingBy = ? WHERE id = ?')
            .bind(Date.now(), u.id, cid).run();
        }
        return ok({});
      }
    }

    if (p0 === 'unread' && method === 'GET') {
      if (!user) return ok({ n: 0 });
      const r = await env.DB.prepare(
        `SELECT COUNT(*) AS n FROM messages m
         JOIN conversations c ON c.id = m.convId
         WHERE (c.studentId = ? OR c.landlordId = ?) AND m.senderId != ? AND m.readAt IS NULL`)
        .bind(user.id, user.id, user.id).first();
      return ok({ n: r.n });
    }

    // ============ ADMIN ============
    if (p0 === 'admin') {
      const u = need(['ADMIN']);
      // tiny single-row counter the client badge poll hits — one indexed query,
      // drives the notification dots on the admin tabs / nav / profile
      if (seg[1] === 'counts' && method === 'GET') {
        const c = await env.DB.prepare(
          `SELECT (SELECT COUNT(*) FROM users WHERE verify_status = 'PENDING') AS verifications,
                  (SELECT COUNT(*) FROM boosts WHERE status = 'PENDING') AS boosts,
                  (SELECT COUNT(*) FROM reports WHERE status = 'OPEN') AS reports`
        ).first();
        return ok({ counts: c });
      }
      if (seg[1] === 'stats' && method === 'GET') {
        const one = async (sql, ...b) => (await env.DB.prepare(sql).bind(...b).first()).n;
        const stats = {
          users: await one('SELECT COUNT(*) AS n FROM users'),
          landlords: await one("SELECT COUNT(*) AS n FROM users WHERE role = 'LANDLORD'"),
          listings: await one("SELECT COUNT(*) AS n FROM listings WHERE status != 'REMOVED'"),
          available: await one("SELECT COUNT(*) AS n FROM listings WHERE status = 'AVAILABLE'"),
          verifications: await one("SELECT COUNT(*) AS n FROM users WHERE verify_status = 'PENDING'"),
          boosts: await one("SELECT COUNT(*) AS n FROM boosts WHERE status = 'PENDING'"),
          reports: await one("SELECT COUNT(*) AS n FROM reports WHERE status = 'OPEN'"),
          views: await one('SELECT COALESCE(SUM(views),0) AS n FROM listings')
        };
        return ok({ stats });
      }
      if (seg[1] === 'verifications' && method === 'GET') {
        const rows = (await env.DB.prepare(
          "SELECT id, username, name, phone, created_at, doc_id, doc_own FROM users WHERE verify_status = 'PENDING' ORDER BY created_at ASC")
          .all()).results || [];
        return ok({ items: rows });
      }
      if (seg[1] === 'verify' && seg[2] && method === 'POST') {
        const b = await json_();
        const st = b.decision === 'approve' ? 'APPROVED' : 'REJECTED';
        await env.DB.prepare('UPDATE users SET verify_status = ?, verify_note = ? WHERE id = ?')
          .bind(st, S(b.note), N(seg[2])).run();
        return ok({ verifyStatus: st });
      }
      if (seg[1] === 'boosts' && method === 'GET') {
        const rows = (await env.DB.prepare(
          `SELECT b.*, l.title AS ltitle, us.username AS uname FROM boosts b
           JOIN listings l ON l.id = b.listingId JOIN users us ON us.id = b.userId
           WHERE b.status = 'PENDING' ORDER BY b.createdAt ASC`).all()).results || [];
        return ok({ items: rows });
      }
      if (seg[1] === 'boosts' && seg[2] && method === 'POST') {
        const b = await json_();
        const req = await env.DB.prepare('SELECT * FROM boosts WHERE id = ?').bind(N(seg[2])).first();
        if (!req || req.status !== 'PENDING') return bad('Request not found', 404);
        if (b.decision === 'approve') {
          const until = Date.now() + 7 * DAY;
          await env.DB.batch([
            env.DB.prepare("UPDATE boosts SET status = 'ACTIVE', until = ? WHERE id = ?").bind(until, req.id),
            env.DB.prepare('UPDATE listings SET boostedUntil = ? WHERE id = ?').bind(until, req.listingId)
          ]);
        } else {
          await env.DB.prepare("UPDATE boosts SET status = 'DECLINED' WHERE id = ?").bind(req.id).run();
        }
        return ok();
      }
      if (seg[1] === 'reports' && method === 'GET') {
        const rows = (await env.DB.prepare(
          `SELECT r.*, l.title AS ltitle, l.status AS lstatus, us.username AS uname FROM reports r
           JOIN listings l ON l.id = r.listingId LEFT JOIN users us ON us.id = r.reporterId
           WHERE r.status = 'OPEN' ORDER BY r.createdAt ASC`).all()).results || [];
        return ok({ items: rows });
      }
      if (seg[1] === 'reports' && seg[2] && method === 'POST') {
        const b = await json_();
        const rep = await env.DB.prepare('SELECT * FROM reports WHERE id = ?').bind(N(seg[2])).first();
        if (!rep) return bad('Report not found', 404);
        if (b.action === 'delete') {
          // hard delete the reported listing entirely — same wipe as the Listings
          // tab, and the reports die with the listing so nothing dangles open
          const lid = rep.listingId;
          await env.DB.batch([
            env.DB.prepare('DELETE FROM messages WHERE convId IN (SELECT id FROM conversations WHERE listingId = ?)').bind(lid),
            env.DB.prepare('DELETE FROM conversations WHERE listingId = ?').bind(lid),
            env.DB.prepare('DELETE FROM photos WHERE listingId = ?').bind(lid),
            env.DB.prepare('DELETE FROM favorites WHERE listing_id = ?').bind(lid),
            env.DB.prepare('DELETE FROM reports WHERE listingId = ?').bind(lid),
            env.DB.prepare('DELETE FROM boosts WHERE listingId = ?').bind(lid),
            env.DB.prepare('DELETE FROM listings WHERE id = ?').bind(lid),
          ]);
        } else if (b.action === 'remove') {
          await env.DB.batch([
            env.DB.prepare("UPDATE listings SET status = 'REMOVED' WHERE id = ?").bind(rep.listingId),
            env.DB.prepare("UPDATE reports SET status = 'RESOLVED' WHERE id = ?").bind(rep.id)
          ]);
        } else {
          await env.DB.prepare("UPDATE reports SET status = 'RESOLVED' WHERE id = ?").bind(rep.id).run();
        }
        return ok();
      }
      if (seg[1] === 'listings' && method === 'GET') {
        const rows = (await env.DB.prepare(
          `SELECT l.id, l.title, l.ptype, l.rent, l.town, l.area, l.status, l.views, l.createdAt, l.boostedUntil, us.username AS owner
           FROM listings l JOIN users us ON us.id = l.ownerId ORDER BY l.createdAt DESC LIMIT 200`).all()).results || [];
        return ok({ items: rows });
      }
      if (seg[1] === 'listings' && seg[2] && seg[3] === 'remove' && method === 'POST') {
        await env.DB.prepare("UPDATE listings SET status = 'REMOVED' WHERE id = ?").bind(N(seg[2])).run();
        return ok();
      }
      if (seg[1] === 'listings' && seg[2] && seg[3] === 'restore' && method === 'POST') {
        await env.DB.prepare("UPDATE listings SET status = 'AVAILABLE' WHERE id = ?").bind(N(seg[2])).run();
        return ok();
      }
      // HARD delete — 'remove' only hides a listing; this one wipes every trace
      // (photos, chats, favorites, reports, boosts, the row itself) so it is GONE.
      if (seg[1] === 'listings' && seg[2] && seg[3] === 'delete' && method === 'POST') {
        const lid = N(seg[2]);
        await env.DB.batch([
          env.DB.prepare('DELETE FROM messages WHERE convId IN (SELECT id FROM conversations WHERE listingId = ?)').bind(lid),
          env.DB.prepare('DELETE FROM conversations WHERE listingId = ?').bind(lid),
          env.DB.prepare('DELETE FROM photos WHERE listingId = ?').bind(lid),
          env.DB.prepare('DELETE FROM favorites WHERE listing_id = ?').bind(lid),
          env.DB.prepare('DELETE FROM reports WHERE listingId = ?').bind(lid),
          env.DB.prepare('DELETE FROM boosts WHERE listingId = ?').bind(lid),
          env.DB.prepare('DELETE FROM listings WHERE id = ?').bind(lid),
        ]);
        return ok();
      }
      if (seg[1] === 'users' && method === 'GET') {
        const rows = (await env.DB.prepare(
          `SELECT id, username, name, role, phone, verify_status, suspended, created_at FROM users ORDER BY created_at DESC LIMIT 300`)
          .all()).results || [];
        return ok({ items: rows });
      }
      if (seg[1] === 'users' && seg[2] && seg[3] === 'suspend' && method === 'POST') {
        const b = await json_();
        await env.DB.prepare('UPDATE users SET suspended = ? WHERE id = ? AND role != ?').bind(b.on ? 1 : 0, N(seg[2]), 'ADMIN').run();
        return ok();
      }
      // HARD delete a user — suspending only locks them out; this removes the
      // account and everything it owns: sessions, listings (+ photos, chats,
      // favorites, reports, boosts on them), their chats, favorites and reports.
      // Admin accounts can never be deleted, and an admin cannot delete themself.
      if (seg[1] === 'users' && seg[2] && seg[3] === 'delete' && method === 'POST') {
        const uid = N(seg[2]);
        if (uid === u.id) return bad('You cannot delete your own admin account.');
        await env.DB.batch([
          env.DB.prepare('DELETE FROM sessions WHERE user_id = ?').bind(uid),
          env.DB.prepare('DELETE FROM messages WHERE convId IN (SELECT id FROM conversations WHERE studentId = ? OR landlordId = ?)').bind(uid, uid),
          env.DB.prepare('DELETE FROM conversations WHERE studentId = ? OR landlordId = ?').bind(uid, uid),
          env.DB.prepare('DELETE FROM messages WHERE convId IN (SELECT id FROM conversations WHERE listingId IN (SELECT id FROM listings WHERE ownerId = ?))').bind(uid),
          env.DB.prepare('DELETE FROM conversations WHERE listingId IN (SELECT id FROM listings WHERE ownerId = ?)').bind(uid),
          env.DB.prepare('DELETE FROM photos WHERE listingId IN (SELECT id FROM listings WHERE ownerId = ?)').bind(uid),
          env.DB.prepare('DELETE FROM favorites WHERE listing_id IN (SELECT id FROM listings WHERE ownerId = ?)').bind(uid),
          env.DB.prepare('DELETE FROM reports WHERE listingId IN (SELECT id FROM listings WHERE ownerId = ?)').bind(uid),
          env.DB.prepare('DELETE FROM boosts WHERE listingId IN (SELECT id FROM listings WHERE ownerId = ?)').bind(uid),
          env.DB.prepare('DELETE FROM listings WHERE ownerId = ?').bind(uid),
          env.DB.prepare('DELETE FROM favorites WHERE user_id = ?').bind(uid),
          env.DB.prepare('DELETE FROM reports WHERE reporterId = ?').bind(uid),
          env.DB.prepare('DELETE FROM boosts WHERE userId = ?').bind(uid),
          env.DB.prepare('DELETE FROM users WHERE id = ? AND role != ?').bind(uid, 'ADMIN'),
        ]);
        return ok();
      }
    }

    return bad('Not found: ' + method + ' /api/' + seg.join('/'), 404);
  } catch (e) {
    const s = e.status || 500;
    if (s === 500) console.error('API error', e);
    // 5xx must not echo raw exception text (SQL internals etc.) to the client
    return bad(s === 500 ? 'Something went wrong on our side — please try again.' : (e.message || 'Server error'), s);
  }
}

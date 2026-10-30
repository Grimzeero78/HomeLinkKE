-- HomeLinKE — D1 schema reference (authoritative copy)
-- This mirrors the SCHEMA const in functions/api/[[route]].js, which is what
-- actually runs: /api/setup executes it on first hit, then applies versioned
-- ALTER TABLE migrations (see SCHEMA_VER / ensureSchema). Keep both in sync.
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
  bath TEXT NOT NULL DEFAULT '1',
  ensuite TEXT NOT NULL DEFAULT 'No',
  kitchen TEXT NOT NULL DEFAULT 'No',
  parking TEXT NOT NULL DEFAULT 'No',
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

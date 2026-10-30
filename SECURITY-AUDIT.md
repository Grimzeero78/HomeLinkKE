# HomeLinKE — White-Hat Security Audit

**Date:** 29 Oct 2026 · **Scope:** full API (`functions/api/[[route]].js`), client JS, headers, auth flows
**Method:** manual code review + automated attack suite (`scripts/whitehat_test.mjs`, 75 assertions) against a live local instance.

**Result: 75 / 75 PASSED.** All attempted attacks were blocked or rendered harmless.

## 1. Findings fixed during this audit

| # | Severity | Finding | Fix |
|---|----------|---------|-----|
| 1 | High | `/api/me` (GET) answered `200 ok` for **forged/expired tokens** and for **suspended** accounts (returned `user:null` / profile data instead of an error) | Now `401` without a valid session, `403` for suspended accounts |
| 2 | Medium | Fresh installs lacked the chat `edited` / `deleted` / `hiddenFor` columns (they existed only via old migrations) — message edit/delete crashed with 500 | Columns are now part of the base schema |
| 3 | Low | `POST /api/setup` had no rate limit before the admin was claimed — an attacker could hammer the one-time claim endpoint | Rate limited to 5 attempts/hour/IP (and permanently locked after the first claim via a unique-row race guard) |
| 4 | Low | `POST /api/listings/:id/boost` had no rate limit | Rate limited to 5/hour/user |
| 5 | Low | No request-body size cap — an attacker could stream arbitrarily large JSON bodies | All requests > 16 MB rejected with `413` (heaviest legitimate request ≈ 11 MB) |

## 2. Attacks tested and blocked (automated suite)

**Authentication & sessions**
- Brute-force login: locked after 15/min/IP and 8/min/username (`429`)
- Registration flood: locked after 8/hour/IP
- Constant-time hash compare; generic "Wrong username or password" (no user enumeration via login)
- Passwords: PBKDF2-SHA-256, 100 000 iterations, per-user 128-bit salt
- Sessions: 40-char CSPRNG tokens, 30-day expiry, server-side revocation on logout — **token is dead after logout** ✔
- Forged tokens rejected ✔ · suspended accounts blocked on every endpoint ✔

**Injection**
- SQL injection via search `q`, `town`, UNION SELECT, `DROP TABLE` payloads — all parameterised (`.bind()`), zero string-built SQL values; table survived ✔
- XSS: `<img onerror>`, `<script>` payloads stored as inert data; every render path escapes via `esc()`; API responses are `application/json` + `X-Content-Type-Options: nosniff` ✔

**Access control (IDOR)**
- Edit / delete / status-toggle / boost of another landlord's listing → blocked ✔
- Seeker attempting landlord-only actions → `403` ✔
- Opening or editing a stranger's conversation → `404` ✔
- Non-admin hitting admin endpoints → `401/403` ✔
- Deleted messages: text wiped server-side (tombstone), `hiddenFor` respected per viewer ✔

**Abuse prevention**
- Uploads: strict raster-image regex only (`png/jpg/webp/gif`) — **SVG and HTML uploads rejected** ✔
- 3–8 photos enforced; per-field length caps; 2-listing free cap / 5 verified
- View counter deduped 1 per IP per listing per 6 h; typing pings throttled; message 30/min; conv creation 10/min
- 17 MB body rejected with `413` ✔

**Headers** (`public/_headers`)
- `Content-Security-Policy` (self-only scripts, no third-party script origins)
- `X-Frame-Options: DENY`, `frame-ancestors 'none'` (no clickjacking)
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: geolocation=(self)` — location shared only with explicit user consent, and it **never leaves the device** (used client-side for distances only)

**Admin claim safety**
- One-time setup: unique `admin_locked` settings row makes the claim race-proof; second attempt `403`; rate limited ✔

## 3. Residual risks (accepted, documented)

- **Password hints** are recoverable via `/api/hint/:username` (rate limited 10/min/IP). By design it lets real users recover accounts; it also reveals whether a username exists. Mitigated by the rate limit and by hints never being passwords (enforced at registration).
- **Rate limiting is per-isolate** (in-memory). Distributed floods are absorbed by Cloudflare's edge; per-isolate windows are a defence-in-depth layer, not the only one.
- **Photos are stored as data URLs in D1.** Strict MIME + size caps keep this safe, but at large scale an R2 bucket would be the natural next step.
- **In-app payments do not exist by design** — the platform never handles rent; every surface repeats the "view first, pay later" rule.

## 4. How to re-run the audit

```bash
npx wrangler pages dev public --d1 DB=local-db --port 8794 &
node scripts/whitehat_test.mjs   # 75 assertions, expects 75 passed / 0 failed
```

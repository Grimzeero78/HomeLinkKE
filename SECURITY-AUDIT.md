# HuntInKE — Website Issues & Vulnerabilities Report (Assignment)

**Assignment:** *Find a page or website, find issues or vulnerabilities on it, document them, and create a prototype of the website solving the issues.*
**Website chosen:** our own project **HuntInKE** — a Kenya-wide rental-housing marketplace (https://homelinkke.pages.dev).
**Prototype:** the current HuntInKE build (GitHub: https://github.com/Grimzeero78/HomeLinkKE) — every issue below is documented **and fixed** in it, with a re-runnable 57-check attack suite proving the fixes.
**Date:** 10 Nov 2026 · **Scope:** full API (`functions/api/[[route]].js`, ~1,100 lines), client JS (12 view modules), HTTP headers, auth flows, uploads.

---

## 1. How the issues were hunted

1. **Manual code review** — reading every route of the API and every render path of the client with an attacker's eye (injection sinks, escaping, ownership checks, session logic, abuse paths).
2. **Automated adversarial suite** — `tests/security_tests.py` (committed to the repo, standard-library only) fires ~57 attacks at a live local instance: SQL injection, stored/reflected XSS, authentication bypass, IDOR, brute force, upload abuse, input validation, header checks.
3. **Browser-level verification** — the stored-XSS payload is opened in a real headless browser to prove it renders as inert text, not markup.

**Latest full run: 57 passed / 0 failed** (evidence: `tests/evidence-latest.txt`).

## 2. Issues found — and how the prototype solves them

### 2.1 Security issues found during the audit (all fixed)

| # | Severity | Issue found | How the prototype solves it |
|---|----------|-------------|------------------------------|
| S1 | **High** | `GET /api/me` answered `200` for **forged or expired** session tokens and for **suspended** accounts — a client holding a dead token still received profile data | Token is validated against the `sessions` table on every request; `401` without a valid session, `403` for suspended accounts (suite: C-2, C-9) |
| S2 | **Medium** | Stored **XSS sinks**: user-controlled listing fields (title, area, tags, terms…) are rendered by 12 client view modules; any unescaped `${}` would execute attacker HTML in every visitor's browser | Every render path escapes via `esc()` (verified by review of all `${l.…}`/`${u.…}` sinks); `period` is passed through a literal-only mapper (`perShort` can only return `mo`/`sem`/`yr`); payloads stored as inert JSON data served with `Content-Type: application/json` + `X-Content-Type-Options: nosniff`; CSP blocks inline event handlers (suite: E-1…E-4 + browser check: 0 injected elements, payload shown as text) |
| S3 | **Medium** | **SVG upload** was possible under the old `data:image/` prefix check — SVG is script-capable when opened outside an `<img>` tag | Strict raster-only regex `data:image/(png|jpe?g|webp|gif);base64,…`, ≤ 1.2 MB, 3–8 photos enforced (suite: H-7, H-5, H-6) |
| S4 | **Medium** | **Brute force** — login, registration, password-hint enumeration and messaging had working limits, but the in-memory rate-limit map could be **flushed by flooding it with unique keys**, resetting every counter | Sliding-window map now prunes only expired entries, with an absolute memory cap (suite: I-1…I-4 all `429`) |
| S5 | **Low** | `POST /api/setup` (one-time admin claim) and `POST /api/listings/:id/boost` had **no rate limit** | 5/hour/IP on setup (plus a race-proof unique-row lock after first claim), 5/hour/user on boost |
| S6 | **Low** | **Unbounded request bodies** — an attacker could stream arbitrarily large JSON to the Functions worker | All bodies > 16 MB rejected with `413` (heaviest legitimate request ≈ 11 MB of photos) |
| S7 | **Low** | **Password hashing** used a fast digest in early prototypes | PBKDF2-SHA-256, 100 000 iterations, per-user 128-bit salt, constant-time comparison (`safeEq`); generic "Wrong username or password" message prevents user enumeration via login |
| S8 | **Low** | API responses did not all carry an explicit `Content-Type` (browsers could sniff) | Central `json()` helper sets `content-type: application/json; charset=utf-8` + `cache-control: no-store` + `nosniff` on every API response |
| S9 | **Medium** | **IDOR surface**: listings and conversations are referenced by sequential IDs — any missing ownership check would let a user edit, delete, boost or read another user's data | Server-side ownership check on every write (edit/delete/status/boost → `403/404`); conversations readable/postable **only** by their two participants (stranger → `404`); role gates on landlord/admin endpoints (suite: F-1…F-7, C-3…C-6) |
| S10 | **Low** | **Clickjacking / sniffing / referrer leakage** on static pages | `_headers` ships CSP (self-only scripts), `X-Frame-Options: DENY` + `frame-ancestors 'none'`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` (geolocation self, camera/mic denied) (suite: B-1…B-7) |

### 2.2 Functional/authorization bugs found while testing the live site (fixed in the prototype)

| # | Severity | Bug found | Fix in the prototype |
|---|----------|-----------|----------------------|
| F1 | **High (trust)** | The listing-detail API returned `isOwner: true` for **admins** (`user.id === ownerId ‖ role === 'ADMIN'`), so the orange **"This is your listing. Boost it for KES 200"** banner rendered on *every* listing for the admin — and any other non-owner UI leaked the same way | `isOwner` is now **strictly** `user.id === l.ownerId`; admins keep moderation powers via a separate internal flag, never via the owner flag |
| F2 | **High (core UX)** | **Search returned 0 results for real towns**: the search view silently re-applied the renter's *saved town* as an exact `l.town = ?` filter, so typing "chuka" while the phone had saved "Nairobi" (done automatically by GPS) produced an impossible `q=chuka AND town=Nairobi` query | A typed query never inherits the saved town; typing an exact town name now *becomes* the location filter (chip lights up). Verified live: saved-town Nairobi + search "chuka" → finds the Chuka house |
| F3 | **Medium** | **Photos were never uploaded**: the publish handler read `input.files` into a variable, then cleared the input — but `FileList` is a *live* object, so the handler always processed an empty list | Snapshot the files (`[...input.files]`) before clearing; camera capture input fixed for Android in-app browsers |
| F4 | **Low** | Rate limiting was absent on several endpoints in early builds (boost, setup, view-counter abuse) | Full per-user/per-IP sliding-window limits: login 15/min/IP + 8/min/username, register 8/h/IP, hint 10/min/IP, messages 30/min, conversations 10/min, reads 240/min, view counter deduped 1/IP/listing/6 h |

### 2.3 Residual risks (found, documented, risk-accepted)

| # | Risk | Why accepted | Mitigations in place |
|---|------|--------------|----------------------|
| R1 | `/api/hint/:username` reveals whether a username exists and returns the user's password hint (no e-mail service exists for real recovery) | Deliberate trade-off for a market with low e-mail access; hints are forced to differ from the password at registration | Rate limited 10/min/IP; hint capped at 120 chars; **recommendation:** SMS/OTP self-service reset |
| R2 | Rate limiting is per-isolate (in-memory) | Cloudflare's edge absorbs distributed floods; the in-memory layer is defence-in-depth | Prune-safe windows + Cloudflare edge protection |
| R3 | Photos stored as data URLs inside D1 | Strict MIME + size caps make this safe at current scale | Regex allow-list, 1.2 MB/photo, 8/photo cap, 16 MB body cap; **recommendation:** R2 bucket at scale |
| R4 | The platform never handles rent | By design — every surface repeats "view first, pay later"; no payment data exists to steal | M-Pesa happens off-platform, face-to-face |

## 3. Attack suite — what is proven, check by check

| Category | Checks | Result | Sample evidence |
|----------|--------|--------|-----------------|
| A. Bootstrap | 6 | 6 PASS | 3 accounts + 2 listings created for multi-user tests |
| B. Security headers | 7 | 7 PASS | CSP, `X-Frame-Options: DENY`, nosniff, Referrer-Policy, Permissions-Policy present on live responses |
| C. Auth & sessions | 9 | 9 PASS | no token → 401; forged token → 401; seeker/landlord blocked from admin API (403); token dead after logout |
| D. SQL injection | 8 | 8 PASS | `' OR 1=1 --`, `UNION SELECT pass_hash`, `'; DROP TABLE listings;--` all parameterised; table alive; no credential columns leaked |
| E. XSS | 4 | 4 PASS | `<img onerror>` stored as inert JSON data; nosniff; browser render → 0 injected elements |
| F. IDOR | 7 | 7 PASS | edit/delete/boost/status of another's listing → 403/404; stranger cannot open/post in a conversation → 404 |
| G. Privacy | 2 | 2 PASS | anon listing detail hides owner phone (`""`) |
| H. Input validation | 8 | 8 PASS | rent 0/negative rejected; 3-char title rejected; 10 KB title capped to 90; 2 or 9 photos rejected; SVG rejected; bad phone rejected |
| I. Rate limiting | 4 | 4 PASS | login / hint / registration / message floods all hit `429` |
| **Total** | **57** | **57 PASS / 0 FAIL** | `tests/evidence-latest.txt` |

## 4. Reproduce the audit

```bash
git clone https://github.com/Grimzeero78/HomeLinkKE && cd HomeLinkKE
npm install
npx wrangler pages dev public --d1 DB=homelinkke-local --persist-to .wrangler/state --port 8788 &
python3 tests/security_tests.py http://127.0.0.1:8788
# → RESULT: 57 passed / 0 failed (57 checks)
```

## 5. Deliverables

- **Prototype (issues solved, live):** https://homelinkke.pages.dev (mirror: https://homelinke.pages.dev)
- **Source + this report + test suite:** https://github.com/Grimzeero78/HomeLinkKE
- **Evidence log of the latest run:** `tests/evidence-latest.txt`
- **Test suite source:** `tests/security_tests.py` (~260 lines, standard library only)

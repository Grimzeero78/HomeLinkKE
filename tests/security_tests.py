#!/usr/bin/env python3
"""
HuntInKE — white-hat security test suite (assignment artifact).

WHAT IT PROVES
--------------
Runs ~50 adversarial assertions against a running local instance of the site:
SQL injection, stored/reflected XSS, authentication bypass, session handling,
IDOR / broken access control, rate-limit brute force, input validation,
upload abuse and security headers.

HOW TO RUN
----------
  1) npx wrangler pages dev public --d1 DB=homelinkke-local --persist-to .wrangler/state --port 8788
  2) python3 tests/security_tests.py http://127.0.0.1:8788

Every check prints PASS/FAIL with observed evidence; the script exits 0 only
when every check passes. Standard library only (no dependencies).
"""
import json, sys, time, urllib.request, urllib.error, base64
from urllib.parse import quote

BASE = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8788'
SUF = str(int(time.time()))[-6:]          # unique usernames per run
PNG = ('data:image/png;base64,' + base64.b64encode(
    bytes.fromhex('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489'
                  '0000000d49444154789c626001000000ffff03000006000557bfabd40000000049454e44ae426082')).decode())
PASS = 0; FAIL = 0; ROWS = []

class CIDict(dict):
    """case-insensitive header dict — HTTP header names are case-insensitive"""
    def __init__(self, items):
        super().__init__((k.lower(), v) for k, v in items)
    def get(self, k, d=None):
        return super().get(k.lower(), d)

def req(method, path, body=None, token=None):
    r = urllib.request.Request(BASE + path, method=method)
    r.add_header('content-type', 'application/json')
    if token: r.add_header('Authorization', 'Bearer ' + token)
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(r, data, timeout=30) as res:
            b = res.read().decode()
            try: j = json.loads(b) if b else {}
            except Exception: j = {'raw': b[:200]}
            return res.status, CIDict(res.headers.items()), j
    except urllib.error.HTTPError as e:
        b = e.read().decode()
        try: j = json.loads(b)
        except Exception: j = {'raw': b[:200]}
        return e.code, CIDict(e.headers.items()), j
    except Exception as e:
        return 0, CIDict([]), {'error': str(e)}

def check(cat, name, cond, evidence=''):
    global PASS, FAIL
    if cond: PASS += 1
    else: FAIL += 1
    tag = '  PASS  ' if cond else '> FAIL  '
    print(tag + f'[{cat}] {name}' + (f'  — {evidence}' if evidence and not cond else ''))
    ROWS.append((cat, name, 'PASS' if cond else 'FAIL', evidence))

def register(username, role, phone='0712345678'):
    return req('POST', '/api/register', {
        'role': role, 'name': 'QA ' + username, 'phone': phone, 'username': username,
        'password': 'Str0ngPass!', 'confirm': 'Str0ngPass!', 'hint': 'not the password'})

def listing_body(**over):
    b = {'title': 'QA test house ' + SUF, 'ptype': 'Bedsitter', 'rent': 7000, 'period': 'Per Month',
         'town': 'Nairobi', 'area': 'Kilimani', 'units': 3, 'unitsVacant': 2,
         'photos': [PNG, PNG, PNG]}
    b.update(over); return b

# ================= A. bootstrap =================
print('== A. bootstrap (test data setup)')
s, h, j = req('GET', '/')
check('A', 'site responds 200', s == 200, f'status={s}')
for who, role in (('lndla' + SUF, 'LANDLORD'), ('lndlb' + SUF, 'LANDLORD'), ('seekr' + SUF, 'SEEKER')):
    s, h, j = register(who, role)
    check('A', f'register {who[:5]}... ({role})', s == 200 and j.get('ok'), f'status={s} {str(j)[:80]}')
    globals()['tk_' + who[:5]] = j.get('token')
TA, TB, TS = tk_lndla, tk_lndlb, tk_seekr
s, h, j = req('POST', '/api/listings', listing_body(), TA)
A_ID = (j.get('listing') or {}).get('id') if isinstance(j.get('listing'), dict) else j.get('id')
check('A', 'landlord A posts a listing', s == 200 and j.get('ok') and A_ID, f'status={s} {str(j)[:100]}')
s, h, j = req('POST', '/api/listings', listing_body(town='Chuka', area='Magumani', title='QA chuka house ' + SUF), TB)
B_ID = j.get('id')
check('A', 'landlord B posts a listing (Chuka)', s == 200 and j.get('ok') and B_ID, f'status={s} {str(j)[:100]}')

# ================= B. security headers =================
print('== B. security headers (GET /)')
s, h, j = req('GET', '/')
H = {k.lower(): v for k, v in h.items()}
for hdr, label in (('content-security-policy', 'Content-Security-Policy present'),
                   ('x-frame-options', 'X-Frame-Options present (anti-clickjacking)'),
                   ('x-content-type-options', 'X-Content-Type-Options: nosniff'),
                   ('referrer-policy', 'Referrer-Policy set'),
                   ('permissions-policy', 'Permissions-Policy locks camera/mic')):
    check('B', label, hdr in H, f'observed header names: {list(H)[:14]}')
check('B', 'X-Frame-Options value is DENY', H.get('x-frame-options', '').upper() == 'DENY', str(H.get('x-frame-options')))
s, h, j = req('GET', '/api/listings')
check('B', 'API answers JSON with nosniff', (h.get('content-type') or '').startswith('application/json')
      and (h.get('x-content-type-options') or '') == 'nosniff', str({k: h.get(k) for k in ('content-type', 'x-content-type-options')}))

# ================= C. authentication & sessions =================
print('== C. authentication & sessions')
s, h, j = req('GET', '/api/me')
check('C', 'no token -> /api/me is 401', s == 401, f'status={s} {str(j)[:80]}')
s, h, j = req('GET', '/api/me', token='forged' + 'A' * 40)
check('C', 'forged token -> 401', s == 401, f'status={s} {str(j)[:80]}')
s, h, j = req('POST', '/api/listings', listing_body(), TS)
check('C', 'seeker cannot post a listing (role gate)', s in (401, 403), f'status={s} {str(j)[:80]}')
s, h, j = req('GET', '/api/my/listings')
check('C', 'anon /api/my/listings -> 401', s == 401, f'status={s}')
s, h, j = req('GET', '/api/admin/overview', token=TS)
check('C', 'seeker cannot reach admin API', s in (401, 403), f'status={s} {str(j)[:80]}')
s, h, j = req('GET', '/api/admin/boosts', token=TB)
check('C', 'landlord cannot reach admin API', s in (401, 403), f'status={s} {str(j)[:80]}')
s, h, j = req('POST', '/api/logout', token=TA)
check('C', 'logout accepted', s == 200 and j.get('ok'), f'status={s}')
s, h, j = req('GET', '/api/me', token=TA)
check('C', 'token is dead server-side after logout', s == 401, f'status={s} {str(j)[:60]}')
s, h, j = req('POST', '/api/login', {'username': 'lndla' + SUF, 'password': 'Str0ngPass!'})
check('C', 're-login issues a fresh session', s == 200 and j.get('token'), f'status={s}')
TA = j.get('token', TA)

# ================= D. SQL injection =================
print('== D. SQL injection')
for name, q in (("search q=\"' OR 1=1 --\"", "' OR 1=1 --"),
                ("search q=\"x' UNION SELECT pass_hash FROM users--\"", "x' UNION SELECT pass_hash FROM users--"),
                ("search q=\"'; DROP TABLE listings;--\"", "'; DROP TABLE listings;--")):
    s, h, j = req('GET', '/api/listings?limit=100&q=' + quote(q))
    check('D', name + ' -> handled, no error', s == 200 and j.get('ok') is not False, f'status={s} {str(j)[:80]}')
    leak = 'pass_hash' in json.dumps(j).lower()
    check('D', 'no credential columns leaked', not leak, 'pass_hash appeared in response!')
s, h, j = req('GET', '/api/listings?limit=100')
ok_after = s == 200 and any(str(i.get('title', '')).startswith('QA test house') for i in j.get('items', []))
check('D', 'listings table alive after DROP attempt', ok_after, f'status={s} items={len(j.get("items", []))}')
s, h, j = req('POST', '/api/login', {'username': "' OR 1=1--", 'password': 'x'})
check('D', "login username \"' OR 1=1--\" rejected", s in (400, 401), f'status={s}')
s, h, j = req('GET', '/api/listings?town=' + quote("Chuka'--"))
check('D', "town filter \"Chuka'--\" parameterised", s == 200 and j.get('ok'), f'status={s}')
s, h, j = req('GET', '/api/listings/' + quote('1 OR 1=1'))
check('D', 'listing id path injection rejected (no 500)', s in (400, 404), f'status={s}')

# ================= E. XSS / stored payload safety =================
print('== E. XSS / stored payload safety')
XT = '<img src=x onerror=alert(1)> house'
s, h, j = req('POST', '/api/listings', listing_body(title=XT, area='<svg onload=alert(1)>', tags='<script>alert(1)</script>,wifi'), TA)
X_ID = j.get('id')
check('E', 'payload title accepted as DATA (no crash, no execution)', s == 200 and j.get('ok'), f'status={s} {str(j)[:80]}')
s, h, j = req('GET', f'/api/listings/{X_ID}')
check('E', 'stored payload served as application/json + nosniff', (h.get('content-type') or '').startswith('application/json')
      and h.get('x-content-type-options') == 'nosniff', str(h.get('content-type')))
check('E', 'payload stored verbatim (inert data, never executed server-side)', (j.get('listing') or {}).get('title') == XT,
      str((j.get('listing') or {}).get('title'))[:60])
s, h, j = req('GET', '/api/listings?limit=20&q=' + quote('<script>'))
check('E', 'reflected <script> search -> safe JSON', s == 200 and (h.get('content-type') or '').startswith('application/json'), f'status={s}')

# ================= F. IDOR / broken access control =================
print('== F. IDOR / broken access control')
s, h, j = req('PUT', f'/api/listings/{A_ID}', {'rent': 1}, TB)
check('F', "B cannot edit A's listing", s in (403, 404), f'status={s} {str(j)[:60]}')
s, h, j = req('DELETE', f'/api/listings/{A_ID}', token=TB)
check('F', "B cannot delete A's listing", s in (403, 404), f'status={s} {str(j)[:60]}')
s, h, j = req('POST', f'/api/listings/{A_ID}/boost', {'mpesaCode': 'QX12TZ', 'senderName': 'B'}, TB)
check('F', "B cannot boost A's listing", s in (403, 404), f'status={s} {str(j)[:60]}')
s, h, j = req('POST', f'/api/listings/{A_ID}/status', {'vacant': 0}, TB)
check('F', "B cannot flip A's listing status", s in (403, 404), f'status={s} {str(j)[:60]}')
s, h, j = req('POST', '/api/convs', {'listingId': A_ID}, TS)
CONV = j.get('id')
check('F', 'seeker opens a conversation on A1', s == 200 and CONV, f'status={s} {str(j)[:60]}')
s, h, j = req('GET', f'/api/convs/{CONV}', token=TB)
check('F', 'stranger B cannot open the A-S conversation', s == 404, f'status={s} {str(j)[:60]}')
s, h, j = req('POST', f'/api/convs/{CONV}', {'body': 'interjecting'}, TB)
check('F', 'stranger B cannot post into that thread', s == 404, f'status={s} {str(j)[:60]}')

# ================= G. privacy =================
print('== G. privacy')
s, h, j = req('GET', f'/api/listings/{A_ID}')
LJ = j.get('listing') or {}
check('G', 'anon listing detail hides owner phone', (LJ.get('ownerPhone') or '') == '' and (LJ.get('contactPhone') or '') == '',
      str({k: LJ.get(k) for k in ('ownerPhone', 'contactPhone')}))
s, h, j = req('GET', '/api/hint/lndla' + SUF)
check('G', 'password-hint endpoint rate limited & capped (documented residual risk)', s == 200 and len(str(j.get('hint', ''))) <= 120, f'status={s} len={len(str(j.get("hint", "")))}')

# ================= H. input validation & upload abuse =================
print('== H. input validation & upload abuse')
s, h, j = req('POST', '/api/listings', listing_body(rent=0), TB)
check('H', 'rent=0 rejected', s == 400, f'status={s} {str(j)[:60]}')
s, h, j = req('POST', '/api/listings', listing_body(rent=-500), TB)
check('H', 'negative rent rejected', s == 400, f'status={s} {str(j)[:60]}')
s, h, j = req('POST', '/api/listings', listing_body(title='abc'), TB)
check('H', '3-char title rejected', s == 400, f'status={s} {str(j)[:60]}')
s, h, j = req('POST', '/api/listings', listing_body(title='X' * 10000), TB)
if s == 200 and j.get('ok'):
    s2, h2, j2 = req('GET', f"/api/listings/{j.get('id')}")
    stored = len((j2.get('listing') or {}).get('title', ''))
    check('H', '10 KB title capped at 90 chars', stored <= 90, f'stored={stored}')
else:
    check('H', '10 KB title capped at 90 chars', s == 400, f'status={s}')
s, h, j = req('POST', '/api/listings', listing_body(photos=[PNG, PNG]), TB)
check('H', 'only 2 photos rejected (min 3)', s == 400, f'status={s} {str(j)[:60]}')
s, h, j = req('POST', '/api/listings', listing_body(photos=[PNG] * 9), TB)
check('H', '9 photos rejected (max 8)', s == 400, f'status={s} {str(j)[:60]}')
SVG = 'data:image/svg+xml;base64,' + base64.b64encode(b'<svg onload=alert(1)>').decode()
s, h, j = req('POST', '/api/listings', listing_body(photos=[SVG, SVG, SVG]), TB)
check('H', 'SVG upload rejected (script-capable format)', s == 400, f'status={s} {str(j)[:60]}')
s, h, j = register('badph' + SUF, 'SEEKER', phone='123')
check('H', 'invalid Kenyan phone rejected at registration', s == 400, f'status={s} {str(j)[:60]}')

# ================= I. rate limiting (run LAST — floods the windows) =================
print('== I. rate limiting (brute force)')
got429, tries = False, 0
for i in range(12):
    tries = i + 1
    s, h, j = req('POST', '/api/login', {'username': 'lndlb' + SUF, 'password': 'wrongpw' + str(i)})
    if s == 429: got429 = True; break
check('I', 'login brute force locked with 429', got429, f'last status={s} after {tries} tries')
got429, tries = False, 0
for i in range(12):
    tries = i + 1
    s, h, j = req('GET', '/api/hint/lndlb' + SUF)
    if s == 429: got429 = True; break
check('I', 'hint enumeration locked with 429', got429, f'last status={s} after {tries} tries')
got429, tries = False, 0
for i in range(9):
    tries = i + 1
    s, h, j = register('flood' + str(i) + SUF, 'SEEKER')
    if s == 429: got429 = True; break
check('I', 'registration flood locked with 429', got429, f'last status={s} after {tries} tries')
got429, tries = False, 0
for i in range(40):
    tries = i + 1
    s, h, j = req('POST', f'/api/convs/{CONV}/messages', {'text': 'spam ' + str(i)}, TS)
    if s == 429: got429 = True; break
check('I', 'message spam locked with 429 (30/min)', got429, f'last status={s} after {tries} msgs')

# ================= summary =================
print('\n' + '=' * 64)
print(f'RESULT: {PASS} passed / {FAIL} failed  ({PASS + FAIL} checks)')
print('=' * 64)
if FAIL:
    print('FAILED CHECKS:')
    for cat, name, st, ev in ROWS:
        if st == 'FAIL': print(f'  [{cat}] {name} — {ev}')
sys.exit(1 if FAIL else 0)

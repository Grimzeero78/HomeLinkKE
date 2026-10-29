# HomeLinkKE — Houses & Rentals across Kenya

A mobile-first PWA where **every Kenyan** can find or list vacant houses, bedsitters
and apartments in any town. Built on the proven ChukaHomes engine, rebuilt Kenya-wide:

- **Houses near me** — the app asks for your location and shows vacant houses nearest to you, with real distances.
- **Town-targeted Boosts** — a KES 200 boost pins a listing at the top **only for renters browsing that town**. A Nanyuki boost never disturbs a Nairobi feed.
- **Search is never limited** — anyone can search any town, estate or landmark in Kenya.
- WhatsApp-first contact, M-Pesa boosts, landlord verification, in-app chat with
  edit / delete-for-everyone / quick replies, dark mode, and a real Google map everywhere.

## Stack

- **Cloudflare Pages** — static frontend (`public/`) + Pages Functions API (`functions/api/`)
- **Cloudflare D1** (SQLite) — database, bound as `DB`
- **No build step** — deploy as-is

## Deploy (one time, ~5 minutes)

1. **Create the Pages project**
   - Cloudflare dashboard → Workers & Pages → Create → Pages → **Connect to Git**
   - Pick the `homelinkke` repository → Begin setup
   - Build command: *(leave empty)* · Build output directory: `public`
   - Save and Deploy (the first deploy works but shows "Database not connected" until step 2)
2. **Create the database**
   - Cloudflare dashboard → Storage & Databases → D1 → Create → name it `homelinkke-db`
   - Open it → copy the **Database ID**
3. **Bind the database to the project**
   - Your Pages project → Settings → Bindings → Add → **D1 database**
   - Variable name: `DB` · Database: `homelinkke-db` → Deploy
4. **Claim the admin account immediately**
   - Open the site, go to `/#/setup`
   - The first account created there becomes the Admin and the page locks forever after.
   - Rate limited to 5 attempts per hour per IP — do this right after deploying.
5. **Set your M-Pesa boost number**
   - Sign in as admin → Admin → Settings → save the paybill number and account name.

## Security notes

See [SECURITY-AUDIT.md](./SECURITY-AUDIT.md) for the full white-hat test report:
XSS, SQL injection, IDOR, brute force, rate limits, upload validation, payload caps,
security headers and the admin-claim lock — all tested and passing.

## Local development

```bash
npx wrangler pages dev public --d1 DB=local-db
# open http://localhost:8788
```

# HuntIn KE — Flutter App (Android)

The **exact mobile version of the HuntInKE website** (https://homelinkke.pages.dev).
Same backend, same accounts, same features: search by town, houses near you (GPS),
map with price pins, chat with landlords, post/edit listings with photos, boost for
KES 200, favourites, admin panel, light/dark theme — and local notifications.

> The app talks to `https://homelinkke.pages.dev/api` with the same Bearer-token
> login as the website. **An account made in the browser works in the app and
> vice-versa.** Nothing to configure.

---

## 1. What is already done for you

| Piece | Status |
| --- | --- |
| `lib/` — the complete app (16 screens) | ✅ done |
| `pubspec.yaml` — all dependencies | ✅ done |
| App icons — launcher, round, adaptive, notification, splash | ✅ done (`android/`) |
| Play Store 512 icon | ✅ done (`assets/icon/playstore-512.png`) |
| AndroidManifest with all permissions | ✅ done (`android/APP_MANIFEST.xml`) |
| Launch splash (green + logo, light & dark) | ✅ done (`android/`) |
| Notifications (channels + runtime permission) | ✅ done (`lib/notifs.dart`) |
| ProGuard rules for release builds | ✅ done |

## 2. Set-up (one time, ~3 minutes)

Open **your existing VS Code project** folder (the one you created with Flutter), then:

**Step 1 — replace the code.**
Delete your project's `lib/` folder and `pubspec.yaml`, then copy these in from this package:

```
lib/            →  your-project/lib/
pubspec.yaml    →  your-project/pubspec.yaml
assets/         →  your-project/assets/
```

**Step 2 — copy the Android pieces.**
Copy the contents of this package's `android/app/src/main/res/` **over**
your project's `android/app/src/main/res/` (it just overwrites icons and adds
splash/adaptive files — safe).
Then copy `android/APP_MANIFEST.xml` over
`android/app/src/main/AndroidManifest.xml`.

**Step 3 — set the Play Store identity.**
Open `android/app/build.gradle` and make sure these two lines inside `defaultConfig { }` say:

```gradle
applicationId = "com.huntinke.app"   // Groovy: applicationId "com.huntinke.app"
minSdk = 24
```

(Kotlin DSL users: `applicationId = "com.huntinke.app"` in `build.gradle.kts`.)
`android/BUILD_GRADLE_REFERENCE.gradle` in this package shows a full example.

**Step 4 — fetch & run.**

```bash
flutter pub get
flutter run
```

## 3. Build the APK (you said you'll do this)

```bash
# test APK (installs anywhere, debug-signed)
flutter build apk --release

# smaller, per-CPU APKs (recommended for sharing)
flutter build apk --split-per-abi
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## 4. Play Store checklist (when you're ready to publish)

1. **Keystore** (generate once, keep FOREVER — losing it means losing the app):
   ```bash
   keytool -genkey -v -keystore ~/huntinke-key.jks -keyalg RSA -keysize 2048 \
           -validity 10000 -alias huntinke
   ```
2. Create `android/key.properties` next to `app/build.gradle`:
   ```properties
   storePassword=YOUR_PASSWORD
   keyPassword=YOUR_PASSWORD
   keyAlias=huntinke
   storeFile=/home/YOU/huntinke-key.jks
   ```
   (`BUILD_GRADLE_REFERENCE.gradle` already reads this file.)
3. `flutter build appbundle` → upload `build/app/outputs/bundle/release/app-release.aab`.
4. Play Console needs:
   - App name: **HuntIn KE** · Category: **House & Home** (or Lifestyle)
   - Short description: "Find vacant houses, bedsitters & apartments across Kenya. Chat with landlords directly. Never pay before viewing."
   - Privacy policy URL: `https://homelinkke.pages.dev/#/privacy` (already live)
   - Screenshots: run the app and screenshot Home / Listing / Chat / Map
5. Version bumps: change `version: 1.0.0+1` → `1.0.1+2` in `pubspec.yaml` for every update (the `+N` is the versionCode).

## 5. Notifications

- The app asks **Allow notifications** on first launch (Android 13+).
- Channel **Messages** — fires when the unread poll detects a new chat message.
- Channel **Account & listings** — boost submitted, verification submitted, listing posted/updated.
- (Future, optional: real push while the app is closed needs Firebase Cloud Messaging — add it later without touching this UI.)

## 6. Where things live

```
lib/
  main.dart            app entry, splash, theme wiring
  api.dart             REST client → homelinkke.pages.dev/api  (same accounts)
  state.dart           session, saved town/GPS, unread badge poll
  data.dart            Kenya towns + every option list (same as the website)
  theme.dart           pine/ember/cream palette, light + dark
  widgets.dart         listing card, badges, chips, rows
  notifs.dart          notification channels
  screens/
    home.dart          hero, town chips, near-you (7 km), boosted, newest
    search.dart        filters + THE town-search fix (type "chuka" → Chuka houses)
    mapview.dart       OSM map with price pins, radius filter, place search
    listing.dart       gallery, facts, map, owner card: Call/WhatsApp/Message
    auth.dart          sign in / create account / password hint
    welcome.dart       role-aware getting-started guide
    create.dart        8-step post/edit wizard with map pin + photo compression
    mylistings.dart    vacancy stepper (−1/+1/All taken/Reopen), boost, delete
    boost.dart         KES 200 M-Pesa boost with paybill details
    chats.dart         conversation list (12 s poll)
    thread.dart        WhatsApp-style chat: ticks, typing, edit, delete
    profile.dart       profile, edit, landlord verification docs, theme, sign out
    favorites.dart     saved houses
    admin.dart         verifications / boosts / reports / listings / users
    privacy.dart       privacy & safety
```

## 7. Test account tip

Use the same username/password you already use on the website — e.g. sign in on
the browser, then sign in with the same credentials in the app: your listings,
favourites and chats are all there.

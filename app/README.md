# HuntIn KE — Flutter app

**The exact mobile version of the HuntInKE website** (https://homelinkke.pages.dev).
Same backend, same accounts — **login with the same username and password you use
in the browser.** 16 screens: home + town chips, search, GPS "near you", map with
price pins, listing detail + Call/WhatsApp, 8-step post wizard with photos,
vacancy stepper, boost KES 200, chats, favourites, admin panel, privacy,
light/dark theme, notifications.

This folder (`app/`) lives inside the HomeLinkKE repo, so every change I push
you get with one pull.

---

## ONE-TIME SETUP (about 5 minutes + first build)

**1. Clone the repo in VSCode**
- Press `Ctrl+Shift+P`, type `Git: Clone`, press Enter
- Paste: `https://github.com/Grimzeero78/HomeLinkKE.git` → Enter
- Choose a folder (e.g. Documents) → click **Open** when asked

> If VSCode says "git not found": install https://git-scm.com/download/win
> (Next → Next → Next), restart VSCode, try again.

**2. Open the app folder**
- File → Open Folder → inside the cloned `HomeLinkKE` folder, select the
  folder called **`app`** → Open

**3. In the terminal (`Ctrl+`` ` ``) run these 3 commands, one by one:**

```
flutter create --platforms=android,ios --org com.huntin --project-name ke .
flutter pub get
flutter build apk --release
```

The first command rebuilds the android phone parts (permissions, icon and
splash come from this repo; the build files are made on your machine).
**First build takes 5–15 minutes** (downloads Android tools) — needs internet,
don't close the terminal.

**4. Your APK:**

```
build\app\outputs\flutter-apk\app-release.apk
```

Copy it to your phone → tap it → allow "install unknown apps" → done.

---

## AFTER EVERY CHANGE (the normal loop)

1. You tell me the change → **I push it to GitHub**
2. You **pull**: click the Source Control icon (left side) → click the
   **circular-arrow / Pull** button — or in the terminal: `git pull`
3. Run again: `flutter build apk --release`

New APK with the changes. That's the whole loop.

---

## TEST ON YOUR PHONE LIVE (optional)

1. Phone: Settings → About phone → tap **Build number** 7 times → back →
   **Developer options** → turn ON **USB debugging**
2. Connect USB cable → tap **Allow** on the phone
3. Terminal: `flutter run`

---

## IF SOMETHING GOES WRONG

- Red underlines in VSCode right after cloning = normal. They disappear
  after `flutter pub get`.
- Error mentioning `minSdkVersion`: open `android/app/build.gradle`
  (or `build.gradle.kts`), find `minSdk`, change it to `24`, build again.
- Anything else: send me the last 20 lines of the terminal and I give you
  the exact fix.

---

## PLAY STORE

Package name is already correct (`com.huntin.ke`). Signing key + upload
checklist: **PLAY-STORE-LATER.txt** in this folder.

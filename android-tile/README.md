# Dev Toggle

A minimal, no-root Android Quick Settings tile that flips **Developer Options** and **USB Debugging** in a single tap.

Built for one specific annoyance: UPI apps (PhonePe, Google Pay, Paytm), most banking apps, and some DRM apps refuse to run while Developer Options is enabled. Every time you need to use one of those apps, you have to:

1. Open Settings.
2. Disable Developer Options.
3. Pay / authenticate.
4. Re-enable Developer Options (which means tapping "Build number" 7 times again on some OEM skins, or at least navigating back to the toggle).
5. Re-enable USB Debugging.

**Dev Toggle replaces those five steps with one tap.**

| Tile state | `development_settings_enabled` | `adb_enabled` |
|---|---|---|
| ON  | 1 | 1 |
| OFF | 0 | 0 |

The tile reflects whichever state the system is currently in. Tap once → both go OFF. Tap again → both go ON.

---

## Compatibility

| Requirement | Why |
|---|---|
| Android 8.0 (Oreo) or newer (API 26+) | TileService API + adaptive launcher icon |
| Computer with `adb` installed (one-time setup only) | To grant `WRITE_SECURE_SETTINGS` permission |
| USB cable for first install | Same |

You do **not** need:
- A rooted phone.
- Magisk, Shizuku, Xposed, or any framework patch.
- Wireless ADB on an ongoing basis. ADB is only used during initial setup.
- Any of the other tools in this repo. Dev Toggle works completely standalone.

---

## What the app needs and why

**Permission:** `android.permission.WRITE_SECURE_SETTINGS`.

This permission cannot be granted from the app's UI — Android only allows it via:
1. `adb shell pm grant ...` from a connected computer (the path used here),
2. Shizuku/root (not used by this app),
3. System pre-installation (not applicable).

The app cannot — and does not — communicate over the network, request any other permissions, or read or write user data outside the two `Settings.Global` integers above.

---

## Install

### Option 1 — install a pre-built APK

If a release is published, download the latest `app-release.apk` from the [Releases page](https://github.com/Tarunswamy-Muralidharan/adb-quickstart/releases) and install it on the phone.

Then continue with the [Grant permission](#grant-permission) step below.

### Option 2 — build from source

You need:
- **JDK 17** (Eclipse Temurin / Adoptium recommended).
- **Android SDK** with platforms `android-34` and build-tools `34.0.0` or newer. The simplest way to get this is to install [Android Studio](https://developer.android.com/studio) and let it provision the SDK on first launch.
- (Build script will download Gradle 8.9 automatically the first time you run it.)

Set `ANDROID_HOME` to your SDK location, or create `android-tile/local.properties`:

```
sdk.dir=/absolute/path/to/Android/Sdk
```

Then build:

```bash
cd android-tile
./gradlew assembleDebug              # macOS / Linux
.\gradlew.bat assembleDebug          # Windows
```

The output APK lands at `app/build/outputs/apk/debug/app-debug.apk`.

To produce a signed release APK, see [Signed release builds](#signed-release-builds) at the bottom.

### Install the APK

With the phone connected via USB and USB debugging on:

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Or copy the APK to the phone (email, cloud, USB transfer) and install from the file manager — make sure "Install unknown apps" is allowed for that source.

---

## Grant permission

This is the one step that needs a computer. The phone must be connected via USB or wireless ADB, and USB debugging must be on.

```bash
adb shell pm grant io.github.tarunswamy.devtoggle android.permission.WRITE_SECURE_SETTINGS
```

The app shows this exact command on its setup screen with a **Copy command** button if you'd rather pull it off the phone.

If `adb` says "permission denied", make sure:
- USB debugging is on,
- the phone is unlocked,
- you accepted the **Allow USB debugging?** prompt the first time you connected the phone to this computer.

---

## Add the tile

1. Open the **Dev Toggle** app once on the phone (so Android registers the TileService).
2. Swipe down twice from the top of the screen to open Quick Settings fully.
3. Tap the **pencil / edit** icon (location varies by OEM — usually bottom-right or bottom-centre of the panel).
4. Find **Dev Options** in the "available tiles" / "hold and drag to add" area.
5. Drag it into your active tiles. Save.

You're done. Tap the tile to test.

---

## Daily use

| Want to do | Tile action |
|---|---|
| Open a UPI / banking app that refuses to run with dev options | Tap tile (turns OFF). Use the app. |
| Get back to development | Tap tile (turns ON). |
| Check what state things are in without the tile | Open the **Dev Toggle** app — the home screen shows live status. |

When the tile is OFF, both Developer Options and USB Debugging are fully disabled (verified by reading the same `Settings.Global` keys the OS reads). UPI / banking apps see the same state as a fresh phone. When the tile is ON, both come back the way they were.

If something else changes those settings (e.g. you toggle them in Settings UI), the tile picks up the new state next time you open Quick Settings.

---

## Signed release builds

The included build configuration signs release builds with the **debug** key by default, which is fine for personal sideloading but **not** suitable for distribution. To produce a properly signed release APK:

1. Generate a keystore (one time):
   ```
   keytool -genkey -v -keystore release.keystore -alias devtoggle \
           -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Edit `android-tile/app/build.gradle.kts` and replace the `signingConfig = signingConfigs.getByName("debug")` line in the `release` block with a real `signingConfigs { create("release") { ... } }` block reading credentials from environment variables or a `keystore.properties` file (which must be `.gitignore`d).
3. `./gradlew assembleRelease`.

Never commit a keystore or its passphrase.

---

## Project layout

```
android-tile/
├── app/
│   ├── build.gradle.kts                    # Module build config
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/io/github/tarunswamy/devtoggle/
│       │   ├── DevToggleTileService.kt     # The tile logic — flips both settings
│       │   └── MainActivity.kt              # Setup / status UI
│       └── res/
│           ├── drawable/                    # Tile icon + adaptive icon layers
│           ├── mipmap-anydpi-v26/           # Adaptive launcher icon
│           └── values/                      # strings + colors
├── build.gradle.kts                        # Root build config
├── settings.gradle.kts
└── gradle/wrapper/                         # Gradle wrapper (8.9)
```

The actual TileService implementation is ~40 lines. The setup UI is ~120 lines. Everything else is project boilerplate.

---

## Privacy and safety

- **No network access.** `INTERNET` is not declared in the manifest; the app physically cannot make a network connection.
- **No data collection.** No analytics, no telemetry, no crash reporting.
- **Two `Settings.Global` keys.** The app reads `development_settings_enabled` and `adb_enabled`, and writes them when you tap the tile. Nothing else.
- **Open source.** Read [`DevToggleTileService.kt`](app/src/main/java/io/github/tarunswamy/devtoggle/DevToggleTileService.kt) — it's the entire toggle logic.

---

## Uninstalling

Same as any other app: long-press the icon → **Uninstall**, or **Settings → Apps → Dev Toggle → Uninstall**. Uninstall does not change the current state of `development_settings_enabled` or `adb_enabled`; if the tile was OFF when you uninstalled, both stay off until you turn them on yourself in Settings.

If you want to revoke the permission instead of uninstalling:

```bash
adb shell pm revoke io.github.tarunswamy.devtoggle android.permission.WRITE_SECURE_SETTINGS
```

---

## License

MIT — same as the parent repo.

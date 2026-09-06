# frontend/aod_clock/CLAUDE.md

Flutter-specific conventions for the `aod_clock` project — a Samsung
Always-On-Display replacement. See the root `CLAUDE.md` for repo-wide
orientation.

## Not a triple

Unlike every other project in this repo, `aod_clock` has **no
`backend/`/`contracts/`** — it's a pure on-device app with no server
component, a deliberate deviation from ADR 0007 (see
`aod-clock-adr-followup` in the user's memory). Because there's no
`contracts/aod_clock/openapi.yaml`, **this file is the source of truth for
the platform-channel wire contract** instead — keep it in sync with the
Kotlin `when` blocks it documents, the same discipline `contract-sync`
enforces for HTTP endpoints elsewhere in the repo.

## Structure

Same feature-first shape as catan-game/infera: `lib/core/` (theme, router,
persistence, platform-channel wrappers) + `lib/features/<name>/
{data,domain,presentation}`. Riverpod for state + DI — no GetIt, no second
DI mechanism. Unlike infera's `identity`/`weekly_case` features, this
project uses **plain `Provider`/`AsyncNotifier`, not `@riverpod` codegen
annotations** — no generated-code step is required to get the app running.
`riverpod_generator`/`build_runner`/`json_serializable` are still in
`pubspec.yaml` for parity with the other two projects, unused today.

`freezed` is intentionally absent, same constraint as catan-game/infera
(`analyzer` version conflict with `riverpod_generator ^4.0.4`).

Typography: `ClockWidget` uses Outfit ExtraLight, every other piece of
AOD-screen text (date, music player, notification count) uses Geist.
Fonts are **bundled local assets** (`assets/fonts/*.ttf`, declared in
`pubspec.yaml`'s `fonts:` section), not the `google_fonts` package —
that was tried first (2026-08-24) and reverted the same day: it fetches
font files over the network on first use, which is unreliable for a
screen rendered from a lockscreen-launched engine with unpredictable
network state, and the user found the fonts actually rendering wrong on
their real device. No `google_fonts` dependency in this project.

## Platform channel contract

Two Activities share these channel names — `MainActivity` (settings UI) and
`AodOverlayActivity` (the AOD screen, launched by `AodForegroundService` on
screen-off) — both wire them up identically in `configureFlutterEngine`.
The Kotlin side (`android/app/src/main/kotlin/com/scylla/tool/aodclock/`)
is authoritative; the Dart wrappers below just mirror it.

- **`com.scylla.tool.aodclock/aod_control`** (MethodChannel) — handled by
  `AodControlHandler.kt`, wrapped by `core/platform/aod_control_channel.dart`.
  - `setAodEnabled({enabled: bool})` → `void` — writes `AodPrefs` (native
    SharedPreferences, not Flutter's SecureStorage) and starts/stops
    `AodForegroundService`.
  - `isAodEnabled()` → `bool`
  - `setBrightnessLevel({level: double})` → `void` — writes `AodPrefs`'s
    brightness value, which `AodOverlayActivity` reads for
    `window.attributes.screenBrightness`. Called on slider change *and*
    once on every settings load (`SettingsController.build()`) — the
    latter exists because this method was missing entirely until
    2026-08-24 (4), so a brightness value persisted before that fix
    needed a way to reach native without the user re-touching the slider.
  - `isNotificationListenerGranted()` → `bool`
  - `openNotificationListenerSettings()` → `void` — deep-links to
    `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`; no runtime dialog
    exists for this permission.
  - `isBatteryOptimizationExempt()` → `bool`
  - `requestBatteryOptimizationExemption()` → `void` — deep-links to
    `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
  - `isFullScreenIntentGranted()` → `bool` — `NotificationManager
    .canUseFullScreenIntent()` on API 34+, always `true` below that (not
    gated pre-Android 14). Auto-granted at install (confirmed on-device);
    exists because Android 14+ lets the user revoke it afterward.
  - `openFullScreenIntentSettings()` → `void` — deep-links to
    `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`, no-op below API 34.
  - `isNotificationsPermissionGranted()` → `bool` — `POST_NOTIFICATIONS`
    runtime grant on API 33+, always `true` below that. **This is the
    permission that actually gates whether AOD triggers at all** — see
    Native architecture below.
  - `requestNotificationsPermission()` → `void` — standard runtime
    permission dialog via `ActivityCompat.requestPermissions`, not a
    Settings deep link (unlike the others — this one has a real system
    prompt).
  - `dismissAodOverlay()` → `void` — only meaningful on
    `AodOverlayActivity`; calls `finish()`.

- **`com.scylla.tool.aodclock/now_playing/control`** (MethodChannel) —
  handled by `NowPlayingControlHandler.kt`, wrapped by
  `core/platform/now_playing_channel.dart`.
  - `play()`, `pause()`, `skipNext()`, `skipPrevious()` → `void`, forwarded
    to `NowPlayingBridge.activeController.transportControls`. No-op
    (silently succeeds) when nothing is playing.

- **`com.scylla.tool.aodclock/now_playing/events`** (EventChannel) —
  streamed from `MediaNotificationListenerService.kt` via `NowPlayingBridge`,
  parsed by `features/now_playing/data/datasources/now_playing_datasource.dart`.
  Each event is `Map<String, dynamic>?` (`null` = nothing playing):
  `title` (String?), `artist` (String?), `albumArt` (Uint8List?, JPEG
  bytes), `isPlaying` (bool), `positionMs` (int), `durationMs` (int).

- **`com.scylla.tool.aodclock/notification_count/events`** (EventChannel)
  — streamed from `MediaNotificationListenerService.kt` via
  `NotificationCountBridge`, wrapped by
  `core/platform/notification_count_channel.dart`. Payload is a plain
  `int?` (count of *other* apps' active notifications, this app's own
  foreground-service/trigger notifications excluded). Rides on the same
  "Notification access" permission already needed for now-playing — no
  separate grant.

## Native architecture (why it's shaped this way)

- **AOD is a show-when-locked Activity, not a `SYSTEM_ALERT_WINDOW`
  overlay** — `AodOverlayActivity` uses `setShowWhenLocked`/`setTurnScreenOn`
  (API 27 fallback: the deprecated `FLAG_SHOW_WHEN_LOCKED`/
  `FLAG_TURN_SCREEN_ON` window flags), same pattern real alarm/call apps
  use. No special "draw over other apps" permission, no `DISABLE_KEYGUARD`
  — a tap or a real unlock (`ACTION_USER_PRESENT`) finishes back to the
  actual lockscreen, PIN/biometric still required.
- **`AodForegroundService`** is the only long-lived native component. It
  exists solely to hold a screen-off `BroadcastReceiver` alive (Android
  doesn't deliver `ACTION_SCREEN_OFF` to a manifest-declared receiver on
  API 26+, it must be registered at runtime by something alive). Declared
  `foregroundServiceType="specialUse"` (Android 14+ requirement) since none
  of the built-in types describe this.
- **Launching `AodOverlayActivity` from the screen-off receiver uses a
  full-screen-intent notification, not a bare `startActivity()`.** First
  version used `startActivity()` directly and it silently did nothing on a
  real device — no crash, screen just turned off normally — because
  Android 10+'s background-activity-launch restrictions block starting an
  Activity from a `BroadcastReceiver` running inside a background service.
  A full-screen-intent notification (`Notification.Builder
  .setFullScreenIntent(pendingIntent, true)` on a high-importance channel)
  is the Android-sanctioned exemption — the same mechanism incoming-call
  and alarm apps use to draw over a locked screen. Needs
  `USE_FULL_SCREEN_INTENT` in the manifest.
- **The full-screen-intent fix alone still wasn't enough — real device
  testing found the actual root cause: `POST_NOTIFICATIONS` was never
  requested.** On API 33+, *every* notification an app posts — including
  the full-screen-intent trigger, not just a visible one — is silently
  dropped by the OS unless this runtime permission is granted. No crash, no
  log. Confirmed two ways on a booted Android 15 emulator:
  `adb shell cmd appops get <pkg> POST_NOTIFICATION` read `ignore`, and
  `adb shell dumpsys package <pkg>` showed no `POST_NOTIFICATIONS` grant at
  all. Fixed with the permission declared in the manifest, a real runtime
  request (`ActivityCompat.requestPermissions`), and the "Show
  notifications" tile in Settings — listed first, it's why "Check all
  permissions" exists, and it's the one to check first if AOD doesn't
  trigger.
- **Correcting an earlier wrong claim in this file's history**: an
  intermediate version of this doc claimed `USE_FULL_SCREEN_INTENT` is
  auto-denied by default for non-phone/alarm apps on Android 14+. Emulator
  testing disproved that — a fresh install showed it already granted. It's
  a normal permission, auto-granted at install like always; Android 14 only
  added the *user's* ability to revoke it afterward. Lesson: the
  `isFullScreenIntentGranted` tile earned its place, but the reasoning
  written for it the first time was a guess that didn't hold up once
  actually tested.
- **`MediaNotificationListenerService`** never reads notification content —
  its only purpose is being an *enabled* notification listener, which is
  what `MediaSessionManager.getActiveSessions()` requires to hand back the
  system's active `MediaController`. State is pushed to whichever Flutter
  engine is currently listening via the `NowPlayingBridge` singleton
  (`NowPlayingBridge.kt`), which also caches the last event so a
  freshly-attached sink doesn't have to wait for the next session change.
  Album art resolution checks an embedded `Bitmap`
  (`METADATA_KEY_ALBUM_ART`/`ART`/`DISPLAY_ICON`) first, then falls back to
  resolving a `content://` URI (`*_URI` variants of those same keys) via
  `ContentResolver` on a background thread — real apps commonly provide
  only the URI, not an embedded bitmap, to avoid Binder transaction size
  limits (found via real device testing 2026-08-24; Spotify/YouTube Music
  showed no art at all until this was added).
- **`AodPrefs`** (native `SharedPreferences`, not Flutter's SecureStorage)
  is the flag `AodForegroundService`'s screen-off receiver and `BootReceiver`
  actually check — neither has a live Dart engine to ask. Flutter's own
  settings datasource keeps its own copy for the UI; `setAodEnabled` writes
  both.
- **Refresh-rate management (2026-08-24)**: `AodOverlayActivity.onCreate`
  calls `window.decorView.setRequestedFrameRate
  (View.REQUESTED_FRAME_RATE_CATEGORY_LOW)`, guarded by
  `Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM` (API
  35, Android 15) — the only frame-rate control actually reachable from
  app code here. The older/lower-level `Surface.setFrameRate` needs direct
  access to the rendering `Surface`, which Flutter's embedding doesn't
  expose to app code. Two things have to both be true for this to do
  anything: the OS has to be API 35+, *and* the panel has to be
  LTPO-capable (Samsung S22 Ultra+/S23/24/25/Note20 Ultra) — a
  fixed-refresh panel just ignores the hint, and below API 35 the call is
  skipped entirely. This is genuinely a best-effort hint, not a guarantee.
  It pairs with `PixelShiftWrapper` using an instant `Transform.translate`
  instead of an animated transition (an 800ms animation every 60s was
  forcing ~48 frames of unnecessary panel wake) and `_ProgressBar`'s local
  1-second position ticker (`mini_music_player.dart`) — that ticker is the
  actual reason the display needs to redraw at ~1fps while music plays;
  without the frame-rate hint that redraw would just run at the panel's
  default rate instead of the lowest one an LTPO panel can sustain.

## Known simplifications (ponytail)

- `AodOverlayActivity` spins up a fresh `FlutterEngine` on every screen-off
  instead of reusing a pre-warmed `FlutterEngineCache` entry. Costs a few
  hundred ms of CPU per launch, not a continuous drain — negligible next to
  keeping the screen on for hours. Revisit if launch latency ever
  measurably matters.
- No repository-interface layer for `settings` (unlike `identity`'s
  data/repositories + domain/repositories split) — it's local storage only,
  one implementation ever, nothing to abstract over. The datasource is the
  whole data layer.
- Low-refresh-rate hinting (`Window.setFrameRate`, API 30+) is **not
  implemented yet** — it's real but genuinely LTPO-panel-only (Samsung
  S22 Ultra+/S23/24/25) and no-ops elsewhere, so it was deferred out of the
  first pass rather than guessed at without a device to verify it against.

## Commands

```
just project=aod_clock lint-frontend       # fvm flutter analyze
just project=aod_clock fmt-frontend        # fvm dart format
just project=aod_clock test-frontend       # fvm flutter test
just project=aod_clock build-frontend      # fvm flutter build apk
just project=aod_clock dev-frontend        # fvm flutter run
FIREBASE_APP_ID=1:141342333212:android:52d691a911ca2f2ea382d9 \
FIREBASE_TESTERS=[tester-email] \
FIREBASE_RELEASE_NOTES="what changed" \
  just project=aod_clock distribute-android  # release APK -> Firebase App Distribution
```

Bump **both** the patch version and the build number in `pubspec.yaml`
before every `distribute-android` run (`1.0.0+3` → `1.0.1+4`, not
`1.0.0+4`), and always pass `FIREBASE_RELEASE_NOTES` — two releases were
uploaded back-to-back as indistinguishable "1.0.0 (1)" with no notes, and a
later fix moved only the build number while the patch stayed at `1.0.0`
across three releases, before both became hard rules (user feedback,
2026-08-24).

### Firebase App Distribution

Dedicated Firebase project `aod-clock-app` (console:
https://console.firebase.google.com/project/aod-clock-app/overview),
created specifically for this project — not shared with catan-game's
Firebase project (`catan-game-3dfb7`), since App Distribution here is
unrelated to RTDB. Distribution is CLI-only: no `firebase_core`/
`google-services.json`/Gradle plugin integration, `firebase
appdistribution:distribute` just needs the App ID and doesn't require the
app to embed the Firebase SDK at all. `.firebaserc` in this directory
already points `default` at `aod-clock-app`, so plain `firebase ...`
commands run from here without `--project`.

- Android App ID: `1:141342333212:android:52d691a911ca2f2ea382d9`
  (package `com.scylla.tool.aodclock`) — not a secret, safe to keep in this
  file.
- Testers: `[tester-email]` added via
  `firebase appdistribution:testers:add`. Add more with the same command,
  or pass `FIREBASE_TESTERS`/`FIREBASE_GROUPS` (see the `distribute-android`
  justfile recipe) to target specific people per run.
- The release build type currently falls back to **debug signing**
  (`android/app/build.gradle.kts` — no `key.properties`/upload keystore set
  up yet, same TODO infera has). Fine for App Distribution testing; would
  need real release signing before any Play Store submission.

The composite recipes (`just dev`, `just build`, `just test`, `just setup`,
`just fmt`, `just lint`, `just check`) chain backend/contract steps that
don't exist for this project — always call the `-frontend`-suffixed
recipes directly with `project=aod_clock`.

## Known gaps

- **The core screen-off → AOD-overlay flow is now verified working**, but
  only on a local Android 15 emulator (`Pixel_8_Pro_API_35`), not the
  user's actual Samsung device. Confirmed via `adb`/`dumpsys` (not just
  visual): after granting "Show notifications", pressing the power key
  produces `mWakefulness=Awake` with `AodOverlayActivity` as the resumed,
  focused, screen-holding activity, and a screenshot of the real
  clock/date over pure black. Tap-to-dismiss confirmed returning focus to
  the prior activity. Two real device-found bugs preceded this fix (bare
  `startActivity()` from the background, then wrongly assuming
  `USE_FULL_SCREEN_INTENT` needed a grant flow when `POST_NOTIFICATIONS`
  was the actual missing piece) — see the 2026-08-24 (3) changelog entry
  for the full debugging trail.
- **The foreground service does not restart itself after being killed
  unless the toggle is re-flipped or the device actually reboots
  (`BootReceiver`).** Found while testing: after `adb install -r` (or
  presumably `am force-stop`), `AodForegroundService` was gone even though
  the persisted "AOD enabled" setting still read `true` and the toggle
  still showed on in the UI — reopening the app alone doesn't restart it.
  Not the bug the user originally hit, but a real gap if the service ever
  gets killed by the OS mid-session for an unrelated reason (low memory,
  etc.) — nothing currently notices and restarts it short of the user
  manually toggling AOD off and on again.
- **Still genuinely unverified**: this exact flow on a real Samsung
  device, notification-listener metadata from a real playing app, survival
  across an actual reboot, Samsung's own OEM battery/auto-start management
  (a real, separate risk the in-app tiles can advise on but can't force),
  and the disclosed battery-cost tradeoff.
- **Even with the full-screen-intent permission granted, Samsung's own OEM
  battery/auto-start management is a separate, unverified risk** — it can
  kill the foreground service independently of anything Android's stock
  permission model controls. The in-app battery-optimization-exemption
  tile and the manual Samsung auto-start instructions exist but haven't
  been confirmed to actually prevent this in practice.
- **Low refresh-rate hinting is implemented but unverified on real
  hardware** (2026-08-24, see Native architecture above) — no LTPO-panel
  device or emulator available to confirm `setRequestedFrameRate` is
  actually honored; the user's S22 Ultra is the first real test of it.
- Onboarding is a single static-text screen, not a per-permission wizard —
  intentionally minimal for v1; the settings screen's permission tiles are
  the real fix-it surface, onboarding just explains the tradeoff once.

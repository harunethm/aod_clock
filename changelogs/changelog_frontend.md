# aod_clock — frontend changelog

Newest first. Build numbers are tracked in `versions.md`. There is no
backend for this project (see `frontend/aod_clock/CLAUDE.md`), so there's
no `changelog_backend.md`.

## 2026-08-24 (7) — refresh-rate management + live position ticking

User (an S22 Ultra owner, an LTPO-capable panel) asked whether the display
refresh rate could be managed, and separately wanted the music player's
elapsed-time to actually count up.

- **Pixel-shift is now an instant jump, not an animated transition.**
  `PixelShiftWrapper` used an `AnimatedContainer` with an 800ms transition
  every 60s — harmless-looking, but that's ~48 frames of animation forcing
  the panel out of any low-power idle refresh state for a shift that's
  supposed to be imperceptible anyway. Switched to a plain
  `Transform.translate` (instant).
- **`AodOverlayActivity` requests the panel's lowest refresh rate** via
  `View.setRequestedFrameRate(REQUESTED_FRAME_RATE_CATEGORY_LOW)` on the
  decor view. This is an API 35+-only hint (`View.setRequestedFrameRate`,
  Android 15) — the older mechanism, `Surface.setFrameRate`, needs direct
  access to the rendering `Surface`, which Flutter doesn't expose to app
  code, so this is the only frame-rate lever actually reachable here.
  Genuinely a no-op below API 35, and even above it only does anything on
  LTPO-capable panels (S22 Ultra+, S23/24/25, Note20 Ultra) — a
  fixed-refresh panel just ignores the hint.
- **Music position now ticks every real second while playing**, not just
  on real `MediaController` events (play/pause/seek/track change, which
  don't fire on a timer). `_ProgressBar` became a `StatefulWidget` with a
  local 1-second `Timer` that interpolates from the last known
  `(positionMs, wall-clock-time)` pair — client-side, no extra native
  calls or platform-channel traffic. This is *why* the frame-rate hint
  matters in practice: without it, this same per-second redraw would just
  run at whatever the panel's default refresh rate is; with it, an LTPO
  panel can service that redraw at closer to 1Hz instead.
- Verified: instant-jump pixel shift compiles/runs clean; the API 35
  symbols (`Build.VERSION_CODES.VANILLA_ICE_CREAM`,
  `View.REQUESTED_FRAME_RATE_CATEGORY_LOW`) compile against this project's
  SDK; position ticking confirmed advancing in real time on the emulator
  (1:24 → 1:48 over ~24s of wall-clock time) using the mock preview track,
  since there's no way to simulate a real MediaSession on the emulator.
  The frame-rate hint itself is unverified — no LTPO-panel device or
  emulator available to confirm it's actually honored; the user's S22
  Ultra is the first real test of it.
- `flutter analyze`/`flutter test` (13 tests) clean.
- Build bumped to 1.0.5+8, release notes attached.

## 2026-08-24 (6) — real-device bugs: player overflow, clock wrap, missing art

User tested with real music playing and hit two real bugs the emulator
(a wide Pixel 8 Pro) had masked, plus reported album art never loading.

- **Player overflowed on portrait.** `MiniMusicPlayer`'s info column was a
  fixed `SizedBox(width: 230)` — art (130) + gap (18) + 230 = 378px total,
  which fit the wide emulator's ~448dp portrait width fine but exceeds a
  common ~360dp-wide phone's available width (screen width minus the
  28px×2 padding). Fixed by wrapping it in `Flexible` +
  `ConstrainedBox(maxWidth: 230)` instead of a fixed `SizedBox` — 230 stays
  the *maximum* on wide screens, but it now actually shrinks (with the
  title/artist text ellipsizing) on narrow ones instead of overflowing.
- **Verifying that fix exposed a second, worse bug**: the clock itself
  wrapped mid-digit ("13:39" → "13:3" / "9" on two lines) at a simulated
  360dp width — a plain `Text` at a fixed `fontSize: 140` has no notion of
  the screen it's actually rendering on. Fixed with `FittedBox(fit:
  BoxFit.scaleDown)` around the clock text — it now scales the whole clock
  down as one block on narrow screens instead of wrapping, and still shows
  at full intended size on wide ones. Verified by temporarily resizing the
  emulator itself (`adb shell wm size 1080x2400` + `wm density 480`, a
  clean way to test other screen widths without switching AVDs) rather
  than guessing a font size would work everywhere.
- **Album art wasn't loading at all for real playback.** The original
  implementation only checked `METADATA_KEY_ALBUM_ART`/`METADATA_KEY_ART`
  for an embedded `Bitmap`. Many real apps — Spotify, YouTube Music among
  them — never embed a bitmap there at all, only a `content://` URI
  (`METADATA_KEY_ALBUM_ART_URI` etc.), specifically to avoid Binder
  transaction size limits on large images. Fixed: falls back to resolving
  the URI via `ContentResolver.openInputStream` when no embedded bitmap is
  present, decoded off the main thread (a background `Thread`, result
  marshaled back via `Handler(Looper.getMainLooper())` since
  `MediaController.Callback` runs on the registering thread — main, here —
  and disk/IPC I/O has no business blocking it). Publishes track
  title/artist/progress immediately without waiting for art, then
  republishes once the art resolves, so there's no added delay before text
  shows up.
- Both Flutter fixes verified visually (not just "should work now"
  reasoning) by temporarily resizing the running emulator to a narrower
  common width and screenshotting before/after.
- Build bumped to 1.0.4+7, release notes attached.

## 2026-08-24 (5) — design-review pass: fonts, mock-data bug, sizing, layout

User compared the (4) build directly against the reference design and
found several real gaps beyond what was guessed at:

- **Fonts looked wrong on the real device.** Root cause: `google_fonts`
  fetches font files over the network on first use and caches them —
  unreliable for a screen rendered from a lockscreen-launched engine with
  unpredictable network state. Fixed by downloading the actual Outfit
  ExtraLight + Geist (Regular/Medium/SemiBold) `.ttf` files and bundling
  them as local assets (`assets/fonts/`, declared in `pubspec.yaml`'s
  `fonts:` section) instead — `google_fonts` dependency removed entirely.
- **Mock preview data was overriding real data, not falling back to it.**
  The previous implementation used a nested `ProviderScope` override that
  unconditionally replaced `nowPlayingTrackProvider`/
  `notificationCountProvider` with the mock stream whenever
  `isPreview: true` — so opening Preview while real music was actually
  playing showed the fake "Midnight City" track instead. Fixed:
  `MiniMusicPlayer`/`NotificationCountBadge` now take a plain `isPreview`
  bool and use mock data only when the real value is null/zero — real data
  always wins.
- **Sizing was measured, not guessed, this time.** Comparing pixel
  proportions against the reference design directly: clock font was
  roughly half the proportion it should have been (80 → 140), album art
  was missing entirely (no asset exists for the real "Midnight City"
  artwork — added an honest neutral placeholder, a dark rounded square
  with a music-note icon, rather than silently leaving empty space), and
  the play button was a bare outline instead of the reference's filled
  dark circle with a white ring.
- **Landscape layout wasn't actually split into two halves** — the
  previous `Row` with `spaceBetween` pinned both blocks to the outer edges
  with a large empty gap. Rebuilt as two `Expanded` + `Center` halves, so
  each block centers within its own half of the screen.
- **Notification count moved to sit inline with the date** (was floating
  separately above the player) via a shared `_DateRow` widget reused by
  both orientations.
- **Date now left-aligns to the clock's own left edge** instead of being
  centered independently under it — nested the clock+date pair in their
  own `Column(crossAxisAlignment: start)`, with that whole block still
  centered as a unit within its parent.
- Every change in this entry was verified visually on the Android 15
  emulator (not just compiled) — screenshots taken in both orientations
  after each fix, checked for overflow, and sent to the user for direct
  comparison against their reference before shipping.
- Build bumped to 1.0.3+6, release notes attached.

## 2026-08-24 (4) — UI overhaul: orientation-responsive layout, redesigned player, new fonts

- Layout now follows `MediaQuery`'s orientation live: portrait stacks
  clock/date/notification-count/player centered vertically, landscape
  splits clock/date left and notification-count/player right — rebuilds on
  rotation, not fixed to whichever orientation the app launched in.
- New notification counter (`NotificationCountBadge`): count of other
  apps' active notifications, sourced from the same
  `MediaNotificationListenerService`/"Notification access" permission
  already needed for now-playing (`NotificationCountBridge.kt`, new
  `com.scylla.tool.aodclock/notification_count/events` EventChannel) — no
  separate permission grant needed. Renders nothing at zero.
- `MiniMusicPlayer` fully redesigned to match a reference mockup: bigger
  album art (84dp, was 48dp), bold title + gray artist, a real progress
  bar (thin track + filled portion + dot thumb) with elapsed/total m:ss
  labels, and previous/play-pause/next controls with the play button in a
  bordered circle. Was a small vertical stack before.
- Fonts: clock uses Outfit ExtraLight (Google Fonts) at a much larger size
  (80, was 52) to read as a real clock face; everything else (date, player
  text, notification count) uses Geist. New `google_fonts: ^8.2.0`
  dependency (already used by infera, just new to this project).
- Immersive fullscreen on the real AOD overlay: status bar and nav bar
  hidden (`WindowInsetsControllerCompat`, swipe-revealable), matching a
  real AOD panel having no status bar. Only applies to `AodOverlayActivity`
  (the real screen-off-triggered instance) — the Preview button runs
  inside `MainActivity` and intentionally still shows the status bar there.
- Mock preview data: the Settings screen's Preview button now shows a
  fake "Midnight City" / M83 track and a notification count of 3 instead
  of nothing, via a nested `ProviderScope` override
  (`nowPlayingTrackProvider`/`notificationCountProvider`) scoped to
  `AodDisplayScreen(isPreview: true)` — real screen-off-triggered launches
  are unaffected and still show real data (or nothing, if nothing's
  active).
- Real bug found and fixed along the way: the brightness slider in
  Settings only ever wrote to Flutter's own storage — `AodPrefs` (the
  native SharedPreferences `AodOverlayActivity` actually reads for
  `screenBrightness`) never received the value, so AOD always rendered at
  its hardcoded 0.12 default no matter what the slider showed. Found by
  the user noticing AOD stayed dim. Fixed with a new
  `setBrightnessLevel` platform-channel method, called both on slider
  change and once on every settings load (so a value persisted before this
  fix also gets corrected without the user re-touching the slider).
- Verified end-to-end on the Android 15 emulator, not just compiled: both
  orientations screenshotted after actually rotating the device, a real
  screen-off trigger (`adb shell input keyevent KEYCODE_POWER`) confirmed
  launching `AodOverlayActivity` with the status bar genuinely hidden, and
  the notification counter confirmed live-updating against real posted
  test notifications (`adb shell cmd notification post`).
- `flutter analyze`/`flutter test` (13 tests) clean.

## 2026-08-24 (3) — the actual fix, verified on-device this time: POST_NOTIFICATIONS

- User, reasonably done with a third round of unverified guessing, offered
  a simulator. Booted a local Android 15 (API 35) AVD (`Pixel_8_Pro_API_35`,
  already present via Android Studio), installed the (2) build, and
  reproduced the exact symptom: power button → `mWakefulness=Asleep` →
  nothing. `adb shell cmd appops get com.scylla.tool.aodclock
  POST_NOTIFICATION` read **`ignore`**. The (2) full-screen-intent fix and
  its permission tile were real and necessary, but not sufficient — Android
  13+ (API 33) requires a separate, *runtime-granted* `POST_NOTIFICATIONS`
  permission for **any** notification to post at all, including the
  full-screen-intent trigger notification. It was never declared in the
  manifest or requested. No crash, no log — every notification the app
  tried to post was silently dropped at the OS level.
- Also corrected an earlier wrong claim in this changelog/CLAUDE.md: (2)'s
  entry said Android 14 auto-denies `USE_FULL_SCREEN_INTENT` to non-alarm
  apps by default. Testing on the emulator disproved that — a fresh install
  showed it already granted (`canUseFullScreenIntent()` true immediately).
  It's a normal permission, auto-granted at install; Android 14 only added
  the ability for the *user* to revoke it afterward. The tile still earns
  its place for that reason, just not the reason originally written.
- Fix: `POST_NOTIFICATIONS` added to the manifest, a real runtime
  permission request wired up (`ActivityCompat.requestPermissions`,
  androidx.core — resolved transitively via the Flutter embedding, no new
  Gradle dependency needed), and a new "Show notifications" tile in
  Settings, listed first — this is the one that actually gates everything.
- **Verified the fix itself, not just that it compiles**: granted the
  permission via the in-app flow on the emulator, confirmed
  `dumpsys package` showed `granted=true`, pressed the power key again, and
  this time `dumpsys activity activities` showed `AodOverlayActivity`
  actually resumed and focused, `mWakefulness=Awake` (screen back on),
  `mHoldScreenWindow` pointing at it — and a screenshot showing the real
  clock/date over pure black. Tap-to-dismiss also confirmed working
  (returns focus to the prior activity/lockscreen).
- Along the way, found (but did not fully fix) a related gap: after a
  `force-stop`/reinstall, the `AodForegroundService` doesn't restart on its
  own even though the persisted "enabled" setting still shows on — only
  re-flipping the toggle, or a real device boot (`BootReceiver`), restarts
  it. Not the bug the user hit (their device wasn't being reinstalled
  between attempts), but worth knowing if AOD ever "stops working after a
  while" for a different reason. Tracked in Known gaps.
- Build number bumped to 1.0.0+3, release notes attached.

## 2026-08-24 (2) — real root cause: Android 14+ full-screen-intent permission

- The full-screen-intent fix from earlier today (2026-08-24 (1) below)
  turned out to be necessary but not sufficient. Real device test: still
  no overlay on power-button/screen-timeout after that fix shipped.
  Root cause: Android 14+ (API 34+) no longer auto-grants
  `USE_FULL_SCREEN_INTENT` to regular apps — only phone/alarm-category apps
  get it by default. Declaring the permission in the manifest isn't enough;
  the notification posts but the full-screen launch is silently suppressed.
  This device's Android SDK is 36 (measured via `flutter doctor -v`), well
  past the threshold — confirms this was almost certainly it.
- Added a real permission check (`NotificationManager.canUseFullScreenIntent()`,
  API 34+, treated as always-granted below that) and a grant flow deep-linking
  to `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`. New "Full-screen
  launch" tile in Settings, listed first — it's the one to check if AOD
  isn't triggering.
- New "Check all permissions" button at the bottom of Settings —
  re-validates all three permission checks (full-screen launch, notification
  access, battery-optimization exemption) in one tap instead of expanding
  each tile, with a summary snackbar.
- Build number bumped to 1.0.0+2 and release notes attached to the
  Firebase App Distribution upload — the previous two releases both
  uploaded as indistinguishable "1.0.0 (1)" with no notes (user feedback,
  now standard practice going forward).
- Fixed the `distribute-android` justfile recipe: `--release-notes=...`
  wasn't quoted, so any notes string containing spaces or parentheses broke
  the shell command (`sh: -c: line 0: syntax error near unexpected token`).
- `flutter analyze`/`flutter test` (13 tests) clean.

## 2026-08-24 (1) — project scaffolded, Firebase App Distribution wired, background-launch bug fixed

- New project: `frontend/aod_clock/`, a software approximation of Samsung's
  Always-On-Display — full-screen black clock/date/mini-music-player shown
  instead of letting the screen turn off. Deliberate deviation from ADR
  0007 (no `backend/`/`contracts/`, pure on-device app) — amendment ADR
  still owed once this project is further along.
- Feature-first Flutter app (Riverpod, go_router, no `freezed`, matching
  catan-game/infera conventions) — `aod_display`, `now_playing`,
  `settings`, `onboarding` features. Plain `Provider`/`AsyncNotifier`
  throughout, not `@riverpod` codegen — no build_runner step needed to run.
- Native Android: `AodForegroundService` (screen-off watcher, foreground
  service type `specialUse`), `AodOverlayActivity` (show-when-locked, no
  `SYSTEM_ALERT_WINDOW`/`DISABLE_KEYGUARD`), `MediaNotificationListenerService`
  (mirrors the system's active `MediaController` — Spotify/YT Music/etc —
  over an EventChannel), `BootReceiver`. Platform-channel contract
  documented in `frontend/aod_clock/CLAUDE.md` (no OpenAPI contract exists
  for this project, so that file is the source of truth instead).
- **Bug found on first real-device test**: pressing the power button with
  AOD enabled just locked the phone normally — no overlay. Root cause: the
  screen-off receiver launched `AodOverlayActivity` with a bare
  `context.startActivity()`, which Android 10+'s background-activity-launch
  restrictions silently block when called from a `BroadcastReceiver`
  running inside a background service (no crash, no log noise — it just
  does nothing). Fixed by switching to a full-screen-intent notification
  (`Notification.Builder.setFullScreenIntent(pendingIntent, true)` on a
  high-importance channel) — the Android-sanctioned mechanism incoming-call
  and alarm apps use to draw over a locked screen. Needs
  `USE_FULL_SCREEN_INTENT` in the manifest (added). Not yet
  device-re-verified — see Known gaps below and in the project's CLAUDE.md.
- Added a "Preview AOD screen" button to Settings (`context.push('/aod')`)
  so the screen can be seen on demand instead of only via a real
  screen-off. `AodDisplayScreen`'s tap-to-dismiss now branches on
  `Navigator.canPop()` — pops back to Settings in preview mode, calls the
  native `dismissAodOverlay()` channel method when it's the real
  lockscreen-launched instance (finishing the wrong Activity would have
  been a bug in the preview path).
- Firebase App Distribution wired up: new dedicated Firebase project
  `aod-clock-app` (not shared with catan-game's project), Android app
  registered (package `com.scylla.tool.aodclock`), CLI-only distribution
  (no `firebase_core`/`google-services.json`/Gradle plugin — the SDK isn't
  embedded in the app at all). New generic `distribute-android` justfile
  recipe (`FIREBASE_APP_ID=... just project=aod_clock distribute-android`).
- 13 unit tests (clock formatting, pixel-shift offset math, settings
  persistence round-trip, now-playing event parsing), `flutter analyze`
  clean, debug and release APKs both build clean.

### Known gaps

- **Still not verified on a real device that the fix works** — the
  background-activity-launch bug was found via a live device test, but the
  full-screen-intent fix hasn't been re-tested on-device yet at the time of
  this entry (redistribution is the next step). Also unverified: Samsung's
  own OEM battery/auto-start management could independently kill the
  foreground service regardless of this fix — the in-app permission tiles
  (battery-optimization exemption, manual Samsung auto-start instructions)
  exist but haven't been confirmed to actually prevent that in practice.
- `USE_FULL_SCREEN_INTENT` can in principle be revoked by the user on
  Android 14+ via Settings — no in-app check/re-request flow for that yet.
- Low-refresh-rate hinting (`Window.setFrameRate`) still unimplemented
  (LTPO-panel-only, deferred without a device to verify against).
- Release build still falls back to debug signing (no upload keystore) —
  fine for App Distribution testing, not for a Play Store submission.

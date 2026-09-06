# aod_clock — deployed versions

Last updated: 2026-08-24.

No backend — this project has no `crates/edge`/D1/Worker, see
`frontend/aod_clock/CLAUDE.md` for why.

## Frontend (Flutter)

| | |
|---|---|
| App version | 1.0.5+8 (`pubspec.yaml`) |
| Flutter | 3.44.8 (stable, via fvm — pinned in `frontend/aod_clock/.fvmrc`) |
| Dart | 3.12.2 |
| flutter_riverpod | ^3.3.2 |
| go_router | ^17.3.0 |
| flutter_secure_storage | ^10.3.1 |
| Fonts | Outfit ExtraLight (clock) + Geist (everything else), bundled `.ttf` assets — not `google_fonts` (removed; runtime-fetch is unreliable for a lockscreen-launched engine) |
| Android build | debug-signed release APK (no upload keystore yet) |

## Firebase App Distribution

| | |
|---|---|
| Firebase project | `aod-clock-app` |
| Android App ID | `1:141342333212:android:52d691a911ca2f2ea382d9` |
| Package | `com.scylla.tool.aodclock` |
| Testers | [tester-email] |
| Latest release | `2vc13r1q8i768`, 2026-08-24 — 1.0.5 (8): pixel-shift is an instant jump (was an 800ms animation forcing ~48 needless frames every 60s), AOD screen requests the panel's lowest refresh rate on API 35+ LTPO panels, music position now ticks every second while playing (client-side interpolation) |
| Release console link | https://console.firebase.google.com/project/aod-clock-app/appdistribution/app/android:com.scylla.tool.aodclock/releases/2vc13r1q8i768 |

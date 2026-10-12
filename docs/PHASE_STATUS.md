# Phase status

Legend: ✅ done and tested here · 🟡 built, needs a Mac/iPhone or hardware to
verify · ⛔ blocked on information · ⬜ not started.

Checks run for this report (Linux build machine, Flutter 3.47.7 / Dart
3.13.5, Node 22):

* `flutter analyze` – no issues
* `flutter test` – 71 tests pass (parsers, sessions, transports, AI client,
  full-UI widget flows)
* `npm test` in `backend/ai_proxy` – 16 tests pass
* `flutter build web --dart-define=PREVIEW=true` – builds; screenshots in
  `docs/screenshots/` were captured from that build in Chromium at iPhone size
* **Not run here:** `flutter build ios` / running on an iPhone (needs macOS +
  Xcode), anything involving a real IQ or vehicle.

| Phase | Status | What actually works | Needs hardware / Mac |
|---|---|---|---|
| 1. Environment, assumptions, project | ✅ | Flutter project (iOS first; Android + web structure), deps, analysis | Xcode signing on your Mac |
| 2. Branded UI with mock scanner | ✅ | All screens, simulated scanner, 5 scenarios | Visual check on a real iPhone |
| 3. Transport abstraction + BLE discovery | 🟡 | Transport interface; BLE discovery/connection code; tested against a fake radio | Real BLE scan on iPhone |
| 4. Scanner communication + OBD parsing | ✅ / 🟡 | ELM327 session, queue, timeouts, retries, CAN 11/29, ISO-TP, legacy, multi-ECU, error states, all unit-tested with synthetic fixtures | Real ELM327 responses from the IQ |
| 5. Tests + diagnostic logs | ✅ | Unit, integration (simulated) and widget tests; redacted log; developer screen; milestone runner | Recorded fixtures from the IQ |
| 6. IQ integration | ⛔ | IQ adapter placeholder with safety gates | **Protocol/GATT details of the IQ** – see HARDWARE_INVESTIGATION.md |
| 7. Garage, history, reports | ✅ | Vehicle profiles, VIN read/mask, saved reports, share sheet text report | Share sheet on device |
| 8. AI mechanic + secure backend | ✅ / 🟡 | Proxy with schema-constrained answers, VIN scrubbing, rate limits; app client + UI | An Anthropic API key and a deployed HTTPS proxy |
| 9. Performance, permissions, privacy, release | 🟡 | Info.plist purpose strings, Android permissions, portrait lock, export-compliance flag, privacy design | See release checklist below |

## Milestone 1 – real scanner connectivity

**Not passed.** The nine-step pipeline passes end to end against the simulated
scanner (`test/obd/session_integration_test.dart` and the in-app runner).
It has not run against an IQ. The in-app runner reports "Milestone NOT passed"
until it runs against real hardware.

## Release checklist (Phase 9)

- [ ] Add `PrivacyInfo.xcprivacy` to the Runner target in Xcode (required
      reason APIs: file timestamp / UserDefaults are declared by Flutter
      plugins; declare app-level data use: "Other diagnostic data" sent to the
      AI proxy, not linked to identity, not used for tracking)
- [ ] App Store privacy "nutrition label" matching the above
- [ ] Replace placeholder icon and hero illustration with official artwork
- [ ] Apple App Attest (or accounts) on the AI proxy before public launch
- [ ] Deploy proxy over HTTPS; set `AI_PROXY_URL` in release builds
- [ ] Test Bluetooth permission denial / Bluetooth off / airplane mode flows
- [ ] Test on the oldest supported iPhone (iOS 15) and with large text sizes
- [ ] Battery/heat check: 20 minutes of live polling at 1 s on device
- [ ] Legal review of AI and guidance wording (Australian Consumer Law)
- [ ] Optional: `bluetooth-central` background mode only if a background
      feature is added (currently not requested, so not declared)

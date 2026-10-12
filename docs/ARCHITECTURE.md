# Architecture

```
┌──────────────────────────── presentation/ ─────────────────────────────┐
│ onboarding · connect · dashboard · faults · ai · garage · report ·     │
│ developer · widgets (gauges, cards, brand)                             │
└───────────────▲───────────────────────────▲────────────────────────────┘
                │ ChangeNotifier (provider) │
┌───────────────┴──────────┐  ┌─────────────┴─────────────┐  ┌───────────┐
│ device/                  │  │ obd/live_data_controller  │  │ ai/       │
│  DeviceDiscovery (scan)  │  │ dtc/fault_scan_controller │  │  client → │──► backend/ai_proxy ──► Claude API
│  ConnectionController    │  │ history/report_builder    │  │  proxy    │
│  MilestoneRunner         │  └─────────────┬─────────────┘  └───────────┘
└───────────────┬──────────┘                │
                │                 ┌─────────┴─────────┐
                │                 │ obd/              │
                └────────────────►│  Elm327Session    │  identify → init → PIDs → reads
                                  │  ElmChannel       │  queue · timeouts · retries · resync
                                  │  CommandPolicy    │  read-only allow-list
                                  │  parsing/         │  framer · ElmReply · FrameParser · PIDs
                                  └─────────┬─────────┘
                                            │ bytes
┌───────────────────────────── transport/ ─┴──────────────────────────────┐
│ ObdTransport ── SimulatedTransport (SimulatedElm327 + SimulatedVehicle) │
│              ├─ BleElmTransport (documented GATT profiles only)         │
│              ├─ WifiElmTransport (TCP)                                  │
│              └─ iq/IqAdapterSpec (unverified placeholder)               │
└──────────────────────────────────────────────────────────────────────────┘
storage/ (JSON document store) ← vehicle/, history/, core/settings/
core/telemetry/ (redacted DiagnosticLog, Telemetry sink) · core/errors/ (typed exceptions)
```

## Module map (requested → code)

| # | Module | Code |
|---|---|---|
| 1 | Presentation layer | `lib/presentation/` |
| 2 | Device discovery and connection | `lib/device/` |
| 3 | Hardware transport | `lib/transport/` |
| 4 | OBD command execution | `lib/obd/commands/`, `lib/obd/elm327_session.dart` |
| 5 | OBD response parsing | `lib/obd/parsing/`, `lib/obd/pids.dart` |
| 6 | Vehicle models | `lib/vehicle/` |
| 7 | Fault code decoding | `lib/dtc/` |
| 8 | Diagnostic history | `lib/history/`, `lib/storage/` |
| 9 | AI diagnostic service | `lib/ai/`, `backend/ai_proxy/` |
| 10 | Error handling and telemetry | `lib/core/errors/`, `lib/core/telemetry/` |

## Key decisions

* **BLE library: `universal_ble` (BSD-3).** `flutter_blue_plus` now requires a
  paid commercial licence for for-profit organisations and sends build-time
  telemetry (its LICENSE, v1.6), so it was not used. `universal_ble` supports
  iOS, Android, macOS, Windows, Linux and web.
* **State management: `provider` + `ChangeNotifier`.** Small, stable and easy
  for a new team to follow.
* **Storage: JSON documents** in the app's private Documents directory with
  atomic writes. Every record has an `id` and `updatedAt`, so a cloud sync
  implementation of `DocumentStore` can be added later.
* **Headers on (`ATH1`)** so every response is attributed to the module that
  sent it (multi-ECU support and "source" on fault codes).
* **Simulator at byte level.** The demo scanner emits exactly what an ELM327
  prints, including echo, `SEARCHING...`, ISO-TP frames, padding, legacy
  checksums and 20-byte BLE-sized chunks. Demo mode therefore exercises the
  same parser as real hardware.
* **AI behind a proxy.** The app never holds an AI key. The proxy constrains
  answers to a JSON schema and strips VINs. "Confirmed data" in the UI is
  rendered by the app from the scan, not by the AI.

## Error handling

Typed failures (`TransportException`, `ObdException`, `AiException`,
`StorageException`) carry a plain-English `userMessage` for the UI and a
`detail` for the developer screen. ELM status lines (`NO DATA`,
`UNABLE TO CONNECT`, `BUS INIT: ...ERROR`, `CAN ERROR`, `STOPPED`, `?`, …) are
classified in `ElmReply`. Transient ones are retried once. Timeouts trigger a
resync so a late reply is never attributed to the next command.

## Privacy

* VINs are never logged (mode 09 responses are summarised) and never sent to
  the AI proxy. The proxy scrubs any VIN-like text as a second line of
  defence.
* Device identifiers are masked in logs and exports.
* No analytics leave the phone (`NoopTelemetrySink`). A crash-reporting sink
  can be added behind user consent.

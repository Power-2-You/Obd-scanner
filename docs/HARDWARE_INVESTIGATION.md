# Boost N' Inflate IQ – hardware investigation

Status: **NOT VERIFIED.** No IQ unit, manufacturer documentation or captured
traffic was available while building this app. Nothing in the codebase claims
that the app has connected to an IQ.

## What is known

| Fact | Source |
|---|---|
| The IQ contains an OBD diagnostic scanner. | My Garage Hero product description |
| The third-party iPhone app **Mini OBDII** shows diagnostic data from the IQ. | My Garage Hero |
| SwiftOBD2 (the library behind the SwiftOBD2App you referenced) talks to ELM327 adapters over three documented BLE GATT layouts and a Wi-Fi TCP endpoint. | `kkonteh97/SwiftOBD2`, `BLEConnection.swift`, `BLECharacteristicHandler.swift`, `wifiManager.swift` (MIT) |

## What is inferred (not verified)

* **Bluetooth Classic is unlikely on iPhone.** iOS only lets third-party apps
  use Bluetooth Classic serial accessories through Apple's MFi programme
  (External Accessory framework). Generic OBD apps like Mini OBDII therefore
  normally use **Bluetooth LE** or **Wi-Fi**. If the IQ appears in
  *Settings › Bluetooth* as a paired accessory, it may be MFi – tell me.
* **ELM327 compatibility is likely but unconfirmed.** Mini OBDII is an
  ELM327-oriented app, so the IQ's scanner probably speaks the ELM327 command
  set. A proprietary protocol is still possible.

## What the app does about it

1. **Discovery is passive.** Scanning only listens to advertisements.
2. **Connection is read-only until a documented profile matches.** After
   connecting, the app enumerates services (read-only). It only subscribes to
   notifications and writes to a characteristic if the device exposes one of
   these documented layouts:

   | Service | Notify | Write | Documented in |
   |---|---|---|---|
   | `FFF0` | `FFF1` | `FFF2` | SwiftOBD2 |
   | `FFE0` | `FFE1` | `FFE1` | SwiftOBD2 |
   | `18F0` | `2AF0` | `2AF1` | SwiftOBD2 (e.g. Vgate iCar Pro) |

   Anything else: disconnect, nothing written, GATT table saved for review.
3. **Identification gate.** On a matched profile the first and only command is
   `ATZ`. Unless the reply identifies an ELM327 or STN interpreter, nothing
   else is sent (`Elm327Session.identify`).
4. **Command allow-list.** Even after identification, only the read-only
   commands in `lib/obd/commands/command_policy.dart` can be sent. Clearing
   codes (mode 04), actuator tests (mode 08) and all UDS services (coding,
   security access/immobiliser, routines, flashing) are blocked at the lowest
   layer, so they cannot reach the IQ or the car.
5. **The IQ adapter is a placeholder.** `lib/transport/iq/iq_adapter.dart` has
   `verified = false` and empty identifiers. It refuses to be used until the
   checklist below is complete.

None of these steps touches the IQ's jump-start, inflation, lighting or
charging functions. The app never sends firmware commands.

## What I need from you (in order of usefulness)

1. **Any manufacturer documentation** for the IQ's diagnostic module: OBD chip
   (e.g. ELM327 clone, STN1110/2120, custom), Bluetooth module part number,
   protocol sheet, or FCC/RCM test reports (these often list the radio module).
2. **How Mini OBDII is set up for the IQ.** In Mini OBDII settings, which
   connection type is selected (Bluetooth 4.0/BLE, Wi-Fi, or other)? Any
   device name shown? Screenshot it.
3. **Does the IQ appear in iPhone Settings › Bluetooth or Settings › Wi-Fi**
   (e.g. a network called `WiFi_OBDII`, `V-LINK` or similar) when the scanner is
   powered?
4. **A hardware report from this app** (preferred), or an **nRF Connect**
   capture (free app by Nordic Semiconductor) if you can test before building:
   * Power on the IQ's scanner, connect it to a car, ignition ON.
   * Fully close Mini OBDII. A BLE scanner only accepts one connection.
   * **This app:** Developer diagnostics › Hardware › *Scan all nearby
     devices* › *Inspect* on the likely device › *Share hardware report*.
     Then Connect your IQ › tap the device. If it matches a documented
     profile, run Developer › Milestone › *Run milestone test* and share the
     report again.
   * **nRF Connect:** Scanner tab › find the device › note name, RSSI and
     advertised services › *Connect* › screenshot the full service and
     characteristic list (UUIDs + properties). Do **not** write to any
     characteristic.
5. **Product/model numbers** of the IQ and its diagnostic module.

## Verification checklist (to flip `IqAdapterSpec.verified`)

- [ ] Link type confirmed (BLE / Wi-Fi / other) from docs or capture
- [ ] Advertised name prefix recorded → `advertisedNamePrefixes`
- [ ] GATT layout recorded; matches a documented profile or a new profile is
      defined from manufacturer documentation → `bleProfile`
- [ ] `ATZ` banner recorded → `expectedBanner`
- [ ] Milestone runner passes all 9 steps against a real vehicle
- [ ] Decoded RPM matches the vehicle's tachometer (idle and ~2,000 rpm)
- [ ] Coolant temperature plausible against the vehicle gauge after warm-up
- [ ] Stored codes match those read by Mini OBDII on the same vehicle
- [ ] Recorded raw responses added to `test/fixtures/recorded/` as regression
      tests (VINs removed)
- [ ] IQ jump-start, inflation, light and charging functions re-tested after a
      diagnostic session and still work normally

## If the IQ turns out to be…

* **ELM327 over a documented BLE profile:** fill in the IQ spec and done. The
  generic transport already handles it.
* **ELM327 over a new BLE layout:** add a `BleSerialProfile` citing the
  manufacturer documentation (not a guess), then fill in the IQ spec.
* **Wi-Fi ELM327:** use *Connect your IQ › Wi-Fi scanner* with the documented
  IP/port. Add `NSLocalNetworkUsageDescription` testing on device.
* **Bluetooth Classic (MFi):** requires the manufacturer's MFi protocol string
  and Apple's External Accessory framework, a native iOS plugin and MFi
  approval. Not possible without the manufacturer.
* **Proprietary protocol:** requires the manufacturer's protocol
  specification. Implement it as a new `ObdTransport` + session in
  `lib/transport/iq/`. The UI, parsing of standard OBD data, storage and AI
  layers remain unchanged.

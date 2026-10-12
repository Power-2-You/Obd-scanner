# Boost N' Inflate IQ – hardware investigation

Status: **command protocol documented, radio link NOT VERIFIED.** The
supplier's protocol document (below) confirms the IQ's OBD module speaks the
ELM327 AT command set, which the app already implements. The app has still
not been connected to a real IQ, and the Bluetooth details needed to reach it
are not in the document.

## What is known

| Fact | Source |
|---|---|
| The IQ contains an OBD diagnostic scanner. | My Garage Hero product description |
| The third-party iPhone app **Mini OBDII** shows diagnostic data from the IQ. | My Garage Hero |
| SwiftOBD2 (the library behind the SwiftOBD2App you referenced) talks to ELM327 adapters over three documented BLE GATT layouts and a Wi-Fi TCP endpoint. | `kkonteh97/SwiftOBD2`, `BLEConnection.swift`, `BLECharacteristicHandler.swift`, `wifiManager.swift` (MIT) |
| The OBD module is **request/response over the ELM327 AT command set**: the app sends AT or OBD commands, the module answers. Every command this app sends (`ATZ`, `ATI`, `ATE0`, `ATL0`, `ATS0`, `ATH1`, `ATSP0`, `ATDP`, `ATDPN`, `ATRV`, modes 01/03/07/09) is in the supplier's list. | Supplier document §5–6 |
| It supports OBD-II protocols 1–9: SAE J1850 PWM/VPW, ISO 9141-2, ISO 14230-4 KWP (5-baud and fast init), ISO 15765-4 CAN 11/29-bit at 500/250 kbaud – the same numbering as `ATSP`/`ATDPN`, already handled by the parser. | Supplier document §4, product image |
| The module family (MCU + CAN / K-line / J1850 interface circuits) can output over **Bluetooth, Wi-Fi, RS232 or GPRS**. | Supplier document §2 block diagram |
| OBD modes 1–9 follow ISO 15031-5; mode 03 legacy frames carry three DTCs each. Matches the app's decoder. | Supplier document §6 |

The supplier document is *"OBD 产品通信协议"* (OBD product communication
protocol, 14 pages), received 12 Oct 2026. It is **not committed** to this
public repository; keep it in your own records.

### Notes on the supplier document

* **MAF formula typo:** PID `10` is listed as `(A*256)+B`, but the stated
  range (0–655.4 g/s) only works with the SAE J1979 formula
  `((A*256)+B)/100`. The app uses the standard formula.
* **Product image typo:** protocol 9 is printed as "251 Kbaud"; the standard
  (and the document's own §4) says 250 kbaud.
* The document also lists mode 04 (clear codes) and mode 08 (actuator
  control). The app still blocks both, as required.
* The document does **not** state the module's `ATI` version string. The app
  therefore accepts an unbranded module if it answers `ATI` and acknowledges
  `ATE0` with `OK` (behaviour defined by the documented command set), in
  addition to banners naming ELM327 / STN / OBDLink.

## What is inferred (not verified)

* **Bluetooth Classic is unlikely on iPhone.** iOS only lets third-party apps
  use Bluetooth Classic serial accessories through Apple's MFi programme
  (External Accessory framework). Generic OBD apps like Mini OBDII therefore
  normally use **Bluetooth LE** or **Wi-Fi**. If the IQ appears in
  *Settings › Bluetooth* as a paired accessory, it may be MFi – tell me.
* **Which radio the IQ uses.** The module family supports Bluetooth, Wi-Fi,
  RS232 and GPRS. Mini OBDII working on iPhone points to Bluetooth LE or
  Wi-Fi, but the IQ's actual fit is not stated.
* **The BLE GATT layout.** If the IQ uses Bluetooth LE, the app can only talk
  to it if it uses one of the documented serial layouts below (or a layout
  the supplier documents). Many ELM327-compatible BLE modules use `FFF0` or
  `FFE0`, but that is not confirmed for the IQ.

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

1. **Answers from the supplier** to the questions below (the protocol
   document covers the command layer but not the radio link).
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

## Questions for the supplier

Copy and send these. The Chinese version is for the supplier's engineers.

1. Which output link does the Boost N' Inflate IQ use: Bluetooth Low Energy
   (BLE 4.x/5.x), Bluetooth Classic (SPP), Wi-Fi, or another?
2. If BLE: the advertised device name, the GATT service UUID, the notify
   characteristic UUID and the write characteristic UUID (and whether writes
   are "with response" or "without response").
3. If Wi-Fi: the network name (SSID), the IP address and the TCP port.
4. The exact text the module returns for `ATZ` and `ATI`.
5. The Bluetooth module part number and the main MCU / OBD chip.
6. Is any pairing PIN or password required?

**中文：**

1. Boost N' Inflate IQ 使用哪种对外通信方式：低功耗蓝牙（BLE 4.x/5.x）、
   经典蓝牙（SPP）、WiFi，还是其他方式？
2. 如果是 BLE：请提供广播的设备名称、GATT 服务 UUID、通知（Notify）特征值
   UUID、写入（Write）特征值 UUID，以及写入方式是"有响应"还是"无响应"。
3. 如果是 WiFi：请提供 WiFi 名称（SSID）、IP 地址和 TCP 端口号。
4. 模块对 `ATZ` 和 `ATI` 命令返回的完整字符串是什么？
5. 蓝牙模块型号，以及主控 MCU / OBD 芯片型号。
6. 连接时是否需要配对码或密码？

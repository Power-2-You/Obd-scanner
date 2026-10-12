import '../../core/errors/app_exception.dart';
import '../ble/ble_gateway.dart';
import '../ble/ble_profiles.dart';

/// Integration point for the Boost N' Inflate IQ.
///
/// STATUS: NOT VERIFIED on hardware.
///
/// Documented (supplier document "OBD 产品通信协议", received 12 Oct 2026,
/// kept out of this public repository):
///  * The OBD module is request/response and speaks the ELM327 AT command
///    set – every command this app sends is in the supplier's list.
///  * It supports OBD-II protocols 1–9 (J1850 PWM/VPW, ISO 9141-2,
///    ISO 14230-4 KWP, ISO 15765-4 CAN 11/29-bit at 250/500 kbaud).
///  * The module family can output over Bluetooth, Wi-Fi, RS232 or GPRS.
///
/// Still unknown: which radio the IQ actually fits, its advertised name,
/// its BLE service/characteristic UUIDs and its ATI version string. The
/// third-party "Mini OBDII" iPhone app reads it, which points to BLE or
/// Wi-Fi (iOS blocks Bluetooth Classic serial without MFi) – an inference,
/// not a verified fact.
///
/// Until the fields below are filled in from real captures (see
/// docs/HARDWARE_INVESTIGATION.md), the IQ is treated like any other unknown
/// device: it is only inspected read-only, and will only be talked to if it
/// exposes one of the documented ELM327 BLE profiles AND identifies itself as
/// (or, for an unbranded banner, behaves as) an ELM327-compatible interpreter.
class IqAdapterSpec {
  const IqAdapterSpec._();

  /// Flip to true only after the checklist in HARDWARE_INVESTIGATION.md has
  /// been completed on real hardware.
  static const bool verified = false;

  /// Command layer, from the supplier document. Already implemented by
  /// Elm327Session; unbranded version strings are accepted by behaviour.
  static const String commandSet = 'ELM327 AT command set (supplier document)';

  /// Output links the supplier's module family offers. Which one the IQ
  /// uses is unverified.
  static const List<String> documentedLinks = [
    'Bluetooth',
    'Wi-Fi',
    'RS232',
    'GPRS',
  ];

  /// Advertised BLE name prefixes of the IQ diagnostic module, e.g. 'IQ-'.
  /// UNKNOWN – capture with the developer screen's scanner list.
  static const List<String> advertisedNamePrefixes = [];

  /// Transport the IQ uses: 'ble' or 'wifi'. UNKNOWN.
  static const String? link = null;

  /// The IQ's GATT serial layout if it uses BLE. UNKNOWN.
  /// If the capture shows it matches a profile in [BleProfiles.documented],
  /// reference that profile here instead of defining a new one.
  static const BleSerialProfile? bleProfile = null;

  /// Expected ATZ/ATI banner, e.g. 'ELM327 v1.5'. UNKNOWN.
  static const String? expectedBanner = null;

  /// Returns true when [hit] is positively identified as an IQ.
  /// Always false until the spec is verified – the app never guesses.
  static bool isIq(BleScanHit hit) {
    if (!verified || advertisedNamePrefixes.isEmpty) return false;
    final name = hit.name ?? '';
    return advertisedNamePrefixes.any(name.startsWith);
  }

  /// Guard used by any IQ-specific code path.
  static void requireVerified() {
    if (!verified) {
      throw const TransportException(
        TransportFailure.notVerified,
        'The Boost N\' Inflate IQ connection details have not been verified '
        'yet. Use the Developer screen to capture its Bluetooth details.',
      );
    }
  }
}

/// Display hint only. Never used to decide whether to send data.
class ScannerNameHints {
  const ScannerNameHints._();

  static const List<String> _obdLike = [
    'OBD',
    'ELM',
    'IQ',
    'VLINK',
    'V-LINK',
    'ICAR',
    'VGATE',
    'VEEPEAK',
    'KONNWEI',
    'OBDLINK',
    'CAR',
    'SCAN',
  ];

  static bool looksLikeScanner(String? name) {
    if (name == null || name.isEmpty) return false;
    final upper = name.toUpperCase();
    return _obdLike.any(upper.contains);
  }
}

import '../../core/errors/app_exception.dart';
import '../ble/ble_gateway.dart';
import '../ble/ble_profiles.dart';

/// Integration point for the Boost N' Inflate IQ.
///
/// STATUS: NOT VERIFIED.
///
/// No manufacturer documentation for the IQ's diagnostic radio has been
/// supplied, and the app has not yet been run against an IQ unit. The only
/// known fact is that the third-party "Mini OBDII" iPhone app can read data
/// from it. On iPhone that rules out Bluetooth Classic SPP for third-party
/// apps without MFi certification, which leaves BLE or Wi-Fi as the likely
/// links – but that is an inference, not a verified fact.
///
/// Until the fields below are filled in from real captures (see
/// docs/HARDWARE_INVESTIGATION.md), the IQ is treated like any other unknown
/// device: it is only inspected read-only, and will only be talked to if it
/// exposes one of the documented ELM327 BLE profiles AND identifies itself as
/// ELM327/STN in reply to ATZ.
class IqAdapterSpec {
  const IqAdapterSpec._();

  /// Flip to true only after the checklist in HARDWARE_INVESTIGATION.md has
  /// been completed on real hardware.
  static const bool verified = false;

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

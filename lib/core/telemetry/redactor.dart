/// Privacy redaction applied to every diagnostic log line before it is stored
/// or exported.
///
/// What counts as personal data here:
///  * Vehicle Identification Numbers (VINs) – they identify a specific car and,
///    through registration records, its owner.
///  * Hardware addresses of the user's phone or scanner (Android MAC addresses).
///
/// Service/characteristic UUIDs are protocol constants, not personal data, and
/// are intentionally left visible because they are needed for hardware
/// verification.
class Redactor {
  const Redactor._();

  /// 17 characters from the VIN alphabet (no I, O, Q) that contain at least
  /// one non-hex letter. Requiring a non-hex letter stops raw OBD hex frames
  /// (which only contain 0-9 and A-F) from being mistaken for VINs.
  static final RegExp _vinPattern = RegExp(
    r'(?<![A-Z0-9])(?=[A-HJ-NPR-Z0-9]{0,16}[G-HJ-NPR-Z])[A-HJ-NPR-Z0-9]{17}(?![A-Z0-9])',
  );

  static final RegExp _macPattern = RegExp(
    r'\b([0-9A-Fa-f]{2})(?::[0-9A-Fa-f]{2}){4}:([0-9A-Fa-f]{2})\b',
  );

  /// Redacts personal data from free text.
  static String text(String input) {
    var out = input.replaceAll(_vinPattern, '[VIN-REDACTED]');
    out = out.replaceAllMapped(
      _macPattern,
      (m) => '${m.group(1)}:**:**:**:**:${m.group(2)}',
    );
    return out;
  }

  /// Masks a device identifier for display in logs and exported reports.
  /// iOS exposes a per-app random UUID; Android exposes the MAC address.
  static String deviceId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
  }

  /// Masks a VIN for on-screen display unless the user chooses to reveal it.
  static String maskVin(String vin) {
    if (vin.length < 8) return '•' * vin.length;
    return '${vin.substring(0, 3)}${'•' * (vin.length - 6)}${vin.substring(vin.length - 3)}';
  }

  /// OBD responses that carry identifying data (mode 09 PID 02 = VIN) must
  /// never be logged verbatim.
  static bool isSensitiveCommand(String command) {
    final c = command.replaceAll(' ', '').toUpperCase();
    return c.startsWith('0902');
  }
}

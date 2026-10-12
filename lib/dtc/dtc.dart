import 'package:flutter/foundation.dart';

import 'dtc_database.dart';

enum DtcSystem {
  powertrain('P', 'Powertrain', 'Engine, transmission and emissions systems'),
  chassis('C', 'Chassis', 'Brakes, steering and suspension systems'),
  body('B', 'Body', 'Airbags, climate, lighting and comfort systems'),
  network('U', 'Network', 'Communication between control modules');

  const DtcSystem(this.letter, this.label, this.description);
  final String letter;
  final String label;
  final String description;
}

/// Where the code came from in the OBD protocol.
enum DtcStatus {
  stored('Stored', 'Confirmed fault stored by the module (mode 03)'),
  pending('Pending', 'Detected once, not yet confirmed (mode 07)'),
  permanent('Permanent', 'Cannot be cleared by a scan tool (mode 0A)');

  const DtcStatus(this.label, this.description);
  final String label;
  final String description;
}

enum DtcDefinitionType {
  generic('Generic (SAE J2012)'),
  manufacturer('Manufacturer-specific');

  const DtcDefinitionType(this.label);
  final String label;
}

@immutable
class DiagnosticTroubleCode {
  const DiagnosticTroubleCode({
    required this.code,
    required this.status,
    this.ecu = -1,
    this.ecuLabel = 'Module (address not reported)',
  });

  /// Five-character code, e.g. `P0301`.
  final String code;
  final DtcStatus status;
  final int ecu;
  final String ecuLabel;

  DtcSystem get system => DtcCodec.systemOf(code);
  DtcDefinitionType get definitionType => DtcCodec.definitionTypeOf(code);
  String get subsystem => DtcCodec.subsystemOf(code);

  /// Standard description when the code is in the local generic database.
  /// Null means "not available" – never invented.
  String? get description => definitionType == DtcDefinitionType.generic
      ? DtcDatabase.describe(code)
      : null;

  Map<String, Object> toJson() => {
        'code': code,
        'status': status.name,
        'ecu': ecu,
        'ecuLabel': ecuLabel,
      };

  factory DiagnosticTroubleCode.fromJson(Map<String, dynamic> j) =>
      DiagnosticTroubleCode(
        code: j['code'] as String,
        status: DtcStatus.values.byName(j['status'] as String),
        ecu: (j['ecu'] as num?)?.toInt() ?? -1,
        ecuLabel: j['ecuLabel'] as String? ?? 'Module (address not reported)',
      );

  @override
  bool operator ==(Object other) =>
      other is DiagnosticTroubleCode &&
      other.code == code &&
      other.status == status &&
      other.ecu == ecu;

  @override
  int get hashCode => Object.hash(code, status, ecu);
}

/// Encoding rules from SAE J2012 / ISO 15031-6.
class DtcCodec {
  const DtcCodec._();

  static const _letters = ['P', 'C', 'B', 'U'];

  /// Decodes the two raw DTC bytes. Returns null for the 0x0000 filler.
  static String? decode(int a, int b) {
    if (a == 0 && b == 0) return null;
    final letter = _letters[(a >> 6) & 0x03];
    final d1 = (a >> 4) & 0x03;
    final d2 = (a & 0x0F).toRadixString(16).toUpperCase();
    final rest = b.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '$letter$d1$d2$rest';
  }

  /// Decodes a run of DTC byte pairs.
  static List<String> decodeAll(List<int> bytes) {
    final out = <String>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final c = decode(bytes[i], bytes[i + 1]);
      if (c != null) out.add(c);
    }
    return out;
  }

  static final RegExp valid = RegExp(r'^[PCBU][0-3][0-9A-F]{3}$');

  static DtcSystem systemOf(String code) => switch (code[0]) {
        'P' => DtcSystem.powertrain,
        'C' => DtcSystem.chassis,
        'B' => DtcSystem.body,
        _ => DtcSystem.network,
      };

  static DtcDefinitionType definitionTypeOf(String code) {
    final d1 = code[1];
    if (code[0] == 'P') {
      if (d1 == '0' || d1 == '2') return DtcDefinitionType.generic;
      if (d1 == '1') return DtcDefinitionType.manufacturer;
      // P3000–P33FF manufacturer, P3400–P39FF generic.
      final d2 = int.parse(code[2], radix: 16);
      return d2 <= 3
          ? DtcDefinitionType.manufacturer
          : DtcDefinitionType.generic;
    }
    return (d1 == '0' || d1 == '3')
        ? DtcDefinitionType.generic
        : DtcDefinitionType.manufacturer;
  }

  /// Area of the vehicle indicated by the third character (powertrain
  /// generic groups per SAE J2012). Other systems return the system label.
  static String subsystemOf(String code) {
    if (code[0] == 'U') {
      return code[1] == '0'
          ? 'Network communication / module communication'
          : 'Network communication';
    }
    if (code[0] != 'P') return systemOf(code).description;
    return switch (code[2]) {
      '0' => 'Fuel and air metering, auxiliary emission controls',
      '1' || '2' => 'Fuel and air metering',
      '3' => 'Ignition system or misfire',
      '4' => 'Auxiliary emission controls',
      '5' => 'Vehicle speed, idle control and auxiliary inputs',
      '6' => 'Computer and output circuits',
      '7' || '8' || '9' => 'Transmission',
      'A' || 'B' || 'C' => 'Hybrid / electric propulsion',
      _ => 'Powertrain (other)',
    };
  }
}

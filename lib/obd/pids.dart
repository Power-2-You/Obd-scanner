import 'package:flutter/foundation.dart';

/// Mode 01 parameter definitions with SAE J1979 decoding formulas.
/// Only parameters the app actually displays are defined; anything else is
/// treated as unsupported rather than guessed.
@immutable
class PidDefinition {
  const PidDefinition({
    required this.pid,
    required this.key,
    required this.name,
    required this.shortName,
    required this.unit,
    required this.dataBytes,
    required this.min,
    required this.max,
    required this.decimals,
    required this.decode,
  });

  final int pid;
  final String key;
  final String name;
  final String shortName;
  final String unit;
  final int dataBytes;
  final double min;
  final double max;
  final int decimals;
  final double Function(List<int> d) decode;

  String get command =>
      '01${pid.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  String get hexId => pid.toRadixString(16).padLeft(2, '0').toUpperCase();
}

class Pids {
  const Pids._();

  static const monitorStatus = 0x01;
  static const engineLoad = 0x04;
  static const coolantTemp = 0x05;
  static const intakeMap = 0x0B;
  static const rpm = 0x0C;
  static const speed = 0x0D;
  static const intakeAirTemp = 0x0F;
  static const maf = 0x10;
  static const throttle = 0x11;
  static const runTime = 0x1F;
  static const fuelLevel = 0x2F;
  static const moduleVoltage = 0x42;
  static const ambientTemp = 0x46;
  static const oilTemp = 0x5C;

  static final Map<int, PidDefinition> all = {
    engineLoad: PidDefinition(
      pid: engineLoad,
      key: 'engine_load',
      name: 'Calculated engine load',
      shortName: 'Engine load',
      unit: '%',
      dataBytes: 1,
      min: 0,
      max: 100,
      decimals: 0,
      decode: (d) => d[0] * 100 / 255,
    ),
    coolantTemp: PidDefinition(
      pid: coolantTemp,
      key: 'coolant_temp',
      name: 'Engine coolant temperature',
      shortName: 'Coolant',
      unit: '°C',
      dataBytes: 1,
      min: -40,
      max: 130,
      decimals: 0,
      decode: (d) => d[0] - 40.0,
    ),
    intakeMap: PidDefinition(
      pid: intakeMap,
      key: 'intake_map',
      name: 'Intake manifold absolute pressure',
      shortName: 'MAP',
      unit: 'kPa',
      dataBytes: 1,
      min: 0,
      max: 255,
      decimals: 0,
      decode: (d) => d[0].toDouble(),
    ),
    rpm: PidDefinition(
      pid: rpm,
      key: 'rpm',
      name: 'Engine speed',
      shortName: 'RPM',
      unit: 'rpm',
      dataBytes: 2,
      min: 0,
      max: 8000,
      decimals: 0,
      decode: (d) => (d[0] * 256 + d[1]) / 4,
    ),
    speed: PidDefinition(
      pid: speed,
      key: 'speed',
      name: 'Vehicle speed',
      shortName: 'Speed',
      unit: 'km/h',
      dataBytes: 1,
      min: 0,
      max: 240,
      decimals: 0,
      decode: (d) => d[0].toDouble(),
    ),
    intakeAirTemp: PidDefinition(
      pid: intakeAirTemp,
      key: 'intake_air_temp',
      name: 'Intake air temperature',
      shortName: 'Intake air',
      unit: '°C',
      dataBytes: 1,
      min: -40,
      max: 100,
      decimals: 0,
      decode: (d) => d[0] - 40.0,
    ),
    maf: PidDefinition(
      pid: maf,
      key: 'maf',
      name: 'Mass air flow rate',
      shortName: 'MAF',
      unit: 'g/s',
      dataBytes: 2,
      min: 0,
      max: 655.35,
      decimals: 1,
      decode: (d) => (d[0] * 256 + d[1]) / 100,
    ),
    throttle: PidDefinition(
      pid: throttle,
      key: 'throttle',
      name: 'Throttle position',
      shortName: 'Throttle',
      unit: '%',
      dataBytes: 1,
      min: 0,
      max: 100,
      decimals: 0,
      decode: (d) => d[0] * 100 / 255,
    ),
    runTime: PidDefinition(
      pid: runTime,
      key: 'run_time',
      name: 'Run time since engine start',
      shortName: 'Run time',
      unit: 's',
      dataBytes: 2,
      min: 0,
      max: 65535,
      decimals: 0,
      decode: (d) => (d[0] * 256 + d[1]).toDouble(),
    ),
    fuelLevel: PidDefinition(
      pid: fuelLevel,
      key: 'fuel_level',
      name: 'Fuel tank level',
      shortName: 'Fuel',
      unit: '%',
      dataBytes: 1,
      min: 0,
      max: 100,
      decimals: 0,
      decode: (d) => d[0] * 100 / 255,
    ),
    moduleVoltage: PidDefinition(
      pid: moduleVoltage,
      key: 'module_voltage',
      name: 'Control module voltage',
      shortName: 'Voltage',
      unit: 'V',
      dataBytes: 2,
      min: 0,
      max: 18,
      decimals: 1,
      decode: (d) => (d[0] * 256 + d[1]) / 1000,
    ),
    ambientTemp: PidDefinition(
      pid: ambientTemp,
      key: 'ambient_temp',
      name: 'Ambient air temperature',
      shortName: 'Ambient',
      unit: '°C',
      dataBytes: 1,
      min: -40,
      max: 60,
      decimals: 0,
      decode: (d) => d[0] - 40.0,
    ),
    oilTemp: PidDefinition(
      pid: oilTemp,
      key: 'oil_temp',
      name: 'Engine oil temperature',
      shortName: 'Oil temp',
      unit: '°C',
      dataBytes: 1,
      min: -40,
      max: 160,
      decimals: 0,
      decode: (d) => d[0] - 40.0,
    ),
  };

  /// Parameters shown as gauges/tiles on the dashboard, in display order.
  static const dashboard = [
    rpm,
    speed,
    coolantTemp,
    moduleVoltage,
    engineLoad,
    throttle,
  ];

  /// Optional extra parameters shown in "More readings" when supported.
  static const extras = [
    intakeAirTemp,
    intakeMap,
    maf,
    fuelLevel,
    ambientTemp,
    oilTemp,
    runTime,
  ];
}

/// Decoded mode 01 PID 01 (monitor status since DTCs cleared), byte A.
@immutable
class MonitorStatus {
  const MonitorStatus({required this.milOn, required this.dtcCount});
  final bool milOn;
  final int dtcCount;

  static MonitorStatus decode(List<int> d) =>
      MonitorStatus(milOn: (d[0] & 0x80) != 0, dtcCount: d[0] & 0x7F);
}

/// Mode 01 supported-PID bitmaps (PIDs 00, 20, 40, ...).
@immutable
class SupportedPids {
  const SupportedPids(this.pids, {this.queriedRanges = const {}});

  static const SupportedPids none = SupportedPids({});

  final Set<int> pids;

  /// Range bases (0x00, 0x20, 0x40) that were actually queried.
  final Set<int> queriedRanges;

  bool supports(int pid) => pids.contains(pid);

  /// Whether we know the answer for [pid] (its range was queried).
  bool knows(int pid) => queriedRanges.contains(((pid - 1) ~/ 0x20) * 0x20);

  /// Decodes the 4 data bytes following `41 <base>`.
  /// Bit 7 of byte A = PID base+1 ... bit 0 of byte D = PID base+0x20.
  static Set<int> decodeBitmap(int base, List<int> bytes) {
    final out = <int>{};
    for (var i = 0; i < 4 && i < bytes.length; i++) {
      for (var bit = 0; bit < 8; bit++) {
        if ((bytes[i] & (0x80 >> bit)) != 0) out.add(base + i * 8 + bit + 1);
      }
    }
    return out;
  }

  SupportedPids merge(int base, Set<int> more) => SupportedPids(
    {...pids, ...more},
    queriedRanges: {...queriedRanges, base},
  );
}

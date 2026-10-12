import 'dart:math' as math;

import '../../obd/obd_protocol.dart';

/// A module (ECU) inside the simulated vehicle.
class SimulatedEcu {
  SimulatedEcu({
    required this.canHeader,
    required this.legacyAddress,
    required this.supportedPids,
    this.storedDtcs = const [],
    this.pendingDtcs = const [],
  });

  /// 11-bit response header, e.g. 0x7E8.
  final int canHeader;

  /// Source byte for 29-bit / legacy headers, e.g. 0x10.
  final int legacyAddress;
  final Set<int> supportedPids;
  final List<String> storedDtcs;
  final List<String> pendingDtcs;
}

enum SimulationScenario {
  healthyDriving(
    'Healthy car – short drive',
    'Engine warming up, gentle driving, no fault codes.',
  ),
  checkEngine(
    'Check-engine light on',
    'Idling with a cylinder 1 misfire and catalyst code stored.',
  ),
  multiModule(
    'Two modules answering',
    'Engine and transmission modules both respond; voltage PID unsupported.',
  ),
  legacyIso9141(
    'Older car (ISO 9141-2)',
    'Pre-CAN protocol with legacy frame format.',
  ),
  ignitionOff(
    'Ignition off',
    'Scanner powered but the car is off – the bus cannot be reached.',
  );

  const SimulationScenario(this.title, this.description);
  final String title;
  final String description;
}

/// Synthetic vehicle used by the simulated scanner. All values are generated
/// from smooth functions of time so the dashboard looks alive, and every
/// screen that shows simulated data is clearly labelled as simulated.
class SimulatedVehicle {
  SimulatedVehicle({
    required this.scenario,
    required this.protocol,
    required this.ecus,
    required this.vin,
    required this.reachable,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        _start = (clock ?? DateTime.now)();

  factory SimulatedVehicle.forScenario(
    SimulationScenario s, {
    DateTime Function()? clock,
  }) {
    const allBasic = {0x01, 0x04, 0x05, 0x0B, 0x0C, 0x0D, 0x0F, 0x10, 0x11, 0x1F, 0x2F, 0x42, 0x46};
    switch (s) {
      case SimulationScenario.healthyDriving:
        return SimulatedVehicle(
          scenario: s,
          protocol: ObdProtocol.can11x500,
          vin: 'MGHDEM00000000001',
          reachable: true,
          clock: clock,
          ecus: [SimulatedEcu(canHeader: 0x7E8, legacyAddress: 0x10, supportedPids: allBasic)],
        );
      case SimulationScenario.checkEngine:
        return SimulatedVehicle(
          scenario: s,
          protocol: ObdProtocol.can11x500,
          vin: 'MGHDEM00000000002',
          reachable: true,
          clock: clock,
          ecus: [
            SimulatedEcu(
              canHeader: 0x7E8,
              legacyAddress: 0x10,
              supportedPids: allBasic,
              storedDtcs: const ['P0301', 'P0420', 'P0171'],
              pendingDtcs: const ['P0302'],
            ),
          ],
        );
      case SimulationScenario.multiModule:
        return SimulatedVehicle(
          scenario: s,
          protocol: ObdProtocol.can11x500,
          vin: 'MGHDEM00000000003',
          reachable: true,
          clock: clock,
          ecus: [
            SimulatedEcu(
              canHeader: 0x7E8,
              legacyAddress: 0x10,
              supportedPids: {...allBasic}..remove(0x42),
              storedDtcs: const ['P0128'],
            ),
            SimulatedEcu(
              canHeader: 0x7E9,
              legacyAddress: 0x18,
              supportedPids: const {0x01, 0x0D},
              storedDtcs: const ['P0715'],
            ),
          ],
        );
      case SimulationScenario.legacyIso9141:
        return SimulatedVehicle(
          scenario: s,
          protocol: ObdProtocol.iso9141,
          vin: 'MGHDEM00000000004',
          reachable: true,
          clock: clock,
          ecus: [
            SimulatedEcu(
              canHeader: 0x7E8,
              legacyAddress: 0x10,
              supportedPids: const {0x01, 0x04, 0x05, 0x0C, 0x0D, 0x11},
              storedDtcs: const ['P0442'],
            ),
          ],
        );
      case SimulationScenario.ignitionOff:
        return SimulatedVehicle(
          scenario: s,
          protocol: ObdProtocol.can11x500,
          vin: 'MGHDEM00000000005',
          reachable: false,
          clock: clock,
          ecus: [SimulatedEcu(canHeader: 0x7E8, legacyAddress: 0x10, supportedPids: allBasic)],
        );
    }
  }

  final SimulationScenario scenario;
  final ObdProtocol protocol;
  final List<SimulatedEcu> ecus;
  final String vin;

  /// False simulates ignition off: the adapter cannot reach the bus.
  final bool reachable;
  final DateTime Function() _clock;
  final DateTime _start;

  double get _t => _clock().difference(_start).inMilliseconds / 1000.0;

  bool get _driving => scenario == SimulationScenario.healthyDriving ||
      scenario == SimulationScenario.multiModule;

  double get speed {
    if (!_driving) return 0;
    // Gentle stop-start urban drive, 90 s cycle.
    final phase = (_t % 90) / 90;
    final v = 62 * math.pow(math.sin(phase * math.pi), 2);
    return v.clamp(0, 140).toDouble();
  }

  double get rpm {
    final misfire = scenario == SimulationScenario.checkEngine
        ? 60 * math.sin(_t * 7.3)
        : 0;
    if (!_driving) return 760 + 18 * math.sin(_t * 1.7) + misfire;
    final v = speed;
    // Rough gear model: rpm rises with speed, drops at shifts.
    final gearSpeed = v < 18 ? 18 : v < 35 ? 35 : v < 55 ? 55 : 80;
    final ratio = (v / gearSpeed).clamp(0.0, 1.0);
    return 820 + 1900 * ratio + 40 * math.sin(_t * 2.1);
  }

  double get coolant => 38 + 52 * (1 - math.exp(-_t / 140));
  double get intakeAir => 24 + 3 * math.sin(_t / 40);
  double get throttle => _driving ? 15 + speed * 0.35 + 6 * math.sin(_t * 0.9).abs() : 14.5;
  double get load => _driving ? 22 + speed * 0.45 : 24 + 3 * math.sin(_t * 0.7);
  double get map => 32 + load * 0.6;
  double get maf => 2.4 + rpm / 900 + load / 25;
  double get fuel => 63;
  double get ambient => 21;
  double get moduleVoltage => 14.1 + 0.08 * math.sin(_t * 0.5);
  double get batteryVoltage => reachable ? moduleVoltage - 0.1 : 12.5;
  int get runTime => _t.round();

  /// Raw data bytes for a mode 01 PID, or null if [ecu] does not support it.
  List<int>? mode01(SimulatedEcu ecu, int pid) {
    if (pid == 0x00 || pid == 0x20 || pid == 0x40) {
      final relevant = ecu.supportedPids.where((p) => p > pid && p <= pid + 0x20);
      final next = ecu.supportedPids.any((p) => p > pid + 0x20) ? {pid + 0x20} : <int>{};
      if (pid != 0 && relevant.isEmpty) return null;
      return _bitmap(pid, {...relevant, ...next});
    }
    if (!ecu.supportedPids.contains(pid)) return null;
    int b(double v) => v.round().clamp(0, 255);
    int pct(double v) => (v * 255 / 100).round().clamp(0, 255);
    return switch (pid) {
      0x01 => [
          (ecu.storedDtcs.isNotEmpty ? 0x80 : 0) | ecu.storedDtcs.length,
          0x07,
          0x65,
          0x00,
        ],
      0x04 => [pct(load)],
      0x05 => [b(coolant + 40)],
      0x0B => [b(map)],
      0x0C => _u16((rpm * 4).round()),
      0x0D => [b(speed)],
      0x0F => [b(intakeAir + 40)],
      0x10 => _u16((maf * 100).round()),
      0x11 => [pct(throttle)],
      0x1F => _u16(runTime),
      0x2F => [pct(fuel)],
      0x42 => _u16((moduleVoltage * 1000).round()),
      0x46 => [b(ambient + 40)],
      _ => null,
    };
  }

  static List<int> _u16(int v) {
    final c = v.clamp(0, 0xFFFF);
    return [(c >> 8) & 0xFF, c & 0xFF];
  }

  static List<int> _bitmap(int base, Set<int> pids) {
    final out = [0, 0, 0, 0];
    for (final p in pids) {
      final idx = p - base - 1;
      if (idx < 0 || idx >= 32) continue;
      out[idx ~/ 8] |= 0x80 >> (idx % 8);
    }
    return out;
  }

  static List<int> encodeDtc(String code) {
    const letters = {'P': 0, 'C': 1, 'B': 2, 'U': 3};
    final a = (letters[code[0]]! << 6) |
        (int.parse(code[1]) << 4) |
        int.parse(code[2], radix: 16);
    final b = int.parse(code.substring(3), radix: 16);
    return [a, b];
  }
}

import 'package:flutter/foundation.dart';

import 'dtc.dart';

enum GuidanceLevel {
  checkSoon('Check soon', 'Not usually urgent, but get it looked at.'),
  inspectPromptly(
    'Inspect promptly',
    'Can affect how the vehicle drives or cause further damage.',
  ),
  stopAndInspect(
    'Stop and inspect',
    'Continuing to drive could cause serious damage or be unsafe.',
  );

  const GuidanceLevel(this.label, this.summary);
  final String label;
  final String summary;
}

/// Rule-based general guidance for a code family.
///
/// This is deliberately conservative, generic information keyed on the code
/// family. It is not a diagnosis and is labelled as such in the UI.
@immutable
class DtcGuidance {
  const DtcGuidance({
    required this.level,
    required this.family,
    required this.commonAreas,
    required this.safetyNote,
    this.quickCheck,
  });

  final GuidanceLevel level;
  final String family;

  /// Areas commonly inspected for this family of codes.
  final List<String> commonAreas;
  final String safetyNote;

  /// A simple owner check worth doing first, if one exists.
  final String? quickCheck;

  /// A trouble code identifies the system or circuit that failed a module
  /// self-test, not the failed part. Further diagnosis is always required
  /// before replacing parts.
  bool get furtherDiagnosisRequired => true;

  static const String diagnosisNote =
      'A trouble code shows which system or circuit failed a self-test. '
      'It does not identify the failed part, so further diagnosis is needed '
      'before replacing anything.';

  static int? _num(String code) => int.tryParse(code.substring(1), radix: 16);

  static bool _inRange(String code, String from, String to) {
    if (code[0] != from[0]) return false;
    final n = _num(code), a = _num(from), b = _num(to);
    if (n == null || a == null || b == null) return false;
    return n >= a && n <= b;
  }

  static DtcGuidance forCode(DiagnosticTroubleCode dtc) => forCodeString(dtc.code);

  static DtcGuidance forCodeString(String code) {
    bool r(String a, String b) => _inRange(code, a, b);

    if (code == 'P0524') {
      return const DtcGuidance(
        level: GuidanceLevel.stopAndInspect,
        family: 'Engine oil pressure',
        commonAreas: ['Engine oil level', 'Oil pressure sender', 'Oil pump'],
        safetyNote: 'Low oil pressure can damage an engine within minutes. '
            'Stop safely, switch off and check the oil level before driving on.',
        quickCheck: 'With the engine off on level ground, check the dipstick.',
      );
    }
    if (code == 'P0217') {
      return const DtcGuidance(
        level: GuidanceLevel.stopAndInspect,
        family: 'Engine overheating',
        commonAreas: ['Coolant level', 'Cooling fan', 'Thermostat', 'Water pump'],
        safetyNote: 'An overheating engine can be severely damaged. Stop safely '
            'and let it cool. Never open a hot radiator cap.',
      );
    }
    if (code == 'P0218') {
      return const DtcGuidance(
        level: GuidanceLevel.stopAndInspect,
        family: 'Transmission overheating',
        commonAreas: ['Transmission fluid level/condition', 'Transmission cooler'],
        safetyNote:
            'Stop safely and let the transmission cool before continuing.',
      );
    }
    if (r('P0300', 'P0312')) {
      return const DtcGuidance(
        level: GuidanceLevel.inspectPromptly,
        family: 'Engine misfire',
        commonAreas: [
          'Spark plugs',
          'Ignition coils / leads',
          'Fuel injectors',
          'Vacuum leaks',
          'Engine compression',
        ],
        safetyNote: 'If the check-engine light is flashing, reduce load and '
            'only drive as far as needed: a severe misfire can overheat and '
            'damage the catalytic converter.',
      );
    }
    if (r('P0351', 'P0362')) {
      return const DtcGuidance(
        level: GuidanceLevel.inspectPromptly,
        family: 'Ignition coil circuit',
        commonAreas: ['Ignition coil', 'Coil connector and wiring'],
        safetyNote: 'Coil faults commonly cause misfires and rough running.',
      );
    }
    if (r('P0010', 'P0025') || r('P0335', 'P0349')) {
      return const DtcGuidance(
        level: GuidanceLevel.inspectPromptly,
        family: 'Crankshaft / camshaft position or timing',
        commonAreas: [
          'Position sensors and wiring',
          'Variable valve timing solenoid',
          'Engine oil level and condition',
          'Timing chain/belt',
        ],
        safetyNote: 'These faults can cause stalling or a no-start condition.',
      );
    }
    if (r('P0120', 'P0123') ||
        r('P0220', 'P0223') ||
        code == 'P2101' ||
        code == 'P2135' ||
        code == 'P2138') {
      return const DtcGuidance(
        level: GuidanceLevel.inspectPromptly,
        family: 'Throttle / pedal position',
        commonAreas: ['Throttle body', 'Pedal position sensor', 'Wiring and connectors'],
        safetyNote: 'Throttle faults can put the vehicle into reduced-power '
            '("limp") mode. Take care when merging or overtaking.',
      );
    }
    if (code == 'P0087' || code == 'P0088' || r('P0190', 'P0193') || code == 'P0230') {
      return const DtcGuidance(
        level: GuidanceLevel.inspectPromptly,
        family: 'Fuel pressure / delivery',
        commonAreas: ['Fuel pump', 'Fuel filter', 'Pressure sensor', 'Pressure regulator'],
        safetyNote: 'Fuel delivery problems can cause hesitation or stalling.',
      );
    }
    if (r('P0171', 'P0175') || code == 'P2187' || code == 'P2188') {
      return const DtcGuidance(
        level: GuidanceLevel.checkSoon,
        family: 'Fuel trim (air/fuel mixture)',
        commonAreas: [
          'Vacuum / intake leaks',
          'Mass air flow sensor',
          'Fuel pressure',
          'Injectors',
          'Exhaust leaks before the oxygen sensor',
        ],
        safetyNote: 'Usually drivable, but a persistent mixture fault can '
            'lead to misfires and catalytic converter damage.',
      );
    }
    if (code == 'P0420' || code == 'P0421' || code == 'P0430') {
      return const DtcGuidance(
        level: GuidanceLevel.checkSoon,
        family: 'Catalytic converter efficiency',
        commonAreas: [
          'Upstream faults first (misfire, mixture)',
          'Oxygen sensors',
          'Exhaust leaks',
          'Catalytic converter',
        ],
        safetyNote: 'Not usually a safety issue, but check for other codes '
            'first – they are a common cause.',
      );
    }
    if (r('P0440', 'P0457')) {
      final capCodes = {'P0455', 'P0456', 'P0457', 'P0442'};
      return DtcGuidance(
        level: GuidanceLevel.checkSoon,
        family: 'Evaporative emissions (fuel vapour)',
        commonAreas: const [
          'Fuel cap seal',
          'EVAP hoses',
          'Purge / vent valves',
          'Charcoal canister',
        ],
        safetyNote: 'Not usually a drivability issue. If you smell fuel, have '
            'it inspected promptly.',
        quickCheck: capCodes.contains(code)
            ? 'Check the fuel cap is present, undamaged and clicks tight.'
            : null,
      );
    }
    if (r('P0130', 'P0167') || code == 'P0030' || code == 'P0036' ||
        r('P2195', 'P2271') || code == 'P2096' || code == 'P2097') {
      return const DtcGuidance(
        level: GuidanceLevel.checkSoon,
        family: 'Oxygen (O2) sensor',
        commonAreas: ['O2 sensor', 'Sensor heater circuit', 'Wiring', 'Exhaust leaks'],
        safetyNote: 'Usually drivable; fuel economy and emissions may suffer.',
      );
    }
    if (r('P0100', 'P0113')) {
      return const DtcGuidance(
        level: GuidanceLevel.checkSoon,
        family: 'Air flow / manifold pressure / intake temperature',
        commonAreas: ['Sensor connector', 'Air filter and intake ducting', 'Sensor itself'],
        safetyNote: 'May cause hesitation, poor economy or rough idle.',
      );
    }
    if (r('P0115', 'P0118') || code == 'P0125' || code == 'P0128') {
      return const DtcGuidance(
        level: GuidanceLevel.checkSoon,
        family: 'Coolant temperature / thermostat',
        commonAreas: ['Coolant level', 'Thermostat', 'Coolant temperature sensor'],
        safetyNote: 'Watch the temperature gauge. Stop if it rises towards hot.',
      );
    }
    if (r('P0520', 'P0523')) {
      return const DtcGuidance(
        level: GuidanceLevel.inspectPromptly,
        family: 'Oil pressure sensor circuit',
        commonAreas: ['Oil level', 'Oil pressure sender and wiring'],
        safetyNote: 'As a precaution, check the oil level before driving.',
        quickCheck: 'Check the engine oil level on the dipstick.',
      );
    }
    if (r('P0560', 'P0563')) {
      return const DtcGuidance(
        level: GuidanceLevel.inspectPromptly,
        family: 'System voltage',
        commonAreas: ['Battery condition', 'Alternator / charging system', 'Battery terminals'],
        safetyNote: 'A charging fault can leave you stranded. The IQ jump '
            'starter can help you start, but the cause still needs fixing.',
      );
    }
    if (r('P0600', 'P0699')) {
      return const DtcGuidance(
        level: GuidanceLevel.inspectPromptly,
        family: 'Control module / output circuits',
        commonAreas: ['Module power and ground supply', 'Wiring', 'Control module'],
        safetyNote: 'Have a workshop check this – module faults can affect '
            'several systems.',
      );
    }
    if (r('P0700', 'P0799')) {
      return const DtcGuidance(
        level: GuidanceLevel.inspectPromptly,
        family: 'Transmission',
        commonAreas: ['Transmission fluid level/condition', 'Sensors and solenoids', 'Wiring'],
        safetyNote: 'Transmission faults can cause harsh shifts or a '
            'reduced-function mode.',
      );
    }
    if (code.startsWith('U')) {
      return const DtcGuidance(
        level: GuidanceLevel.inspectPromptly,
        family: 'Module communication',
        commonAreas: ['Battery voltage', 'Wiring / connectors', 'Affected module'],
        safetyNote: 'Communication faults can disable systems such as ABS or '
            'instrument warnings.',
      );
    }
    if (code.startsWith('C')) {
      return const DtcGuidance(
        level: GuidanceLevel.inspectPromptly,
        family: 'Chassis (brakes, steering, suspension)',
        commonAreas: ['Wheel speed sensors', 'Brake system', 'Steering system'],
        safetyNote: 'If a brake, ABS or stability warning light is on, have '
            'the system checked before relying on it.',
      );
    }
    if (code.startsWith('B')) {
      return const DtcGuidance(
        level: GuidanceLevel.checkSoon,
        family: 'Body systems',
        commonAreas: ['Affected body system', 'Wiring and connectors'],
        safetyNote: 'Body codes include airbag (SRS) faults. If the airbag '
            'warning light is on, airbags may not deploy – inspect promptly.',
      );
    }
    return const DtcGuidance(
      level: GuidanceLevel.checkSoon,
      family: 'Powertrain',
      commonAreas: ['System indicated by the code'],
      safetyNote: 'Watch for warning lights or changes in how the vehicle '
          'drives, and have the code diagnosed.',
    );
  }
}

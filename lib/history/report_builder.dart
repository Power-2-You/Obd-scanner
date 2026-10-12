import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../ai/ai_models.dart';
import '../device/connection_controller.dart';
import '../dtc/dtc.dart';
import '../dtc/dtc_guidance.dart';
import '../dtc/fault_scan_controller.dart';
import '../obd/elm327_session.dart';
import '../obd/live_data_controller.dart';
import '../obd/pids.dart';
import '../vehicle/vehicle.dart';
import 'diagnostic_report.dart';

/// Builds report snapshots from the current session and renders them as
/// shareable text. The same snapshot feeds the AI mechanic, so the AI sees
/// exactly the confirmed data the user sees.
class ReportBuilder {
  const ReportBuilder._();

  static const _uuid = Uuid();

  static DiagnosticReport snapshot({
    required ConnectionController connection,
    required FaultScanController faults,
    required LiveDataController live,
    Vehicle? vehicle,
  }) {
    final session = connection.session;
    final readings = <ReadingSnapshot>[];
    for (final pid in [...Pids.dashboard, ...Pids.extras]) {
      final def = Pids.all[pid]!;
      final r = live.readings[pid];
      final unsupported = live.isUnsupported(pid);
      if (r == null && !unsupported && Pids.extras.contains(pid)) continue;
      readings.add(
        ReadingSnapshot(
          key: def.key,
          name: def.name,
          unit: def.unit,
          decimals: def.decimals,
          status: unsupported
              ? 'unsupported'
              : r == null
              ? 'noData'
              : r.status.name,
          value: r?.hasValue == true ? r!.value : null,
        ),
      );
    }
    if (live.adapterVoltage != null) {
      readings.add(
        ReadingSnapshot(
          key: 'adapter_voltage',
          name: 'Battery voltage at OBD port (measured by scanner)',
          unit: 'V',
          decimals: 1,
          status: 'live',
          value: live.adapterVoltage,
        ),
      );
    }
    final simulated =
        connection.isSimulated || (faults.scannedSimulated ?? false);
    return DiagnosticReport(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      dataOrigin: simulated ? 'simulated' : 'live',
      scannerName: connection.details?.deviceName ?? 'No scanner',
      scannerFamily: session?.identity?.banner,
      protocol: session?.protocol.label,
      vehicleId: vehicle?.id,
      vehicle: vehicle?.toJson(includeVin: false),
      storedCodes: faults.stored?.codes ?? const [],
      pendingCodes: faults.pending?.codes ?? const [],
      milOn: faults.monitor?.milOn ?? live.monitorStatus?.milOn,
      readings: readings,
    );
  }

  static DiagnosticContext contextFor(DiagnosticReport r) {
    Map<String, Object?> code(DiagnosticTroubleCode c) => {
      'code': c.code,
      'status': c.status.name,
      'description': c.description,
      'definition': c.definitionType.label,
      'system': c.system.label,
      'subsystem': c.subsystem,
      'source': c.ecuLabel,
    };
    return DiagnosticContext(
      dataOrigin: r.dataOrigin,
      vehicle: r.vehicle == null
          ? null
          : {
              'make': r.vehicle!['make'],
              'model': r.vehicle!['model'],
              'year': r.vehicle!['year'],
              'engine': r.vehicle!['engine'],
            },
      faultCodes: [...r.storedCodes.map(code), ...r.pendingCodes.map(code)],
      readings: [
        for (final x in r.readings.where((x) => x.value != null))
          {'name': x.name, 'value': x.value, 'unit': x.unit},
      ],
      unsupported: [
        for (final x in r.readings.where((x) => x.value == null)) x.name,
      ],
      milOn: r.milOn,
      reportedDtcCount: r.storedCodes.length,
      protocol: r.protocol,
      scanTime: r.createdAt,
    );
  }

  /// Rule-based next steps (plus AI suggestions when present).
  static List<String> nextSteps(DiagnosticReport r) {
    final steps = <String>[];
    final codes = [...r.storedCodes, ...r.pendingCodes];
    if (codes.isEmpty) {
      steps.add(
        'No trouble codes were reported. If you notice a symptom, '
        'note when it happens and scan again while it is present.',
      );
    }
    final guidance = {for (final c in codes) c.code: DtcGuidance.forCode(c)};
    final urgent = guidance.entries
        .where((e) => e.value.level == GuidanceLevel.stopAndInspect)
        .map((e) => e.key)
        .toList();
    if (urgent.isNotEmpty) {
      steps.add(
        'Priority: ${urgent.join(', ')} – ${guidance[urgent.first]!.safetyNote}',
      );
    }
    for (final e in guidance.entries) {
      final q = e.value.quickCheck;
      if (q != null) steps.add('${e.key}: $q');
    }
    if (codes.isNotEmpty) {
      steps.add(
        'Have the codes diagnosed before replacing parts – a code points '
        'to a system or circuit, not a specific failed part.',
      );
      steps.add(
        'Do not clear the codes before a mechanic has seen them; they '
        'help diagnosis.',
      );
    }
    final ai = r.aiAnswer;
    if (ai != null) {
      for (final c in ai.nextChecks.take(4)) {
        steps.add(
          '${c.step} (AI suggestion, ${c.who == 'owner' ? 'owner check' : 'workshop'})',
        );
      }
    }
    return steps;
  }

  static String toText(DiagnosticReport r) {
    final df = DateFormat('d MMM yyyy, h:mm a');
    final b = StringBuffer();
    void line([String s = '']) => b.writeln(s);
    void heading(String s) {
      line();
      line(s.toUpperCase());
      line('-' * s.length);
    }

    line('MY GARAGE HERO IQ – DIAGNOSTIC REPORT');
    if (r.isSimulated) {
      line();
      line('*** SIMULATED DATA – generated by the in-app demo scanner, ');
      line('*** not read from a real vehicle.');
    }
    heading('Vehicle');
    line(r.vehicleName);
    final engine = r.vehicle?['engine'] as String? ?? '';
    if (engine.isNotEmpty) line('Engine: $engine');
    heading('Diagnostic session');
    line('Date: ${df.format(r.createdAt)}');
    line(
      'Scanner: ${r.scannerName}${r.scannerFamily == null ? '' : ' (${r.scannerFamily})'}',
    );
    if (r.protocol != null) line('Vehicle protocol: ${r.protocol}');
    line(
      'Check-engine light: ${r.milOn == null
          ? 'not reported'
          : r.milOn!
          ? 'ON'
          : 'OFF'}',
    );

    heading('Fault codes');
    if (r.storedCodes.isEmpty && r.pendingCodes.isEmpty) {
      line('No stored or pending emission-related codes reported.');
    }
    for (final c in [...r.storedCodes, ...r.pendingCodes]) {
      final g = DtcGuidance.forCode(c);
      line('${c.code}  [${c.status.label}]');
      line(
        '  ${c.description ?? 'Description not available in local database'}',
      );
      line('  ${c.system.label} · ${c.subsystem} · ${c.definitionType.label}');
      line('  Source: ${c.ecuLabel}');
      line('  Guidance: ${g.level.label} – ${g.safetyNote}');
    }

    heading('Sensor readings');
    for (final x in r.readings) {
      line('${x.name}: ${x.display}');
    }

    final ai = r.aiAnswer;
    if (ai != null) {
      heading('AI mechanic explanation (not a confirmed diagnosis)');
      if (r.aiQuestion != null) line('Question: ${r.aiQuestion}');
      line(ai.summary);
      if (ai.possibleCauses.isNotEmpty) {
        line();
        line('Possible causes:');
        for (final c in ai.possibleCauses) {
          line('  • ${c.cause} (${c.likelihood.replaceAll('_', ' ')})');
        }
      }
      line();
      line('Safety: ${ai.safetyLevel.label}');
      for (final n in ai.safetyNotes) {
        line('  • $n');
      }
      if (ai.costOutlook.isNotEmpty) line('Cost outlook: ${ai.costOutlook}');
      if (ai.unknowns.isNotEmpty) {
        line('Unknown / not supported:');
        for (final u in ai.unknowns) {
          line('  • $u');
        }
      }
      line(ai.disclaimer);
    }

    heading('Recommended next steps');
    for (final s in nextSteps(r)) {
      line('• $s');
    }
    if (r.notes.isNotEmpty) {
      heading('Notes');
      line(r.notes);
    }
    line();
    line(
      'Generated by My Garage Hero IQ. Trouble codes and readings come from '
      'the vehicle\'s on-board diagnostics. This report is not a substitute '
      'for inspection by a qualified mechanic.',
    );
    return b.toString();
  }

  static String readingValue(PidReading? r, int pid, bool unsupported) {
    if (unsupported) return 'Not supported';
    if (r == null) return '—';
    if (!r.hasValue) return 'Unavailable';
    final def = Pids.all[pid];
    return r.value!.toStringAsFixed(def?.decimals ?? 0);
  }
}

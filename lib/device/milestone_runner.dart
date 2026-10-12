import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/telemetry/diagnostic_log.dart';
import '../core/telemetry/redactor.dart';
import '../obd/elm327_session.dart';
import '../obd/pids.dart';
import '../transport/obd_transport.dart';
import 'connection_controller.dart';

class MilestoneStep {
  MilestoneStep(this.number, this.title);
  final int number;
  final String title;
  ProgressState state = ProgressState.pending;
  String detail = '';
}

/// Milestone 1 – "prove the app can retrieve genuine diagnostic data".
///
/// Re-runs and records the nine required steps against the current
/// connection. The verdict is only "hardware verified" when the transport is
/// a real scanner; with the simulator it explicitly says the milestone has
/// NOT passed.
class MilestoneRunner extends ChangeNotifier {
  MilestoneRunner({required this.connection, required this.log});

  final ConnectionController connection;
  final DiagnosticLog log;

  bool running = false;
  double? rpm;
  String verdict = 'Not run yet';
  bool hardwareVerified = false;
  DateTime? ranAt;

  final List<MilestoneStep> steps = [
    MilestoneStep(1, 'Discover the scanner'),
    MilestoneStep(2, 'Connect through the verified transport'),
    MilestoneStep(3, 'Identify the scanner / protocol'),
    MilestoneStep(4, 'Initialise the diagnostic session'),
    MilestoneStep(5, 'Request supported PIDs (0100)'),
    MilestoneStep(6, 'Read engine RPM (010C)'),
    MilestoneStep(7, 'Decode the received response'),
    MilestoneStep(8, 'Display the actual RPM on screen'),
    MilestoneStep(9, 'Record logs without personal data'),
  ];

  void _set(int i, ProgressState s, String d) {
    steps[i]
      ..state = s
      ..detail = d;
    notifyListeners();
  }

  Future<void> run() async {
    if (running) return;
    running = true;
    rpm = null;
    hardwareVerified = false;
    for (final s in steps) {
      s
        ..state = ProgressState.pending
        ..detail = '';
    }
    notifyListeners();
    log.info(LogCategory.app, 'Milestone run started');

    try {
      final t = connection.transport;
      final session = connection.session;
      final d = connection.details;
      final simulated = t?.kind == TransportKind.simulated;

      // 1 – Discover
      if (d == null) {
        _set(
          0,
          ProgressState.failed,
          'No scanner selected. Search for your IQ first.',
        );
        return;
      }
      _set(
        0,
        ProgressState.done,
        simulated
            ? 'Simulated device (no radio discovery)'
            : '${d.deviceName} (${connection.discoveredByScan ? 'found by scan' : 'saved/manual'})',
      );

      // 2 – Connect
      if (t == null || t.state != LinkState.connected) {
        _set(
          1,
          ProgressState.failed,
          'Not connected. Connect first, then re-run.',
        );
        return;
      }
      _set(
        1,
        ProgressState.done,
        '${t.kind.label}${d.profileName == null ? '' : ' · ${d.profileName}'}',
      );

      // 3 – Identify
      final id = session?.identity;
      if (session == null || id == null || !id.recognised) {
        _set(
          2,
          ProgressState.failed,
          'Scanner did not identify as ELM327/STN.',
        );
        return;
      }
      _set(2, ProgressState.done, '${id.banner} · ${session.protocol.label}');

      // 4 – Initialise
      if (!session.isInitialised) {
        _set(3, ProgressState.failed, 'Session not initialised.');
        return;
      }
      _set(
        3,
        ProgressState.done,
        session.warnings.isEmpty
            ? 'All setup commands acknowledged'
            : 'Initialised with warnings: ${session.warnings.join('; ')}',
      );

      // 5 – Supported PIDs
      _set(4, ProgressState.running, '');
      final supported = await session.discoverSupportedPids();
      if (supported.pids.isEmpty) {
        _set(4, ProgressState.failed, 'Vehicle returned no supported PIDs.');
        return;
      }
      _set(
        4,
        ProgressState.done,
        '${supported.pids.length} PIDs, RPM '
        '${supported.supports(Pids.rpm) ? 'supported' : 'NOT supported'}',
      );

      // 6 – Read RPM
      _set(5, ProgressState.running, '');
      final reading = await session.readPid(Pids.rpm);
      final raw = (reading.raw ?? '').replaceAll('\r', ' ').trim();
      if (reading.status != ReadingStatus.live) {
        _set(
          5,
          ProgressState.failed,
          '${reading.status.name}: ${reading.message ?? raw}',
        );
        return;
      }
      _set(5, ProgressState.done, 'Raw: $raw');

      // 7 – Decode
      rpm = reading.value;
      _set(
        6,
        ProgressState.done,
        '${reading.value!.toStringAsFixed(0)} rpm from ${reading.ecu}',
      );

      // 8 – Display (the developer screen renders [rpm] as soon as it is set)
      _set(
        7,
        ProgressState.done,
        'Shown below as ${reading.value!.toStringAsFixed(0)} rpm',
      );

      // 9 – Logs
      final entries = log.entries;
      // Every entry is redacted on write; re-check that nothing slipped past.
      final leaked = entries.any((e) => Redactor.text(e.message) != e.message);
      _set(
        8,
        leaked ? ProgressState.failed : ProgressState.done,
        '${entries.length} entries · ${connection.channel?.history.length ?? 0} exchanges · '
        '${leaked ? 'possible personal data found!' : 'redaction check passed'}',
      );

      hardwareVerified = !simulated;
    } on AppException catch (e) {
      final i = steps.indexWhere((s) => s.state == ProgressState.running);
      if (i >= 0) _set(i, ProgressState.failed, e.userMessage);
    } finally {
      running = false;
      ranAt = DateTime.now();
      final allDone = steps.every((s) => s.state == ProgressState.done);
      if (!allDone) {
        verdict = 'Milestone NOT passed – see the failed step.';
      } else if (!hardwareVerified) {
        verdict =
            'Pipeline works with the SIMULATED scanner. The milestone '
            'has NOT passed: it must be repeated with a real IQ in a vehicle.';
      } else {
        verdict =
            'All steps passed on real hardware. Confirm the RPM above '
            'matches the vehicle\'s tachometer, then record the result.';
      }
      log.info(LogCategory.app, 'Milestone run finished: $verdict');
      notifyListeners();
    }
  }
}

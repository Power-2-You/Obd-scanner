import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/telemetry/telemetry.dart';
import '../device/connection_controller.dart';
import '../obd/elm327_session.dart';
import '../obd/pids.dart';
import 'dtc.dart';

/// Reads stored and pending trouble codes. Read-only: this version of the app
/// cannot clear codes (mode 04 is blocked by CommandPolicy).
class FaultScanController extends ChangeNotifier {
  FaultScanController({required this.connection, required this.telemetry}) {
    connection.addListener(_onConnection);
  }

  final ConnectionController connection;
  final Telemetry telemetry;

  bool scanning = false;
  String? error;
  DateTime? scannedAt;
  bool? scannedSimulated;
  DtcReadResult? stored;
  DtcReadResult? pending;
  MonitorStatus? monitor;
  bool _disposed = false;

  bool get hasResult => stored != null;
  List<DiagnosticTroubleCode> get allCodes => [
    ...?stored?.codes,
    ...?pending?.codes,
  ];

  List<String> get problems => [...?stored?.problems, ...?pending?.problems];

  Future<void> scan() async {
    final s = connection.session;
    if (s == null || !connection.isReady || scanning) return;
    scanning = true;
    error = null;
    _notify();
    try {
      stored = await s.readDtcs(DtcStatus.stored);
      pending = await s.readDtcs(DtcStatus.pending);
      monitor = await s.readMonitorStatus();
      scannedAt = DateTime.now();
      scannedSimulated = connection.isSimulated;
      telemetry.count('dtc.scan', {'count': allCodes.length});
    } on AppException catch (e) {
      error = e.userMessage;
    } finally {
      scanning = false;
      _notify();
    }
  }

  void _onConnection() {
    if (connection.phase == ConnectionPhase.connecting) {
      stored = null;
      pending = null;
      monitor = null;
      scannedAt = null;
      error = null;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    connection.removeListener(_onConnection);
    super.dispose();
  }
}

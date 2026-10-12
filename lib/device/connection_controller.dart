import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/settings/settings_repository.dart';
import '../core/telemetry/diagnostic_log.dart';
import '../core/telemetry/telemetry.dart';
import '../obd/commands/elm_channel.dart';
import '../obd/elm327_session.dart';
import '../transport/ble/ble_elm_transport.dart';
import '../transport/ble/ble_gateway.dart';
import '../transport/obd_transport.dart';
import '../transport/simulated/simulated_transport.dart';
import '../transport/simulated/simulated_vehicle.dart';
import '../transport/wifi/wifi_elm_transport.dart';
import 'discovered_device.dart';

enum ConnectionPhase {
  idle,
  connecting,
  identifying,
  initialising,
  detectingVehicle,
  ready,

  /// Scanner verified, but the vehicle bus did not answer (ignition off).
  noVehicle,
  failed,
  disconnecting,
}

enum ProgressState { pending, running, done, failed, skipped }

class ConnectionStep {
  ConnectionStep(this.title);
  final String title;
  ProgressState state = ProgressState.pending;
  String? detail;
  DateTime? finishedAt;
}

/// Orchestrates: connect transport → identify scanner (ATZ) → initialise
/// (ATE0 ATL0 ATS0 ATH1 ATSP0) → detect vehicle (0100, ATDPN, 0120/0140).
class ConnectionController extends ChangeNotifier {
  ConnectionController({
    required this.gateway,
    required this.settings,
    required this.log,
    required this.telemetry,
    this.overallTimeout = const Duration(seconds: 60),
  });

  final BleGateway gateway;
  final SettingsRepository settings;
  final DiagnosticLog log;
  final Telemetry telemetry;
  final Duration overallTimeout;

  ConnectionPhase phase = ConnectionPhase.idle;
  List<ConnectionStep> steps = [];
  ObdTransport? transport;
  Elm327Session? session;
  AppException? error;
  DateTime? connectedAt;
  SimulationScenario? scenario;

  /// The device that was last attempted (kept after failures for the
  /// developer screen – includes any discovered GATT table).
  TransportDetails? lastDetails;
  bool discoveredByScan = false;

  StreamSubscription<LinkState>? _linkSub;
  int _attempt = 0;
  bool _disposed = false;

  bool get isReady => phase == ConnectionPhase.ready;
  bool get isBusy => const {
    ConnectionPhase.connecting,
    ConnectionPhase.identifying,
    ConnectionPhase.initialising,
    ConnectionPhase.detectingVehicle,
    ConnectionPhase.disconnecting,
  }.contains(phase);
  bool get isLinked => transport?.state == LinkState.connected;
  bool get isSimulated => transport?.kind == TransportKind.simulated;
  TransportDetails? get details => transport?.details ?? lastDetails;
  ElmChannel? get channel => session?.channel;

  String get statusLabel => switch (phase) {
    ConnectionPhase.idle => 'Not connected',
    ConnectionPhase.connecting => 'Connecting…',
    ConnectionPhase.identifying => 'Identifying scanner…',
    ConnectionPhase.initialising => 'Preparing scanner…',
    ConnectionPhase.detectingVehicle => 'Talking to vehicle…',
    ConnectionPhase.ready => isSimulated ? 'Demo connected' : 'Connected',
    ConnectionPhase.noVehicle => 'Scanner ready · vehicle not responding',
    ConnectionPhase.failed => 'Connection failed',
    ConnectionPhase.disconnecting => 'Disconnecting…',
  };

  // ------------------------------------------------------------ entry points

  Future<void> connectSimulated(SimulationScenario s) {
    scenario = s;
    discoveredByScan = false;
    return _connect(SimulatedTransport(scenario: s));
  }

  Future<void> connectBle(DiscoveredDevice device) {
    scenario = null;
    discoveredByScan = true;
    return _connect(
      BleElmTransport(
        gateway: gateway,
        deviceId: device.id,
        deviceName: device.name,
        log: log,
      ),
    );
  }

  Future<void> connectSavedBle(SavedDevice saved) {
    scenario = null;
    discoveredByScan = false;
    return _connect(
      BleElmTransport(
        gateway: gateway,
        deviceId: saved.id,
        deviceName: saved.name,
        log: log,
      ),
    );
  }

  Future<void> connectWifi(String host, int port) {
    scenario = null;
    discoveredByScan = false;
    return _connect(WifiElmTransport(host: host, port: port, log: log));
  }

  /// Read-only GATT capture of an unknown device for verification.
  Future<List<GattServiceInfo>> inspectDevice(DiscoveredDevice device) async {
    final t = BleElmTransport(
      gateway: gateway,
      deviceId: device.id,
      deviceName: device.name,
      log: log,
    );
    try {
      final services = await t.inspectOnly();
      lastDetails = t.details;
      return services;
    } finally {
      _notify();
    }
  }

  // --------------------------------------------------------------- pipeline

  Future<void> _connect(ObdTransport t) async {
    await disconnect(silent: true);
    final attempt = ++_attempt;
    error = null;
    transport = t;
    lastDetails = t.details;
    steps = [
      ConnectionStep('Connect to scanner'),
      ConnectionStep('Identify scanner'),
      ConnectionStep('Initialise diagnostic session'),
      ConnectionStep('Detect vehicle protocol'),
    ];
    telemetry.count('connect.attempt', {'kind': t.kind.name});
    log.info(LogCategory.connection, 'Connecting via ${t.kind.label}');

    try {
      await _pipeline(t, attempt).timeout(overallTimeout);
    } on TimeoutException {
      if (attempt != _attempt) return;
      await _fail(
        const TransportException(
          TransportFailure.timeout,
          'Connecting took too long. Make sure the IQ is switched on, plugged '
          'in and close to your phone, then try again.',
        ),
      );
    } on AppException catch (e) {
      if (attempt != _attempt) return;
      if (e is ObdException &&
          (e.failure == ObdFailure.unableToConnect ||
              e.failure == ObdFailure.noData) &&
          (session?.isInitialised ?? false)) {
        _markRunning(ProgressState.failed, e.userMessage);
        error = e;
        phase = ConnectionPhase.noVehicle;
        telemetry.count('connect.no_vehicle');
        _notify();
        return;
      }
      await _fail(e);
    } catch (e, st) {
      if (attempt != _attempt) return;
      telemetry.recordError(e, st, context: 'connect');
      await _fail(
        TransportException(
          TransportFailure.connectFailed,
          'Something went wrong while connecting.',
          detail: '$e',
        ),
      );
    }
  }

  Future<void> _pipeline(ObdTransport t, int attempt) async {
    _setPhase(ConnectionPhase.connecting, 0);
    await t.open();
    lastDetails = t.details;
    if (attempt != _attempt) return;
    _linkSub = t.stateChanges.listen(_onLinkState);
    _complete(0, t.details.profileName ?? t.kind.label);

    final s = Elm327Session(
      channel: ElmChannel(transport: t, log: log),
      log: log,
    );
    session = s;

    _setPhase(ConnectionPhase.identifying, 1);
    final id = await s.identify();
    if (attempt != _attempt) return;
    _complete(1, id.banner);

    _setPhase(ConnectionPhase.initialising, 2);
    await s.initialise();
    if (attempt != _attempt) return;
    _complete(
      2,
      s.warnings.isEmpty
          ? 'ATE0 ATL0 ATS0 ATH1 ATSP0'
          : '${s.warnings.length} warning(s)',
    );

    // Remember only real scanners that proved they are ELM327-compatible.
    if (t.kind != TransportKind.simulated) {
      await settings.rememberDevice(
        SavedDevice(
          kind: t.kind,
          id: t.details.deviceId,
          name: t.details.deviceName,
        ),
      );
    }

    await _detectVehicle(attempt);
  }

  Future<void> _detectVehicle(int attempt) async {
    final s = session!;
    _setPhase(ConnectionPhase.detectingVehicle, 3);
    final supported = await s.discoverSupportedPids();
    if (attempt != _attempt) return;
    _complete(
      3,
      '${s.protocol.label} · ${supported.pids.length} values supported',
    );
    phase = ConnectionPhase.ready;
    connectedAt = DateTime.now();
    telemetry.count('connect.success', {'kind': transport!.kind.name});
    log.info(LogCategory.connection, 'Ready');
    _notify();
  }

  /// After "ignition off": try the vehicle again on the same scanner link.
  Future<void> retryVehicleDetection() async {
    if (session == null || !isLinked) return;
    error = null;
    steps[3]
      ..state = ProgressState.pending
      ..detail = null;
    final attempt = _attempt;
    try {
      await _detectVehicle(attempt);
    } on ObdException catch (e) {
      _markRunning(ProgressState.failed, e.userMessage);
      error = e;
      phase = ConnectionPhase.noVehicle;
      _notify();
    } on AppException catch (e) {
      await _fail(e);
    }
  }

  void _onLinkState(LinkState s) {
    if (s != LinkState.disconnected) return;
    if (phase == ConnectionPhase.disconnecting ||
        phase == ConnectionPhase.idle) {
      return;
    }
    log.warn(LogCategory.connection, 'Scanner link dropped');
    telemetry.count('connect.dropped');
    error = const TransportException(
      TransportFailure.disconnected,
      'The scanner disconnected. Check the IQ is still powered and in range.',
    );
    phase = ConnectionPhase.failed;
    _cleanupSession();
    _notify();
  }

  Future<void> disconnect({bool silent = false}) async {
    _attempt++;
    final t = transport;
    if (t == null) {
      if (!silent) {
        phase = ConnectionPhase.idle;
        _notify();
      }
      return;
    }
    phase = ConnectionPhase.disconnecting;
    if (!silent) _notify();
    await _linkSub?.cancel();
    _linkSub = null;
    try {
      await session?.close();
      await t.close();
    } catch (_) {}
    _cleanupSession();
    transport = null;
    phase = ConnectionPhase.idle;
    connectedAt = null;
    _notify();
  }

  Future<void> forgetSavedDevice() => settings.rememberDevice(null);

  // ----------------------------------------------------------------- helpers

  Future<void> _fail(AppException e) async {
    error = e;
    _markRunning(ProgressState.failed, e.userMessage);
    telemetry.count('connect.failed', {'reason': e.runtimeType.toString()});
    log.error(
      LogCategory.connection,
      '${e.userMessage}${e.detail == null ? '' : ' – ${e.detail}'}',
    );
    await _linkSub?.cancel();
    _linkSub = null;
    final t = transport;
    if (t != null) lastDetails = t.details;
    try {
      await session?.close();
      if (t != null && t.state != LinkState.disconnected) await t.close();
    } catch (_) {}
    _cleanupSession();
    transport = null;
    phase = ConnectionPhase.failed;
    _notify();
  }

  void _cleanupSession() {
    session = null;
  }

  void _setPhase(ConnectionPhase p, int stepIndex) {
    phase = p;
    steps[stepIndex].state = ProgressState.running;
    _notify();
  }

  void _complete(int i, String detail) {
    steps[i]
      ..state = ProgressState.done
      ..detail = detail
      ..finishedAt = DateTime.now();
    _notify();
  }

  void _markRunning(ProgressState s, String detail) {
    for (final step in steps) {
      if (step.state == ProgressState.running) {
        step
          ..state = s
          ..detail = detail
          ..finishedAt = DateTime.now();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _linkSub?.cancel();
    transport?.close();
    super.dispose();
  }
}

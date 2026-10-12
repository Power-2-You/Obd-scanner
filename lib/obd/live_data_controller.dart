import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/settings/settings_repository.dart';
import '../core/telemetry/diagnostic_log.dart';
import '../device/connection_controller.dart';
import 'elm327_session.dart';
import 'pids.dart';

/// Polls supported live parameters while the dashboard is active.
class LiveDataController extends ChangeNotifier {
  LiveDataController({
    required this.connection,
    required this.settings,
    required this.log,
  }) {
    connection.addListener(_onConnectionChanged);
  }

  final ConnectionController connection;
  final SettingsRepository settings;
  final DiagnosticLog log;

  static const List<int> intervalsMs = [500, 1000, 2000, 5000];
  static const int historyLength = 60;

  final Map<int, PidReading> readings = {};
  final Map<int, ListQueue<double>> history = {};
  MonitorStatus? monitorStatus;
  double? adapterVoltage;
  bool polling = false;
  String? error;
  DateTime? lastUpdate;
  int cycles = 0;

  int _generation = 0;
  int _consecutiveFailures = 0;
  bool _disposed = false;

  int get intervalMs => settings.pollingIntervalMs;

  /// Dashboard + extra PIDs the vehicle has said it supports.
  List<int> get activePids {
    final s = connection.session?.supported ?? SupportedPids.none;
    return [...Pids.dashboard, ...Pids.extras.where(s.supports)];
  }

  bool isUnsupported(int pid) {
    final s = connection.session?.supported;
    if (s == null) return false;
    return s.knows(pid) && !s.supports(pid);
  }

  Future<void> setInterval(int ms) async {
    await settings.setPollingInterval(ms);
    _notify();
  }

  void start() {
    if (polling || !connection.isReady) return;
    polling = true;
    error = null;
    _consecutiveFailures = 0;
    final gen = ++_generation;
    log.info(LogCategory.decode, 'Live polling started (${intervalMs}ms)');
    _notify();
    unawaited(_loop(gen));
  }

  void stop() {
    if (!polling) return;
    polling = false;
    _generation++;
    log.info(LogCategory.decode, 'Live polling stopped');
    _notify();
  }

  void toggle() => polling ? stop() : start();

  Future<void> _loop(int gen) async {
    while (polling && gen == _generation) {
      final session = connection.session;
      if (session == null || !connection.isReady) break;
      final started = DateTime.now();
      try {
        await _cycle(session, gen);
        _consecutiveFailures = 0;
      } on TransportException catch (e) {
        error = e.userMessage;
        break;
      } on ObdException catch (e) {
        _consecutiveFailures++;
        log.warn(LogCategory.decode, 'Poll failed: ${e.userMessage}');
        if (_consecutiveFailures >= 3) {
          error =
              'Live data paused: the scanner stopped answering. ${e.userMessage}';
          break;
        }
      }
      if (gen != _generation) return;
      cycles++;
      lastUpdate = DateTime.now();
      _notify();
      final elapsed = DateTime.now().difference(started);
      final wait = Duration(milliseconds: intervalMs) - elapsed;
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    if (gen == _generation) {
      polling = false;
      _notify();
    }
  }

  Future<void> _cycle(Elm327Session s, int gen) async {
    for (final pid in activePids) {
      if (gen != _generation) return;
      if (isUnsupported(pid)) {
        readings[pid] = PidReading(
          pid: pid,
          status: ReadingStatus.unsupported,
          time: DateTime.now(),
        );
        continue;
      }
      final r = await s.readPid(pid);
      readings[pid] = r;
      if (r.hasValue) {
        final h = history.putIfAbsent(pid, () => ListQueue<double>());
        h.addLast(r.value!);
        while (h.length > historyLength) {
          h.removeFirst();
        }
      }
    }
    // Slower-changing values every 10th cycle.
    if (cycles % 10 == 0) {
      monitorStatus = await s.readMonitorStatus();
      adapterVoltage = await s.readAdapterVoltage();
    }
  }

  /// One-off refresh used by reports when polling is off.
  Future<void> refreshOnce() async {
    final s = connection.session;
    if (s == null || !connection.isReady) return;
    final gen = _generation;
    await _cycle(s, gen);
    monitorStatus = await s.readMonitorStatus();
    lastUpdate = DateTime.now();
    _notify();
  }

  void _onConnectionChanged() {
    if (!connection.isReady) {
      if (polling) stop();
      if (connection.phase == ConnectionPhase.idle ||
          connection.phase == ConnectionPhase.connecting) {
        readings.clear();
        history.clear();
        monitorStatus = null;
        adapterVoltage = null;
        cycles = 0;
      }
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    connection.removeListener(_onConnectionChanged);
    super.dispose();
  }
}

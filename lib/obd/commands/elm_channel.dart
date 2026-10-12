import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../core/telemetry/diagnostic_log.dart';
import '../../core/telemetry/redactor.dart';
import '../../transport/obd_transport.dart';
import '../parsing/elm_reply.dart';
import '../parsing/response_framer.dart';
import 'command_policy.dart';

/// One command/response exchange, kept for the developer screen.
@immutable
class ExchangeRecord {
  const ExchangeRecord({
    required this.time,
    required this.command,
    required this.response,
    required this.status,
    required this.elapsed,
    this.error,
  });

  final DateTime time;
  final String command;

  /// Redacted raw response.
  final String response;
  final ElmStatus? status;
  final Duration elapsed;
  final String? error;
}

/// Serial command channel to an ELM327-compatible interpreter.
///
/// * Commands are strictly serialised – the ELM327 processes one at a time.
/// * Each command has a timeout. After a timeout the channel resynchronises by
///   waiting briefly for the late prompt before sending anything else, so a
///   late response is never attributed to the next command.
/// * Transient adapter errors (BUS BUSY, STOPPED, …) and timeouts can be
///   retried a bounded number of times.
/// * Every command is checked against [CommandPolicy] and refused unless the
///   transport is a confirmed ELM327 serial channel.
class ElmChannel {
  ElmChannel({
    required this.transport,
    required this.log,
    this.resyncWindow = const Duration(milliseconds: 1500),
    this.historyCapacity = 300,
  }) {
    _sub = transport.incoming.listen(_onBytes);
    _stateSub = transport.stateChanges.listen((s) {
      if (s == LinkState.disconnected) _failPending();
    });
  }

  final ObdTransport transport;
  final DiagnosticLog log;
  final Duration resyncWindow;
  final int historyCapacity;

  final ResponseFramer _framer = ResponseFramer();
  final ListQueue<ExchangeRecord> _history = ListQueue();
  late final StreamSubscription<Uint8List> _sub;
  late final StreamSubscription<LinkState> _stateSub;

  Completer<String>? _pending;
  Completer<void>? _latePrompt;
  bool _awaitingLatePrompt = false;
  Future<void> _tail = Future.value();
  bool _closed = false;

  int commandsSent = 0;
  int timeouts = 0;

  List<ExchangeRecord> get history => List.unmodifiable(_history);

  /// Queues [command]. Completes with the parsed reply, or throws
  /// [ObdException] / [TransportException].
  Future<ElmReply> send(
    String command, {
    Duration timeout = const Duration(seconds: 3),
    int retries = 0,
  }) {
    final result = Completer<ElmReply>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await _sendWithRetries(command, timeout, retries));
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }

  Future<ElmReply> _sendWithRetries(
    String command,
    Duration timeout,
    int retries,
  ) async {
    var attempt = 0;
    while (true) {
      try {
        final reply = await _sendOnce(command, timeout);
        if (reply.status.isTransient && attempt < retries) {
          attempt++;
          log.warn(LogCategory.tx,
              'Retrying $command after ${reply.status.name} (attempt ${attempt + 1})');
          continue;
        }
        return reply;
      } on ObdException catch (e) {
        if (e.failure == ObdFailure.timeout && attempt < retries) {
          attempt++;
          log.warn(LogCategory.tx,
              'Retrying $command after timeout (attempt ${attempt + 1})');
          continue;
        }
        rethrow;
      }
    }
  }

  Future<ElmReply> _sendOnce(String command, Duration timeout) async {
    if (_closed) {
      throw const ObdException(ObdFailure.notReady, 'Scanner session closed.');
    }
    if (!CommandPolicy.isAllowed(command)) {
      log.error(LogCategory.tx, 'BLOCKED by command policy: $command');
      throw ObdException(
        ObdFailure.commandBlocked,
        'This command is not permitted by the app safety policy.',
        detail: command,
      );
    }
    if (!transport.carriesElmSerial) {
      log.error(LogCategory.tx,
          'BLOCKED: transport is not a confirmed ELM327 channel ($command)');
      throw const ObdException(
        ObdFailure.commandBlocked,
        'This device has not been verified as an OBD scanner, so no commands '
        'were sent.',
      );
    }
    if (transport.state != LinkState.connected) {
      throw const ObdException(ObdFailure.notReady, 'Scanner is not connected.');
    }

    if (_awaitingLatePrompt) await _waitForLatePrompt();

    _framer.reset();
    final pending = Completer<String>();
    _pending = pending;
    final started = DateTime.now();
    final sw = Stopwatch()..start();

    log.info(LogCategory.tx, '> $command');
    commandsSent++;
    try {
      await transport.write(Uint8List.fromList(ascii.encode('$command\r')));
    } catch (e) {
      _pending = null;
      _record(started, command, '', null, sw.elapsed, 'write failed: $e');
      throw TransportException(
        TransportFailure.writeFailed,
        'Could not send to the scanner.',
        detail: '$e',
      );
    }

    final String raw;
    try {
      raw = await pending.future.timeout(timeout);
    } on TimeoutException {
      _pending = null;
      _awaitingLatePrompt = true;
      timeouts++;
      log.warn(LogCategory.rx,
          'Timeout after ${timeout.inMilliseconds} ms waiting for $command');
      _record(started, command, _framer.pending, null, sw.elapsed, 'timeout');
      throw ObdException(
        ObdFailure.timeout,
        'The scanner did not respond in time.',
        detail: command,
      );
    }

    final reply = ElmReply.parse(command, raw);
    final shown = Redactor.isSensitiveCommand(command)
        ? '[${reply.lines.length} line(s) – identifying data not logged]'
        : _printable(raw);
    log.info(LogCategory.rx, '< $shown  [${reply.status.name}, '
        '${sw.elapsedMilliseconds} ms]');
    _record(started, command, shown, reply.status, sw.elapsed, null);
    return reply;
  }

  void _onBytes(Uint8List bytes) {
    final responses = _framer.add(bytes);
    if (_framer.overflowed) {
      log.warn(LogCategory.rx, 'Receive buffer overflow – data discarded');
    }
    for (final r in responses) {
      final p = _pending;
      if (p != null && !p.isCompleted) {
        _pending = null;
        p.complete(r);
      } else if (_awaitingLatePrompt) {
        _awaitingLatePrompt = false;
        log.debug(LogCategory.rx, 'Discarded late response: ${_printable(r)}');
        final lp = _latePrompt;
        if (lp != null && !lp.isCompleted) lp.complete();
      } else {
        log.debug(LogCategory.rx, 'Unsolicited data: ${_printable(r)}');
      }
    }
  }

  Future<void> _waitForLatePrompt() async {
    final c = Completer<void>();
    _latePrompt = c;
    try {
      await c.future.timeout(resyncWindow);
    } on TimeoutException {
      log.debug(LogCategory.rx, 'No late prompt; continuing');
    } finally {
      _latePrompt = null;
      _awaitingLatePrompt = false;
    }
  }

  void _failPending() {
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) {
      p.completeError(const TransportException(
        TransportFailure.disconnected,
        'The scanner disconnected.',
      ));
    }
  }

  void _record(
    DateTime time,
    String command,
    String response,
    ElmStatus? status,
    Duration elapsed,
    String? error,
  ) {
    _history.addLast(ExchangeRecord(
      time: time,
      command: command,
      response: Redactor.text(response),
      status: status,
      elapsed: elapsed,
      error: error,
    ));
    while (_history.length > historyCapacity) {
      _history.removeFirst();
    }
  }

  static String _printable(String raw) =>
      raw.replaceAll('\r', '⏎').replaceAll('\n', '').trim();

  Future<void> close() async {
    _closed = true;
    _failPending();
    await _sub.cancel();
    await _stateSub.cancel();
  }
}

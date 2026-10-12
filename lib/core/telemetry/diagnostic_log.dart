import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'redactor.dart';

enum LogLevel { debug, info, warning, error }

enum LogCategory {
  app,
  connection,
  transport,
  tx,
  rx,
  parser,
  decode,
  storage,
  ai,
  error,
}

@immutable
class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.category,
    required this.message,
  });

  final DateTime time;
  final LogLevel level;
  final LogCategory category;

  /// Already redacted.
  final String message;

  String format() {
    final t = time.toIso8601String().substring(11, 23);
    return '$t ${level.name.toUpperCase().padRight(7)} '
        '${category.name.toUpperCase().padRight(10)} $message';
  }
}

/// In-memory ring buffer of connection, protocol and parser events.
///
/// Every message passes through [Redactor] before it is stored, so the log can
/// be shown on the developer screen or exported without leaking personal data.
/// Nothing is uploaded anywhere; export is always an explicit user action.
class DiagnosticLog extends ChangeNotifier {
  DiagnosticLog({this.capacity = 3000, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final int capacity;
  final DateTime Function() _clock;
  final ListQueue<LogEntry> _entries = ListQueue<LogEntry>();
  bool _notifyScheduled = false;

  UnmodifiableListView<LogEntry> get entries => UnmodifiableListView(_entries);

  void log(
    LogCategory category,
    String message, {
    LogLevel level = LogLevel.info,
  }) {
    final entry = LogEntry(
      time: _clock(),
      level: level,
      category: category,
      message: Redactor.text(message),
    );
    _entries.addLast(entry);
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    if (kDebugMode) debugPrint('[MGH] ${entry.format()}');
    _scheduleNotify();
  }

  void info(LogCategory c, String m) => log(c, m);
  void warn(LogCategory c, String m) => log(c, m, level: LogLevel.warning);
  void error(LogCategory c, String m) => log(c, m, level: LogLevel.error);
  void debug(LogCategory c, String m) => log(c, m, level: LogLevel.debug);

  /// Batch listener notifications so high-rate polling does not rebuild the
  /// developer screen for every single frame.
  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (hasListeners) notifyListeners();
    });
  }

  List<LogEntry> where({Set<LogCategory>? categories, LogLevel? minLevel}) {
    return _entries.where((e) {
      if (categories != null && !categories.contains(e.category)) return false;
      if (minLevel != null && e.level.index < minLevel.index) return false;
      return true;
    }).toList();
  }

  String exportText({String? header}) {
    final b = StringBuffer();
    if (header != null) b.writeln(header);
    b.writeln('My Garage Hero IQ – diagnostic log (personal data redacted)');
    b.writeln('Exported ${_clock().toIso8601String()}');
    b.writeln('Entries: ${_entries.length}');
    b.writeln('-' * 60);
    for (final e in _entries) {
      b.writeln(e.format());
    }
    return b.toString();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

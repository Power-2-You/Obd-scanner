import 'package:flutter/foundation.dart';

import 'diagnostic_log.dart';

/// Destination for anonymous operational metrics (crash reporting, connection
/// success rates). The app ships with [NoopTelemetrySink]: nothing leaves the
/// phone. A remote sink (e.g. Sentry or Firebase Crashlytics) can be plugged in
/// later behind a user opt-in without touching the rest of the app.
abstract interface class TelemetrySink {
  void event(String name, Map<String, Object> properties);
  void error(Object error, StackTrace? stack, {String? context});
}

class NoopTelemetrySink implements TelemetrySink {
  const NoopTelemetrySink();
  @override
  void event(String name, Map<String, Object> properties) {}
  @override
  void error(Object error, StackTrace? stack, {String? context}) {}
}

/// Local counters + error funnel. Properties must never contain personal data
/// (no VINs, device identifiers, names or free text from the user).
class Telemetry {
  Telemetry({required this.log, this.sink = const NoopTelemetrySink()});

  final DiagnosticLog log;
  final TelemetrySink sink;
  final Map<String, int> _counters = {};

  Map<String, int> get counters => Map.unmodifiable(_counters);

  void count(String name, [Map<String, Object> properties = const {}]) {
    _counters[name] = (_counters[name] ?? 0) + 1;
    sink.event(name, properties);
  }

  void recordError(Object error, StackTrace? stack, {required String context}) {
    log.error(LogCategory.error, '$context: $error');
    count('error.$context');
    sink.error(error, stack, context: context);
    if (kDebugMode && stack != null) debugPrint(stack.toString());
  }
}

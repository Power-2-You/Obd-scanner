import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/telemetry/diagnostic_log.dart';
import '../dtc/dtc.dart';
import 'commands/elm_channel.dart';
import 'obd_protocol.dart';
import 'parsing/elm_reply.dart';
import 'parsing/frame_parser.dart';
import 'pids.dart';

/// What the scanner said about itself in reply to ATZ.
@immutable
class ScannerIdentity {
  const ScannerIdentity({
    required this.banner,
    required this.family,
    this.version,
  });

  /// Raw identification text, e.g. "ELM327 v1.5".
  final String banner;

  /// ELM327, STN (OBDLink) or unrecognised.
  final String family;
  final String? version;

  bool get recognised => family != 'unrecognised';

  static final RegExp _elm = RegExp(r'ELM ?327\s*v?([0-9.]+[a-z]?)?', caseSensitive: false);
  static final RegExp _stn = RegExp(r'(STN\d{4})\s*v?([0-9.]+)?', caseSensitive: false);

  static ScannerIdentity fromBanner(String banner) {
    final b = banner.trim();
    final stn = _stn.firstMatch(b);
    if (stn != null) {
      return ScannerIdentity(banner: b, family: stn.group(1)!.toUpperCase(), version: stn.group(2));
    }
    if (b.toUpperCase().contains('OBDLINK')) {
      return ScannerIdentity(banner: b, family: 'OBDLink (STN)');
    }
    final elm = _elm.firstMatch(b);
    if (elm != null) {
      return ScannerIdentity(banner: b, family: 'ELM327', version: elm.group(1));
    }
    return ScannerIdentity(banner: b, family: 'unrecognised');
  }
}

enum ReadingStatus { live, unsupported, noData, error }

@immutable
class PidReading {
  const PidReading({
    required this.pid,
    required this.status,
    required this.time,
    this.value,
    this.ecu,
    this.raw,
    this.message,
  });

  final int pid;
  final ReadingStatus status;
  final DateTime time;
  final double? value;
  final String? ecu;
  final String? raw;
  final String? message;

  bool get hasValue => status == ReadingStatus.live && value != null;
}

@immutable
class DtcReadResult {
  const DtcReadResult({
    required this.status,
    required this.codes,
    required this.respondingModules,
    this.problems = const [],
    this.rawStatus,
  });

  final DtcStatus status;
  final List<DiagnosticTroubleCode> codes;

  /// Modules that answered the request (even with zero codes).
  final List<String> respondingModules;
  final List<String> problems;
  final ElmStatus? rawStatus;
}

/// Drives an ELM327-compatible interpreter through identification,
/// initialisation and read-only OBD-II requests.
///
/// Guarantees:
///  * Nothing except `ATZ` is sent until the device identifies itself as an
///    ELM327/STN-compatible interpreter.
///  * No OBD request is sent until initialisation has completed.
///  * Only read-only services are used (see CommandPolicy).
class Elm327Session {
  Elm327Session({required this.channel, required this.log});

  final ElmChannel channel;
  final DiagnosticLog log;

  ScannerIdentity? identity;
  ObdProtocol protocol = ObdProtocol.unknown;
  SupportedPids supported = SupportedPids.none;
  final Map<String, Set<int>> supportedByModule = {};
  final List<String> warnings = [];
  bool _initialised = false;

  bool get isIdentified => identity?.recognised ?? false;
  bool get isInitialised => _initialised;

  // ------------------------------------------------------------ handshake --

  Future<ScannerIdentity> identify() async {
    final reply = await channel.send('ATZ',
        timeout: const Duration(seconds: 6), retries: 1);
    final banner = reply.lines.join(' ');
    final id = ScannerIdentity.fromBanner(banner);
    identity = id;
    if (!id.recognised) {
      log.error(LogCategory.connection,
          'Device did not identify as ELM327/STN: "$banner"');
      throw ObdException(
        ObdFailure.notElmCompatible,
        'This device did not identify itself as an OBD-II scanner, so no '
        'diagnostic commands were sent.',
        detail: banner.isEmpty ? reply.status.name : banner,
      );
    }
    log.info(LogCategory.connection,
        'Scanner identified: ${id.family} ${id.version ?? ''}'.trim());
    return id;
  }

  Future<void> initialise() async {
    if (!isIdentified) {
      throw const ObdException(ObdFailure.notReady,
          'Scanner must be identified before initialisation.');
    }
    // Required settings – failure means the device is not usable.
    await _expectOk('ATE0', required: true);
    // Optional – the parser copes without them, so only warn.
    await _expectOk('ATL0');
    await _expectOk('ATS0');
    await _expectOk('ATH1');
    await _expectOk('ATSP0', required: true);
    _initialised = true;
    log.info(LogCategory.connection, 'Diagnostic session initialised');
  }

  Future<void> _expectOk(String cmd, {bool required = false}) async {
    final r = await channel.send(cmd, retries: 1);
    if (r.hasOkToken) return;
    final msg = '$cmd not acknowledged (${r.status.name}: ${r.raw.trim()})';
    if (required) {
      throw ObdException(ObdFailure.adapterError,
          'The scanner rejected a setup command.', detail: msg);
    }
    warnings.add(msg);
    log.warn(LogCategory.connection, msg);
  }

  // -------------------------------------------------------- capabilities --

  /// Queries supported PIDs (0100, then 0120/0140 when advertised) and the
  /// detected bus protocol. The first request triggers the adapter's
  /// automatic protocol search, which can take several seconds.
  Future<SupportedPids> discoverSupportedPids() async {
    _requireReady();
    final first = await channel.send('0100',
        timeout: const Duration(seconds: 20), retries: 1);
    _throwIfVehicleUnreachable(first);

    final dpn = await channel.send('ATDPN');
    if (dpn.isOk && dpn.lines.isNotEmpty) {
      protocol = ObdProtocol.fromDpn(dpn.lines.first);
    }
    log.info(LogCategory.connection, 'Vehicle protocol: ${protocol.label}');

    var result = _mergeBitmap(SupportedPids.none, 0x00, first);
    const ranges = [0x20, 0x40];
    for (final base in ranges) {
      if (!result.supports(base)) {
        // The vehicle reports no PIDs beyond this point: mark the remaining
        // ranges as known-unsupported instead of probing them.
        for (final rest in ranges.where((r) => r >= base)) {
          result = result.merge(rest, const {});
        }
        break;
      }
      final cmd = '01${base.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      final r = await channel.send(cmd, timeout: const Duration(seconds: 4), retries: 1);
      if (!r.isOk) break;
      result = _mergeBitmap(result, base, r);
    }
    supported = result;
    log.info(LogCategory.decode,
        'Supported PIDs: ${result.pids.map((p) => p.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}');
    return result;
  }

  SupportedPids _mergeBitmap(SupportedPids current, int base, ElmReply reply) {
    final parsed = _parse(reply);
    var merged = current.merge(base, {});
    for (final m in parsed.messages) {
      if (m.data.length >= 6 && m.data[0] == 0x41 && m.data[1] == base) {
        final pids = SupportedPids.decodeBitmap(base, m.data.sublist(2, 6));
        supportedByModule.putIfAbsent(m.ecuLabel, () => {}).addAll(pids);
        merged = merged.merge(base, pids);
      }
    }
    return merged;
  }

  void _throwIfVehicleUnreachable(ElmReply r) {
    switch (r.status) {
      case ElmStatus.ok:
        return;
      case ElmStatus.unableToConnect:
      case ElmStatus.busInitError:
        throw ObdException(ObdFailure.unableToConnect,
            'The scanner could not talk to the vehicle. Turn the ignition on '
            '(or start the engine) and check the OBD plug is fully seated.',
            detail: r.status.description);
      case ElmStatus.noData:
        throw ObdException(ObdFailure.noData,
            'The vehicle did not answer. Turn the ignition on and try again.',
            detail: r.status.description);
      default:
        throw ObdException(ObdFailure.busError,
            'Communication problem with the vehicle.',
            detail: r.status.description);
    }
  }

  // --------------------------------------------------------------- reads --

  Future<PidReading> readPid(int pid) async {
    _requireReady();
    final def = Pids.all[pid];
    final now = DateTime.now();
    if (def == null && pid != Pids.monitorStatus) {
      return PidReading(pid: pid, status: ReadingStatus.unsupported, time: now,
          message: 'Not decoded by this app');
    }
    if (supported.knows(pid) && !supported.supports(pid)) {
      return PidReading(pid: pid, status: ReadingStatus.unsupported, time: now,
          message: 'Vehicle does not report this value');
    }
    final cmd = '01${pid.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final reply = await channel.send(cmd, retries: 1);
    if (reply.status == ElmStatus.noData) {
      return PidReading(pid: pid, status: ReadingStatus.noData, time: now,
          raw: reply.raw, message: 'No module answered');
    }
    if (!reply.isOk) {
      return PidReading(pid: pid, status: ReadingStatus.error, time: now,
          raw: reply.raw, message: reply.status.description);
    }
    final parsed = _parse(reply);
    final bytesNeeded = pid == Pids.monitorStatus ? 4 : def!.dataBytes;
    final candidates = parsed.messages
        .where((m) =>
            m.data.length >= 2 + bytesNeeded &&
            m.data[0] == 0x41 &&
            m.data[1] == pid &&
            !m.partial)
        .toList();
    if (candidates.isEmpty) {
      final negative = parsed.messages.any((m) => m.data.isNotEmpty && m.data[0] == 0x7F);
      log.warn(LogCategory.parser,
          'No valid 41 $pid frame in reply (${parsed.problems.join('; ')})');
      return PidReading(
        pid: pid,
        status: negative ? ReadingStatus.unsupported : ReadingStatus.error,
        time: now,
        raw: reply.raw,
        message: negative ? 'Module rejected the request' : 'Malformed response',
      );
    }
    // Prefer the engine module when several modules answer.
    candidates.sort((a, b) => _ecuRank(a).compareTo(_ecuRank(b)));
    final m = candidates.first;
    final payload = m.data.sublist(2, 2 + bytesNeeded);
    final value = pid == Pids.monitorStatus
        ? MonitorStatus.decode(payload).dtcCount.toDouble()
        : def!.decode(payload);
    log.debug(LogCategory.decode,
        '${def?.shortName ?? 'Monitor status'} = ${value.toStringAsFixed(def?.decimals ?? 0)} ${def?.unit ?? 'DTCs'} (${m.ecuLabel})');
    return PidReading(pid: pid, status: ReadingStatus.live, time: now,
        value: value, ecu: m.ecuLabel, raw: reply.raw);
  }

  /// Reads mode 01 PID 01 – MIL state and number of stored emission DTCs.
  Future<MonitorStatus?> readMonitorStatus() async {
    _requireReady();
    if (supported.knows(Pids.monitorStatus) &&
        !supported.supports(Pids.monitorStatus)) {
      return null;
    }
    final reply = await channel.send('0101', retries: 1);
    if (!reply.isOk) return null;
    final parsed = _parse(reply);
    var total = 0;
    var mil = false;
    var any = false;
    for (final m in parsed.messages) {
      if (m.data.length >= 6 && m.data[0] == 0x41 && m.data[1] == 0x01) {
        final s = MonitorStatus.decode(m.data.sublist(2));
        total += s.dtcCount;
        mil = mil || s.milOn;
        any = true;
      }
    }
    return any ? MonitorStatus(milOn: mil, dtcCount: total) : null;
  }

  Future<DtcReadResult> readDtcs(DtcStatus kind) async {
    _requireReady();
    final (mode, responseService) = switch (kind) {
      DtcStatus.stored => ('03', 0x43),
      DtcStatus.pending => ('07', 0x47),
      DtcStatus.permanent => ('0A', 0x4A),
    };
    final reply = await channel.send(mode,
        timeout: const Duration(seconds: 6), retries: 1);
    if (reply.status == ElmStatus.noData) {
      return DtcReadResult(status: kind, codes: const [],
          respondingModules: const [], rawStatus: reply.status,
          problems: const ['No module answered this request.']);
    }
    if (!reply.isOk) {
      _throwIfVehicleUnreachable(reply);
    }
    final parsed = _parse(reply);
    final codes = <DiagnosticTroubleCode>[];
    final modules = <String>[];
    final problems = [...parsed.problems];
    for (final m in parsed.messages) {
      if (m.data.isEmpty) continue;
      if (m.data[0] == 0x7F) {
        problems.add('${m.ecuLabel} rejected the request (not supported).');
        continue;
      }
      if (m.data[0] != responseService) continue;
      modules.add(m.ecuLabel);
      // CAN responses carry a DTC-count byte after the service byte
      // (length 2 + 2n); legacy responses do not (length 1 + 6k).
      final skip = (m.data.length - 1).isOdd ? 2 : 1;
      if (m.partial) problems.add('Incomplete response from ${m.ecuLabel}.');
      final payload = m.data.length > skip ? m.data.sublist(skip) : const <int>[];
      for (final code in DtcCodec.decodeAll(payload)) {
        final dtc = DiagnosticTroubleCode(
            code: code, status: kind, ecu: m.ecu, ecuLabel: m.ecuLabel);
        if (!codes.contains(dtc)) codes.add(dtc);
      }
    }
    log.info(LogCategory.decode,
        '${kind.label} DTCs: ${codes.isEmpty ? 'none' : codes.map((c) => c.code).join(', ')}');
    return DtcReadResult(status: kind, codes: codes,
        respondingModules: modules, problems: problems, rawStatus: reply.status);
  }

  /// Reads the VIN (mode 09 PID 02). Returns null when unsupported.
  /// The VIN is never written to the diagnostic log.
  Future<String?> readVin() async {
    _requireReady();
    final reply = await channel.send('0902',
        timeout: const Duration(seconds: 6), retries: 1);
    if (!reply.isOk) return null;
    for (final m in _parse(reply).messages) {
      if (m.data.length < 3 || m.data[0] != 0x49 || m.data[1] != 0x02) continue;
      final chars = m.data
          .sublist(2)
          .where((b) => b >= 0x30 && b <= 0x5A)
          .map(String.fromCharCode)
          .join();
      if (chars.length >= 17) {
        final vin = chars.substring(chars.length - 17);
        if (RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(vin)) return vin;
      }
    }
    return null;
  }

  /// Voltage measured by the adapter at OBD pin 16 (battery feed).
  Future<double?> readAdapterVoltage() async {
    final r = await channel.send('ATRV');
    if (!r.isOk || r.lines.isEmpty) return null;
    final m = RegExp(r'(\d{1,2}(?:\.\d{1,2})?)\s*V', caseSensitive: false)
        .firstMatch(r.lines.first);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  // ------------------------------------------------------------- helpers --

  FrameParseResult _parse(ElmReply reply) {
    final parsed = FrameParser.parse(reply.lines, protocol);
    for (final p in parsed.problems) {
      log.warn(LogCategory.parser, p);
    }
    if (reply.corruptLines.isNotEmpty) {
      log.warn(LogCategory.parser,
          'Adapter flagged ${reply.corruptLines.length} corrupt frame(s)');
    }
    return parsed;
  }

  static int _ecuRank(ObdMessage m) => switch (m.ecu) {
        0x7E8 || 0x10 => 0,
        _ => 1,
      };

  void _requireReady() {
    if (!_initialised) {
      throw const ObdException(
          ObdFailure.notReady, 'Diagnostic session is not initialised.');
    }
  }

  Future<void> close() => channel.close();
}

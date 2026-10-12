import 'package:flutter/foundation.dart';

/// Outcome of a single ELM327 command, after echo and status chatter have
/// been removed.
enum ElmStatus {
  ok,
  noData,
  unableToConnect,
  busInitError,
  busError,
  busBusy,
  canError,
  dataError,
  bufferFull,
  stopped,
  unknownCommand,
  adapterAlert,
  adapterError,
  empty,
}

extension ElmStatusText on ElmStatus {
  String get description => switch (this) {
        ElmStatus.ok => 'OK',
        ElmStatus.noData => 'NO DATA – no module answered this request',
        ElmStatus.unableToConnect =>
          'UNABLE TO CONNECT – the scanner could not find a vehicle bus. '
              'Is the ignition on and the OBD plug fully seated?',
        ElmStatus.busInitError =>
          'BUS INIT ERROR – the vehicle did not respond to initialisation',
        ElmStatus.busError => 'BUS ERROR – electrical problem on the OBD bus',
        ElmStatus.busBusy => 'BUS BUSY – too much traffic on the vehicle bus',
        ElmStatus.canError => 'CAN ERROR – CAN bus communication problem',
        ElmStatus.dataError => 'DATA ERROR – corrupted response from vehicle',
        ElmStatus.bufferFull => 'BUFFER FULL – scanner could not keep up',
        ElmStatus.stopped => 'STOPPED – command was interrupted',
        ElmStatus.unknownCommand => '? – scanner did not understand command',
        ElmStatus.adapterAlert => 'Scanner low-power or activity alert',
        ElmStatus.adapterError => 'Scanner internal error',
        ElmStatus.empty => 'Empty response',
      };

  /// Worth retrying once: transient bus or timing conditions.
  bool get isTransient =>
      this == ElmStatus.busBusy ||
      this == ElmStatus.stopped ||
      this == ElmStatus.bufferFull ||
      this == ElmStatus.canError ||
      this == ElmStatus.dataError;
}

@immutable
class ElmReply {
  const ElmReply({
    required this.command,
    required this.raw,
    required this.lines,
    required this.status,
    this.searched = false,
    this.corruptLines = const [],
    this.notes = const [],
  });

  final String command;

  /// Raw text received before the prompt (NULs stripped).
  final String raw;

  /// Payload lines: echo, SEARCHING..., BUS INIT and error lines removed.
  final List<String> lines;
  final ElmStatus status;

  /// The adapter printed SEARCHING... (automatic protocol detection ran).
  final bool searched;

  /// Lines the adapter flagged with `<DATA ERROR` / `<RX ERROR`.
  final List<String> corruptLines;
  final List<String> notes;

  bool get isOk => status == ElmStatus.ok;
  bool get hasOkToken => lines.any((l) => l.toUpperCase() == 'OK');

  static final RegExp _errCode = RegExp(r'^ERR\d{2}$');

  /// Classifies the text an ELM327 returned for [command].
  factory ElmReply.parse(String command, String raw) {
    final cleaned = raw.replaceAll('\u0000', '');
    final normalisedCommand = command.replaceAll(' ', '').toUpperCase();
    final rawLines = cleaned
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final data = <String>[];
    final corrupt = <String>[];
    final notes = <String>[];
    ElmStatus? errorStatus;
    var searched = false;

    void flag(ElmStatus s) => errorStatus ??= s;

    for (final line in rawLines) {
      final upper = line.toUpperCase();
      final compact = upper.replaceAll(' ', '');

      // Echo of the command (echo is on until ATE0 has been processed).
      if (compact == normalisedCommand) continue;

      if (upper.startsWith('SEARCHING')) {
        searched = true;
        continue;
      }
      if (upper.startsWith('BUS INIT')) {
        if (upper.contains('ERROR')) {
          flag(ElmStatus.busInitError);
        } else {
          notes.add(line);
        }
        continue;
      }
      if (upper.endsWith('<DATA ERROR') || upper.endsWith('<RX ERROR')) {
        corrupt.add(line);
        continue;
      }

      final s = _statusForLine(compact);
      if (s != null) {
        flag(s);
        notes.add(line);
        continue;
      }
      if (_errCode.hasMatch(compact)) {
        flag(ElmStatus.adapterError);
        notes.add(line);
        continue;
      }
      data.add(line);
    }

    final ElmStatus status;
    if (data.isNotEmpty) {
      // Some modules answered even if another reported a problem (common
      // with multiple ECUs). Keep the data; the error is kept in notes.
      status = ElmStatus.ok;
    } else if (errorStatus != null) {
      status = errorStatus!;
    } else if (corrupt.isNotEmpty) {
      status = ElmStatus.dataError;
    } else {
      status = ElmStatus.empty;
    }

    return ElmReply(
      command: command,
      raw: cleaned,
      lines: List.unmodifiable(data),
      status: status,
      searched: searched,
      corruptLines: List.unmodifiable(corrupt),
      notes: List.unmodifiable(notes),
    );
  }

  static ElmStatus? _statusForLine(String compact) {
    return switch (compact) {
      'NODATA' => ElmStatus.noData,
      'UNABLETOCONNECT' => ElmStatus.unableToConnect,
      'BUSERROR' || 'FBERROR' => ElmStatus.busError,
      'BUSBUSY' => ElmStatus.busBusy,
      'CANERROR' => ElmStatus.canError,
      'DATAERROR' => ElmStatus.dataError,
      'BUFFERFULL' => ElmStatus.bufferFull,
      'STOPPED' => ElmStatus.stopped,
      '?' => ElmStatus.unknownCommand,
      'ACTALERT' || 'LPALERT' || 'LVRESET' => ElmStatus.adapterAlert,
      'ERROR' => ElmStatus.adapterError,
      _ => null,
    };
  }
}

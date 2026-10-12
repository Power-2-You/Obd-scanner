import '../../obd/obd_protocol.dart';
import 'simulated_vehicle.dart';

/// Byte-accurate emulation of an ELM327 v1.5 interpreter connected to a
/// [SimulatedVehicle]. It produces the same text a real adapter prints
/// (echo, SEARCHING..., headers, ISO-TP frames, legacy checksums, prompts),
/// so the simulator exercises the real parsing pipeline end to end.
class SimulatedElm327 {
  SimulatedElm327({required this.vehicle});

  SimulatedVehicle vehicle;

  static const String banner = 'ELM327 v1.5';

  bool echo = true;
  bool linefeeds = false;
  bool spaces = true;
  bool headers = false;
  int protocolSetting = 0;
  bool protocolEstablished = false;

  void _reset() {
    echo = true;
    linefeeds = false;
    spaces = true;
    headers = false;
    protocolSetting = 0;
    protocolEstablished = false;
  }

  /// Full adapter output for one command line, including the final prompt.
  String process(String line) {
    final cmd = line.trim().toUpperCase().replaceAll(' ', '');
    final eol = linefeeds ? '\r\n' : '\r';
    final out = StringBuffer();
    if (echo) out.write('${line.trim()}$eol');
    final body = respond(cmd);
    for (final l in body) {
      out.write('$l$eol');
    }
    out.write('$eol>');
    return out.toString();
  }

  /// Whether [cmd] makes the adapter search for a protocol (slow).
  bool willSearch(String cmd) {
    final c = cmd.trim().toUpperCase();
    return !c.startsWith('AT') && protocolSetting == 0 && !protocolEstablished;
  }

  List<String> respond(String cmd) {
    if (cmd.isEmpty) return const ['?'];
    if (cmd.startsWith('AT')) return _at(cmd.substring(2));
    if (!RegExp(r'^[0-9A-F]+$').hasMatch(cmd) || cmd.length.isOdd) {
      return const ['?'];
    }
    return _obd(cmd);
  }

  List<String> _at(String a) {
    switch (a) {
      case 'Z':
        _reset();
        return const ['', banner];
      case 'I':
        return const [banner];
      case '@1':
        return const ['OBDII to RS232 Interpreter'];
      case 'RV':
        return ['${vehicle.batteryVoltage.toStringAsFixed(1)}V'];
      case 'DPN':
        if (!protocolEstablished) return [protocolSetting == 0 ? 'A0' : '$protocolSetting'];
        final n = vehicle.protocol.number.toRadixString(16).toUpperCase();
        return [protocolSetting == 0 ? 'A$n' : n];
      case 'DP':
        if (!protocolEstablished) return const ['AUTO'];
        return ['${protocolSetting == 0 ? 'AUTO, ' : ''}${vehicle.protocol.label}'];
    }
    final flag = RegExp(r'^([ELSH])([01])$').firstMatch(a);
    if (flag != null) {
      final on = flag.group(2) == '1';
      switch (flag.group(1)) {
        case 'E':
          echo = on;
        case 'L':
          linefeeds = on;
        case 'S':
          spaces = on;
        case 'H':
          headers = on;
      }
      return const ['OK'];
    }
    final sp = RegExp(r'^SPA?([0-9A-C])$').firstMatch(a);
    if (sp != null) {
      protocolSetting = int.parse(sp.group(1)!, radix: 16);
      protocolEstablished = false;
      return const ['OK'];
    }
    return const ['?'];
  }

  List<String> _obd(String cmd) {
    final lines = <String>[];
    if (protocolSetting == 0 && !protocolEstablished) lines.add('SEARCHING...');
    if (!vehicle.reachable) {
      lines.add('UNABLE TO CONNECT');
      return lines;
    }
    protocolEstablished = true;

    final mode = cmd.substring(0, 2);
    final messages = <(SimulatedEcu, List<List<int>>)>[];

    for (final ecu in vehicle.ecus) {
      final frames = _messageFor(ecu, mode, cmd);
      if (frames != null) messages.add((ecu, frames));
    }
    if (messages.isEmpty) {
      lines.add('NO DATA');
      return lines;
    }
    for (final (ecu, payloads) in messages) {
      for (final p in payloads) {
        lines.addAll(vehicle.protocol.isCan ? _formatCan(ecu, p) : _formatLegacy(ecu, p));
      }
    }
    return lines;
  }

  /// Returns the logical message(s) an ECU sends. For CAN that is one ISO-TP
  /// message; legacy protocols split DTC/VIN data into several frames.
  List<List<int>>? _messageFor(SimulatedEcu ecu, String mode, String cmd) {
    final isCan = vehicle.protocol.isCan;
    switch (mode) {
      case '01':
        if (cmd.length != 4) return null;
        final pid = int.parse(cmd.substring(2), radix: 16);
        final data = vehicle.mode01(ecu, pid);
        return data == null ? null : [[0x41, pid, ...data]];
      case '03':
      case '07':
        final codes = mode == '03' ? ecu.storedDtcs : ecu.pendingDtcs;
        final service = mode == '03' ? 0x43 : 0x47;
        final bytes = [for (final c in codes) ...SimulatedVehicle.encodeDtc(c)];
        if (isCan) return [[service, codes.length, ...bytes]];
        final frames = <List<int>>[];
        for (var i = 0; i < bytes.length || frames.isEmpty; i += 6) {
          final chunk = bytes.length > i
              ? bytes.sublist(i, (i + 6).clamp(0, bytes.length))
              : <int>[];
          frames.add([service, ...chunk, ...List.filled(6 - chunk.length, 0)]);
        }
        return frames;
      case '0A':
        return isCan ? [[0x4A, 0x00]] : null;
      case '09':
        if (cmd == '0900') return [[0x49, 0x00, 0x40, 0x00, 0x00, 0x00]];
        if (cmd != '0902' || ecu != vehicle.ecus.first) return null;
        final vinBytes = vehicle.vin.codeUnits;
        if (isCan) return [[0x49, 0x02, 0x01, ...vinBytes]];
        final padded = [0, 0, 0, ...vinBytes];
        return [
          for (var seq = 1; seq <= 5; seq++)
            [0x49, 0x02, seq, ...padded.sublist((seq - 1) * 4, seq * 4)],
        ];
      default:
        return null;
    }
  }

  String _hex(int b) => b.toRadixString(16).padLeft(2, '0').toUpperCase();
  String _join(Iterable<int> bytes) => bytes.map(_hex).join(spaces ? ' ' : '');

  List<String> _formatCan(SimulatedEcu ecu, List<int> payload) {
    final header = vehicle.protocol.isCan29Bit
        ? '18DAF1${_hex(ecu.legacyAddress)}'
        : ecu.canHeader.toRadixString(16).toUpperCase();
    final sep = spaces ? ' ' : '';

    if (payload.length <= 7) {
      if (!headers) return [_join(payload)];
      final frame = [payload.length, ...payload];
      while (frame.length < 8) {
        frame.add(0x00);
      }
      return ['$header$sep${_join(frame)}'];
    }

    // ISO-TP multi-frame.
    final len = payload.length;
    if (!headers) {
      final out = <String>[len.toRadixString(16).padLeft(3, '0').toUpperCase()];
      out.add('0:$sep${_join(payload.sublist(0, 6))}');
      var idx = 6;
      var seq = 1;
      while (idx < len) {
        final end = (idx + 7).clamp(0, len);
        out.add('${(seq & 0xF).toRadixString(16).toUpperCase()}:$sep${_join(payload.sublist(idx, end))}');
        idx = end;
        seq++;
      }
      return out;
    }
    final out = <String>[];
    out.add('$header$sep${_join([0x10 | (len >> 8), len & 0xFF, ...payload.sublist(0, 6)])}');
    var idx = 6;
    var seq = 1;
    while (idx < len) {
      final end = (idx + 7).clamp(0, len);
      final frame = [0x20 | (seq & 0x0F), ...payload.sublist(idx, end)];
      while (frame.length < 8) {
        frame.add(0x00);
      }
      out.add('$header$sep${_join(frame)}');
      idx = end;
      seq++;
    }
    return out;
  }

  List<String> _formatLegacy(SimulatedEcu ecu, List<int> payload) {
    if (!headers) return [_join(payload)];
    final head = vehicle.protocol == ObdProtocol.j1850Pwm
        ? [0x41, 0x6B, ecu.legacyAddress]
        : [0x48, 0x6B, ecu.legacyAddress];
    final frame = [...head, ...payload];
    final checksum = frame.fold<int>(0, (a, b) => a + b) & 0xFF;
    return [_join([...frame, checksum])];
  }
}

import 'package:flutter/foundation.dart';

import '../obd_protocol.dart';

/// A complete OBD response message from one control module (ECU).
@immutable
class ObdMessage {
  const ObdMessage({
    required this.ecu,
    required this.header,
    required this.data,
    this.partial = false,
  });

  /// Responding module address: CAN 11-bit header (e.g. 0x7E8), the source
  /// byte of a 29-bit header, or the source byte of a legacy header.
  /// -1 when the adapter did not print headers.
  final int ecu;

  /// Header text exactly as printed by the adapter.
  final String header;

  /// Message bytes starting with the response service byte (e.g. 0x41).
  final List<int> data;

  /// True when fewer bytes arrived than the frame/ISO-TP length announced.
  final bool partial;

  String get ecuLabel => describeEcu(ecu, header);

  /// Human label for a module address. These are conventions from
  /// ISO 15765-4 (7E8 = first emissions ECU, usually the engine) – they are
  /// not guaranteed for every vehicle, so the raw address is always shown.
  static String describeEcu(int ecu, String header) {
    if (ecu < 0) return 'Module (address not reported)';
    if (header.length == 3) {
      return switch (ecu) {
        0x7E8 => 'ECU 7E8 (usually engine)',
        0x7E9 => 'ECU 7E9 (usually transmission)',
        _ => 'ECU ${ecu.toRadixString(16).toUpperCase()}',
      };
    }
    final hex = ecu.toRadixString(16).toUpperCase().padLeft(2, '0');
    return switch (ecu) {
      0x10 => 'ECU $hex (usually engine)',
      0x18 => 'ECU $hex (usually transmission)',
      _ => 'ECU $hex',
    };
  }
}

@immutable
class FrameParseResult {
  const FrameParseResult({required this.messages, required this.problems});
  final List<ObdMessage> messages;

  /// Malformed or orphaned frames that were discarded, with reasons.
  final List<String> problems;
}

class _Frame {
  _Frame(this.header, this.ecu, this.bytes);
  final String header;
  final int ecu;
  final List<int> bytes;
}

/// Turns adapter output lines (headers on, spaces optional) into per-ECU
/// messages, reassembling ISO-TP multi-frame CAN responses and multi-frame
/// legacy responses.
class FrameParser {
  const FrameParser._();

  static final RegExp _hexOnly = RegExp(r'^[0-9A-F]+$');
  static final RegExp _headerlessMultiLine = RegExp(r'^([0-9A-F]):([0-9A-F]*)$');

  static FrameParseResult parse(List<String> lines, ObdProtocol protocol) {
    final problems = <String>[];
    final cleaned = <String>[];
    for (final l in lines) {
      final c = l.replaceAll(' ', '').toUpperCase();
      if (c.isEmpty) continue;
      cleaned.add(c);
    }
    if (cleaned.isEmpty) {
      return const FrameParseResult(messages: [], problems: []);
    }

    // Headers-off multi-line format ("014", "0:4902...", "1:...").
    if (cleaned.any((c) => _headerlessMultiLine.hasMatch(c))) {
      return _parseHeaderlessMultiLine(cleaned);
    }

    final hexLines = <String>[];
    for (final c in cleaned) {
      if (_hexOnly.hasMatch(c)) {
        hexLines.add(c);
      } else {
        problems.add('Non-hex line ignored: "$c"');
      }
    }

    if (protocol.isCan || protocol == ObdProtocol.unknown) {
      final effective =
          protocol == ObdProtocol.unknown ? _guessProtocol(hexLines) : protocol;
      if (effective.isCan) {
        return _parseCan(hexLines, effective, problems);
      }
      return _parseLegacy(hexLines, problems);
    }
    return _parseLegacy(hexLines, problems);
  }

  /// Fallback when ATDPN was unavailable: 11-bit CAN lines have an odd number
  /// of hex digits (3-digit header), 29-bit lines start with 18DA.
  static ObdProtocol _guessProtocol(List<String> lines) {
    if (lines.isEmpty) return ObdProtocol.unknown;
    final first = lines.first;
    if (first.length.isOdd) return ObdProtocol.can11x500;
    if (first.startsWith('18DA') && first.length >= 12) {
      return ObdProtocol.can29x500;
    }
    return ObdProtocol.iso9141;
  }

  static List<int>? _hexToBytes(String hex) {
    if (hex.length.isOdd) return null;
    final out = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  // ---------------------------------------------------------------- CAN ----

  static FrameParseResult _parseCan(
    List<String> lines,
    ObdProtocol protocol,
    List<String> problems,
  ) {
    final headerLen = protocol.isCan29Bit ? 8 : 3;
    final frames = <_Frame>[];
    var headerless = false;

    for (final line in lines) {
      // An even-length line on 11-bit CAN means the adapter is not printing
      // headers (ATH1 ignored). Treat the line as a bare single message.
      if (!protocol.isCan29Bit && line.length.isEven) {
        headerless = true;
        final bytes = _hexToBytes(line);
        if (bytes == null || bytes.isEmpty) {
          problems.add('Malformed headerless line: "$line"');
          continue;
        }
        frames.add(_Frame('', -1, bytes));
        continue;
      }
      if (line.length <= headerLen) {
        problems.add('Frame too short: "$line"');
        continue;
      }
      final header = line.substring(0, headerLen);
      final bytes = _hexToBytes(line.substring(headerLen));
      if (bytes == null || bytes.isEmpty) {
        problems.add('Malformed frame payload: "$line"');
        continue;
      }
      final ecu = protocol.isCan29Bit
          ? int.parse(header.substring(6, 8), radix: 16)
          : int.parse(header, radix: 16);
      frames.add(_Frame(header, ecu, bytes));
    }

    if (headerless) {
      return FrameParseResult(
        messages: [
          for (final f in frames)
            if (f.ecu == -1)
              ObdMessage(ecu: -1, header: '', data: List.unmodifiable(f.bytes)),
        ],
        problems: problems,
      );
    }

    // Group by header, keeping arrival order inside each group.
    final groups = <String, List<_Frame>>{};
    for (final f in frames) {
      groups.putIfAbsent(f.header, () => []).add(f);
    }

    final messages = <ObdMessage>[];
    for (final entry in groups.entries) {
      messages.addAll(_assembleIsoTp(entry.value, problems));
    }
    return FrameParseResult(messages: messages, problems: problems);
  }

  /// ISO 15765-2 (ISO-TP) reassembly for one ECU.
  static List<ObdMessage> _assembleIsoTp(
    List<_Frame> frames,
    List<String> problems,
  ) {
    final out = <ObdMessage>[];
    List<int>? multi;
    var expectedLength = 0;
    var nextSeq = 1;
    _Frame? firstFrame;

    void finishMulti() {
      if (multi == null || firstFrame == null) return;
      final partial = multi!.length < expectedLength;
      if (partial) {
        problems.add(
          'Partial multi-frame message from ${firstFrame!.header}: '
          '${multi!.length}/$expectedLength bytes',
        );
      }
      out.add(ObdMessage(
        ecu: firstFrame!.ecu,
        header: firstFrame!.header,
        data: List.unmodifiable(
          partial ? multi! : multi!.sublist(0, expectedLength),
        ),
        partial: partial,
      ));
      multi = null;
      firstFrame = null;
    }

    for (final f in frames) {
      final pci = f.bytes[0];
      final type = pci >> 4;
      switch (type) {
        case 0: // Single frame
          finishMulti();
          final len = pci & 0x0F;
          if (len == 0) {
            problems.add('Single frame with zero length from ${f.header}');
            continue;
          }
          final available = f.bytes.length - 1;
          final partial = available < len;
          if (partial) {
            problems.add(
              'Partial single frame from ${f.header}: $available/$len bytes',
            );
          }
          out.add(ObdMessage(
            ecu: f.ecu,
            header: f.header,
            data: List.unmodifiable(
              f.bytes.sublist(1, 1 + (partial ? available : len)),
            ),
            partial: partial,
          ));
        case 1: // First frame
          finishMulti();
          if (f.bytes.length < 2) {
            problems.add('Truncated first frame from ${f.header}');
            continue;
          }
          expectedLength = ((pci & 0x0F) << 8) | f.bytes[1];
          multi = [...f.bytes.sublist(2)];
          firstFrame = f;
          nextSeq = 1;
        case 2: // Consecutive frame
          if (multi == null) {
            problems.add('Consecutive frame without first frame: ${f.header}');
            continue;
          }
          final seq = pci & 0x0F;
          if (seq != nextSeq) {
            problems.add(
              'Out-of-order consecutive frame from ${f.header} '
              '(expected $nextSeq, got $seq)',
            );
            finishMulti();
            continue;
          }
          multi!.addAll(f.bytes.sublist(1));
          nextSeq = (nextSeq + 1) & 0x0F;
          if (multi!.length >= expectedLength) finishMulti();
        case 3: // Flow control – sent by tester side, ignore if echoed.
          continue;
        default:
          problems.add('Unknown CAN frame type $type from ${f.header}');
      }
    }
    finishMulti();
    return out;
  }

  // ------------------------------------------------------------- Legacy ----

  /// J1850 / ISO 9141 / KWP with headers on: 3 header bytes, data, then a
  /// checksum byte (already verified by the adapter; failures are printed as
  /// `<DATA ERROR`).
  static FrameParseResult _parseLegacy(
    List<String> lines,
    List<String> problems,
  ) {
    final frames = <_Frame>[];
    for (final line in lines) {
      final bytes = _hexToBytes(line);
      if (bytes == null) {
        problems.add('Odd-length legacy frame: "$line"');
        continue;
      }
      if (bytes.length < 5) {
        problems.add('Legacy frame too short: "$line"');
        continue;
      }
      final header = line.substring(0, 6);
      frames.add(_Frame(header, bytes[2], bytes.sublist(3, bytes.length - 1)));
    }

    final byEcu = <int, List<_Frame>>{};
    for (final f in frames) {
      byEcu.putIfAbsent(f.ecu, () => []).add(f);
    }

    final messages = <ObdMessage>[];
    for (final group in byEcu.values) {
      final service = group.first.bytes.first;
      final header = group.first.header;
      final ecu = group.first.ecu;
      if (service == 0x43 || service == 0x47 || service == 0x4A) {
        // DTC responses: up to three codes per frame, concatenate payloads.
        final data = <int>[service];
        for (final f in group) {
          if (f.bytes.first != service) continue;
          data.addAll(f.bytes.sublist(1));
        }
        messages.add(ObdMessage(ecu: ecu, header: header, data: data));
      } else if (service == 0x49 && group.length > 1) {
        // Mode 09 multi-frame: 49 PID SEQ d d d d – order by SEQ.
        final sorted = [...group]
          ..sort((a, b) => (a.bytes.length > 2 ? a.bytes[2] : 0)
              .compareTo(b.bytes.length > 2 ? b.bytes[2] : 0));
        final data = <int>[0x49, sorted.first.bytes[1]];
        for (final f in sorted) {
          if (f.bytes.length > 3) data.addAll(f.bytes.sublist(3));
        }
        messages.add(ObdMessage(ecu: ecu, header: header, data: data));
      } else {
        for (final f in group) {
          messages.add(ObdMessage(
            ecu: f.ecu,
            header: f.header,
            data: List.unmodifiable(f.bytes),
          ));
        }
      }
    }
    return FrameParseResult(messages: messages, problems: problems);
  }

  // ------------------------------------------------------- Headers off ----

  static FrameParseResult _parseHeaderlessMultiLine(List<String> lines) {
    final problems = <String>[];
    var expected = -1;
    final data = <int>[];
    for (final line in lines) {
      final m = _headerlessMultiLine.firstMatch(line);
      if (m == null) {
        if (expected < 0 && _hexOnly.hasMatch(line) && line.length <= 3) {
          expected = int.parse(line, radix: 16);
        } else {
          problems.add('Unexpected line in multi-line response: "$line"');
        }
        continue;
      }
      final bytes = _hexToBytes(m.group(2)!);
      if (bytes == null) {
        problems.add('Malformed multi-line segment: "$line"');
        continue;
      }
      data.addAll(bytes);
    }
    final partial = expected > 0 && data.length < expected;
    final trimmed =
        expected > 0 && data.length > expected ? data.sublist(0, expected) : data;
    return FrameParseResult(
      messages: [
        ObdMessage(ecu: -1, header: '', data: trimmed, partial: partial),
      ],
      problems: problems,
    );
  }
}

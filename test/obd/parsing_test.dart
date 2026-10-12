import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_garage_hero_iq/dtc/dtc.dart';
import 'package:my_garage_hero_iq/obd/obd_protocol.dart';
import 'package:my_garage_hero_iq/obd/parsing/elm_reply.dart';
import 'package:my_garage_hero_iq/obd/parsing/frame_parser.dart';
import 'package:my_garage_hero_iq/obd/parsing/response_framer.dart';
import 'package:my_garage_hero_iq/obd/pids.dart';

import '../fixtures/elm_fixtures.dart';

List<ObdMessage> parse(String raw, String cmd, ObdProtocol p) {
  final reply = ElmReply.parse(cmd, raw);
  return FrameParser.parse(reply.lines, p).messages;
}

void main() {
  group('ResponseFramer', () {
    test('assembles a response split across BLE-sized chunks', () {
      final f = ResponseFramer();
      final bytes = latin1.encode('7E804410C1AF8000000\r\r>');
      final out = <String>[];
      for (var i = 0; i < bytes.length; i += 5) {
        out.addAll(f.add(bytes.sublist(i, (i + 5).clamp(0, bytes.length))));
      }
      expect(out, ['7E804410C1AF8000000\r\r']);
    });

    test('splits two responses delivered in one chunk and keeps remainder', () {
      final f = ResponseFramer();
      final out = f.add(latin1.encode('OK\r\r>ELM327 v1.5\r\r>41 0'));
      expect(out, ['OK\r\r', 'ELM327 v1.5\r\r']);
      expect(f.pending, '41 0');
    });

    test('strips NUL padding bytes some clones emit', () {
      final f = ResponseFramer();
      expect(f.add([0, 0x4F, 0, 0x4B, 0x0D, 0x3E]), ['OK\r']);
    });

    test('drops runaway data without a prompt', () {
      final f = ResponseFramer(maxBufferLength: 16);
      f.add(latin1.encode('A' * 40));
      expect(f.overflowed, isTrue);
      expect(f.pending, isEmpty);
    });
  });

  group('ElmReply classification', () {
    test('removes echo and SEARCHING, keeps data', () {
      final r = ElmReply.parse('0100', ElmFixtures.supportedPidsSearching);
      expect(r.status, ElmStatus.ok);
      expect(r.searched, isTrue);
      expect(r.lines, ['7E8064100BE3FA81300']);
    });

    test('NO DATA', () {
      expect(ElmReply.parse('0142', ElmFixtures.noData).status, ElmStatus.noData);
    });

    test('UNABLE TO CONNECT after SEARCHING', () {
      final r = ElmReply.parse('0100', ElmFixtures.unableToConnect);
      expect(r.status, ElmStatus.unableToConnect);
      expect(r.searched, isTrue);
    });

    test('BUS INIT error', () {
      expect(ElmReply.parse('0100', ElmFixtures.busInitError).status,
          ElmStatus.busInitError);
    });

    test('unknown command', () {
      expect(ElmReply.parse('ATXX', ElmFixtures.unknownCommand).status,
          ElmStatus.unknownCommand);
    });

    test('STOPPED is transient', () {
      final r = ElmReply.parse('010C', ElmFixtures.stopped);
      expect(r.status, ElmStatus.stopped);
      expect(r.status.isTransient, isTrue);
    });

    test('corrupt frames are separated from data', () {
      final r = ElmReply.parse('010C', ElmFixtures.corruptFrame);
      expect(r.lines, isEmpty);
      expect(r.corruptLines, hasLength(1));
      expect(r.status, ElmStatus.dataError);
    });

    test('OK token detected for AT commands with echo', () {
      final r = ElmReply.parse('ATE0', 'ATE0\rOK\r\r');
      expect(r.hasOkToken, isTrue);
    });
  });

  group('FrameParser – CAN 11-bit', () {
    test('single frame with padding', () {
      final m = parse(ElmFixtures.rpm1726, '010C', ObdProtocol.can11x500);
      expect(m, hasLength(1));
      expect(m.first.ecu, 0x7E8);
      expect(m.first.data, [0x41, 0x0C, 0x1A, 0xF8]);
      expect(Pids.all[Pids.rpm]!.decode(m.first.data.sublist(2)), 1726);
    });

    test('spaces on are tolerated', () {
      final m = parse(ElmFixtures.rpmWithSpaces, '010C', ObdProtocol.can11x500);
      expect(m.single.data, [0x41, 0x0C, 0x1A, 0xF8]);
    });

    test('multiple ECUs are kept separate', () {
      final m = parse(ElmFixtures.rpmTwoEcus, '010C', ObdProtocol.can11x500);
      expect(m.map((e) => e.ecu), [0x7E8, 0x7E9]);
      expect(m.first.ecuLabel, contains('engine'));
      expect(m.last.ecuLabel, contains('transmission'));
    });

    test('ISO-TP multi-frame DTC response', () {
      final m = parse(ElmFixtures.dtcsMultiFrame, '03', ObdProtocol.can11x500);
      expect(m.single.data.length, 10);
      expect(m.single.partial, isFalse);
      expect(DtcCodec.decodeAll(m.single.data.sublist(2)),
          ['P0301', 'P0420', 'P0171', 'U0100']);
    });

    test('multi-frame VIN', () {
      final m = parse(ElmFixtures.vinMultiFrame, '0902', ObdProtocol.can11x500);
      final vin = String.fromCharCodes(m.single.data.sublist(3));
      expect(vin, 'MGHDEM00000000001');
    });

    test('partial multi-frame is flagged', () {
      final r = FrameParser.parse(
          ElmReply.parse('0902', ElmFixtures.partialMultiFrame).lines,
          ObdProtocol.can11x500);
      expect(r.messages.single.partial, isTrue);
      expect(r.problems.single, contains('Partial'));
    });

    test('out-of-order consecutive frame is detected', () {
      final r = FrameParser.parse(
          ElmReply.parse('0902', ElmFixtures.outOfOrder).lines,
          ObdProtocol.can11x500);
      expect(r.problems.any((p) => p.contains('Out-of-order')), isTrue);
      expect(r.messages.single.partial, isTrue);
    });

    test('malformed line is reported, not decoded', () {
      final r = FrameParser.parse(
          ElmReply.parse('010C', ElmFixtures.malformedLine).lines,
          ObdProtocol.can11x500);
      expect(r.messages, isEmpty);
      expect(r.problems, isNotEmpty);
    });

    test('headers-off single frame falls back to headerless parsing', () {
      final m = parse('410C1AF8\r\r', '010C', ObdProtocol.can11x500);
      expect(m.single.ecu, -1);
      expect(m.single.data, [0x41, 0x0C, 0x1A, 0xF8]);
    });

    test('headers-off multi-line format', () {
      const raw = '014\r0:490201'
          '4D4748\r1:44454D30303030\r2:30303030303031\r\r';
      final m = parse(raw, '0902', ObdProtocol.can11x500);
      expect(String.fromCharCodes(m.single.data.sublist(3)), 'MGHDEM00000000001');
    });

    test('unknown protocol is inferred from frame shape', () {
      final m = parse(ElmFixtures.rpm1726, '010C', ObdProtocol.unknown);
      expect(m.single.ecu, 0x7E8);
    });
  });

  group('FrameParser – CAN 29-bit', () {
    test('source address taken from header', () {
      final m = parse(ElmFixtures.rpm29Bit, '010C', ObdProtocol.can29x500);
      expect(m.single.ecu, 0x10);
      expect(m.single.header, '18DAF110');
      expect(m.single.data, [0x41, 0x0C, 0x1A, 0xF8]);
    });
  });

  group('FrameParser – legacy', () {
    test('ISO 9141 single frame strips header and checksum', () {
      final m = parse(ElmFixtures.legacyRpm, '010C', ObdProtocol.iso9141);
      expect(m.single.ecu, 0x10);
      expect(m.single.data, [0x41, 0x0C, 0x1A, 0xF8]);
    });

    test('ISO 9141 multi-frame DTCs are concatenated', () {
      final m = parse(ElmFixtures.legacyDtcs, '03', ObdProtocol.iso9141);
      expect(m.single.data.first, 0x43);
      expect(DtcCodec.decodeAll(m.single.data.sublist(1)),
          ['P0301', 'P0420', 'P0171', 'U0100']);
    });
  });

  group('ObdProtocol', () {
    test('parses ATDPN replies', () {
      expect(ObdProtocol.fromDpn('A6'), ObdProtocol.can11x500);
      expect(ObdProtocol.fromDpn('7'), ObdProtocol.can29x500);
      expect(ObdProtocol.fromDpn('A3'), ObdProtocol.iso9141);
      expect(ObdProtocol.fromDpn('AA'), ObdProtocol.j1939);
      expect(ObdProtocol.fromDpn('garbage'), ObdProtocol.unknown);
    });
  });

  group('PID decoding (SAE J1979)', () {
    double d(int pid, List<int> b) => Pids.all[pid]!.decode(b);
    test('formulas', () {
      expect(d(Pids.rpm, [0x0C, 0xD0]), 820);
      expect(d(Pids.speed, [0x64]), 100);
      expect(d(Pids.coolantTemp, [0x7B]), 83);
      expect(d(Pids.coolantTemp, [0x00]), -40);
      expect(d(Pids.engineLoad, [0xFF]), 100);
      expect(d(Pids.throttle, [0x00]), 0);
      expect(d(Pids.moduleVoltage, [0x37, 0x6E]), closeTo(14.19, 0.001));
    });

    test('monitor status', () {
      final s = MonitorStatus.decode([0x83, 0x07, 0x65, 0x00]);
      expect(s.milOn, isTrue);
      expect(s.dtcCount, 3);
    });

    test('supported PID bitmap', () {
      final pids = SupportedPids.decodeBitmap(0x00, [0xBE, 0x3F, 0xA8, 0x13]);
      expect(pids, containsAll([0x01, 0x03, 0x04, 0x05, 0x06, 0x07, 0x0C, 0x0D, 0x11, 0x20]));
      expect(pids.contains(0x02), isFalse);
      expect(pids.contains(0x0A), isFalse);
    });

    test('knows() only answers for queried ranges', () {
      final s = SupportedPids.none.merge(0x00, {0x0C});
      expect(s.knows(0x0C), isTrue);
      expect(s.knows(0x42), isFalse);
      expect(s.supports(0x0D), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:my_garage_hero_iq/dtc/dtc.dart';
import 'package:my_garage_hero_iq/dtc/dtc_database.dart';
import 'package:my_garage_hero_iq/dtc/dtc_guidance.dart';

void main() {
  group('DtcCodec', () {
    test('decodes system letters and digits (SAE J2012 bit layout)', () {
      expect(DtcCodec.decode(0x03, 0x01), 'P0301');
      expect(DtcCodec.decode(0x14, 0x23), 'P1423');
      expect(DtcCodec.decode(0x41, 0x23), 'C0123');
      expect(DtcCodec.decode(0x92, 0x34), 'B1234');
      expect(DtcCodec.decode(0xC1, 0x00), 'U0100');
      expect(DtcCodec.decode(0x2A, 0xBC), 'P2ABC');
    });

    test('0000 filler is skipped', () {
      expect(DtcCodec.decode(0, 0), isNull);
      expect(DtcCodec.decodeAll([0x03, 0x01, 0x00, 0x00, 0x04, 0x20]), [
        'P0301',
        'P0420',
      ]);
    });

    test('generic vs manufacturer-specific', () {
      expect(DtcCodec.definitionTypeOf('P0301'), DtcDefinitionType.generic);
      expect(
        DtcCodec.definitionTypeOf('P1301'),
        DtcDefinitionType.manufacturer,
      );
      expect(DtcCodec.definitionTypeOf('P2135'), DtcDefinitionType.generic);
      expect(
        DtcCodec.definitionTypeOf('P3000'),
        DtcDefinitionType.manufacturer,
      );
      expect(DtcCodec.definitionTypeOf('P3400'), DtcDefinitionType.generic);
      expect(DtcCodec.definitionTypeOf('U0100'), DtcDefinitionType.generic);
      expect(
        DtcCodec.definitionTypeOf('B1234'),
        DtcDefinitionType.manufacturer,
      );
    });

    test('subsystem from third character', () {
      expect(DtcCodec.subsystemOf('P0301'), 'Ignition system or misfire');
      expect(DtcCodec.subsystemOf('P0420'), 'Auxiliary emission controls');
      expect(DtcCodec.subsystemOf('P0700'), 'Transmission');
    });
  });

  group('Descriptions', () {
    test('known generic codes have a description', () {
      const dtc = DiagnosticTroubleCode(
        code: 'P0301',
        status: DtcStatus.stored,
      );
      expect(dtc.description, 'Cylinder 1 Misfire Detected');
      expect(DtcDatabase.size, greaterThan(150));
    });

    test('manufacturer codes are never given a generic description', () {
      const dtc = DiagnosticTroubleCode(
        code: 'P1301',
        status: DtcStatus.stored,
      );
      expect(dtc.description, isNull);
    });

    test('unlisted generic code reports null rather than a guess', () {
      const dtc = DiagnosticTroubleCode(
        code: 'P0999',
        status: DtcStatus.stored,
      );
      expect(dtc.description, isNull);
    });

    test('json round trip', () {
      const dtc = DiagnosticTroubleCode(
        code: 'P0420',
        status: DtcStatus.pending,
        ecu: 0x7E8,
        ecuLabel: 'ECU 7E8',
      );
      expect(DiagnosticTroubleCode.fromJson(dtc.toJson()), dtc);
    });
  });

  group('Guidance', () {
    test('oil pressure is stop-and-inspect', () {
      expect(
        DtcGuidance.forCodeString('P0524').level,
        GuidanceLevel.stopAndInspect,
      );
    });
    test('misfire mentions flashing light', () {
      final g = DtcGuidance.forCodeString('P0302');
      expect(g.level, GuidanceLevel.inspectPromptly);
      expect(g.safetyNote, contains('flashing'));
    });
    test('fuel cap quick check for gross EVAP leak', () {
      expect(
        DtcGuidance.forCodeString('P0455').quickCheck,
        contains('fuel cap'),
      );
      expect(DtcGuidance.forCodeString('P0443').quickCheck, isNull);
    });
    test('every code requires further diagnosis', () {
      for (final c in ['P0420', 'U0100', 'B1234', 'C0035', 'P1234']) {
        expect(DtcGuidance.forCodeString(c).furtherDiagnosisRequired, isTrue);
      }
    });
  });
}

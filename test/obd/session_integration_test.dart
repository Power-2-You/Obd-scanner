import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_garage_hero_iq/core/errors/app_exception.dart';
import 'package:my_garage_hero_iq/core/telemetry/diagnostic_log.dart';
import 'package:my_garage_hero_iq/dtc/dtc.dart';
import 'package:my_garage_hero_iq/obd/commands/elm_channel.dart';
import 'package:my_garage_hero_iq/obd/elm327_session.dart';
import 'package:my_garage_hero_iq/obd/obd_protocol.dart';
import 'package:my_garage_hero_iq/obd/pids.dart';
import 'package:my_garage_hero_iq/transport/obd_transport.dart';
import 'package:my_garage_hero_iq/transport/simulated/simulated_transport.dart';
import 'package:my_garage_hero_iq/transport/simulated/simulated_vehicle.dart';

final fixedClock = () => DateTime(2026, 1, 1, 9);

Future<(Elm327Session, SimulatedTransport, DiagnosticLog)> openSession(
  SimulationScenario s,
) async {
  final log = DiagnosticLog();
  final t = SimulatedTransport(
    scenario: s,
    latency: Duration.zero,
    searchDelay: Duration.zero,
    clock: fixedClock,
  );
  await t.open();
  final session = Elm327Session(channel: ElmChannel(transport: t, log: log), log: log);
  return (session, t, log);
}

/// Transport that answers with a fixed script, used to model devices that
/// are not ELM327s or that stop answering.
class ScriptedTransport extends BaseTransport {
  ScriptedTransport(this.replies, {this.elm = true});
  final Map<String, String?> replies;
  final bool elm;
  final List<String> written = [];

  @override
  TransportKind get kind => TransportKind.bleElm327;
  @override
  TransportDetails get details => const TransportDetails(
      kind: TransportKind.bleElm327, deviceId: 'x', deviceName: 'scripted');
  @override
  bool get carriesElmSerial => elm && state == LinkState.connected;
  @override
  Future<void> open({Duration timeout = Duration.zero}) async =>
      setState(LinkState.connected);
  @override
  Future<void> close() async => setState(LinkState.disconnected);
  void inject(String text) => emit(Uint8List.fromList(latin1.encode(text)));

  @override
  Future<void> write(Uint8List data) async {
    final cmd = latin1.decode(data).trim();
    written.add(cmd);
    final r = replies[cmd];
    if (r != null) scheduleMicrotask(() => emit(Uint8List.fromList(latin1.encode(r))));
  }
}

void main() {
  group('Simulated scanner end to end (real channel, framer, parser)', () {
    test('milestone sequence: identify → init → supported PIDs → RPM', () async {
      final (s, _, log) = await openSession(SimulationScenario.healthyDriving);
      final id = await s.identify();
      expect(id.family, 'ELM327');
      expect(id.version, '1.5');
      await s.initialise();
      final supported = await s.discoverSupportedPids();
      expect(s.protocol, ObdProtocol.can11x500);
      expect(supported.supports(Pids.rpm), isTrue);
      expect(supported.supports(Pids.moduleVoltage), isTrue);
      final rpm = await s.readPid(Pids.rpm);
      expect(rpm.status, ReadingStatus.live);
      expect(rpm.value, 820); // deterministic with fixed clock
      expect(rpm.ecu, contains('7E8'));
      expect(log.entries.where((e) => e.category == LogCategory.tx), isNotEmpty);
    });

    test('dashboard PIDs decode within physical ranges', () async {
      final (s, _, _) = await openSession(SimulationScenario.healthyDriving);
      await s.identify();
      await s.initialise();
      await s.discoverSupportedPids();
      for (final pid in Pids.dashboard) {
        final r = await s.readPid(pid);
        final def = Pids.all[pid]!;
        expect(r.status, ReadingStatus.live, reason: def.name);
        expect(r.value, inInclusiveRange(def.min, def.max), reason: def.name);
      }
    });

    test('stored and pending DTCs with source module', () async {
      final (s, _, _) = await openSession(SimulationScenario.checkEngine);
      await s.identify();
      await s.initialise();
      await s.discoverSupportedPids();
      final stored = await s.readDtcs(DtcStatus.stored);
      expect(stored.codes.map((c) => c.code), ['P0301', 'P0420', 'P0171']);
      expect(stored.codes.first.ecuLabel, contains('7E8'));
      final pending = await s.readDtcs(DtcStatus.pending);
      expect(pending.codes.map((c) => c.code), ['P0302']);
      final monitor = await s.readMonitorStatus();
      expect(monitor!.milOn, isTrue);
      expect(monitor.dtcCount, 3);
    });

    test('multiple modules: codes from both, unsupported voltage', () async {
      final (s, _, _) = await openSession(SimulationScenario.multiModule);
      await s.identify();
      await s.initialise();
      await s.discoverSupportedPids();
      expect(s.supportedByModule.keys, hasLength(2));
      final v = await s.readPid(Pids.moduleVoltage);
      expect(v.status, ReadingStatus.unsupported);
      expect(v.value, isNull);
      final dtcs = await s.readDtcs(DtcStatus.stored);
      expect(dtcs.codes.map((c) => c.code).toSet(), {'P0128', 'P0715'});
      expect(dtcs.respondingModules, hasLength(2));
    });

    test('legacy ISO 9141 vehicle', () async {
      final (s, _, _) = await openSession(SimulationScenario.legacyIso9141);
      await s.identify();
      await s.initialise();
      await s.discoverSupportedPids();
      expect(s.protocol, ObdProtocol.iso9141);
      final rpm = await s.readPid(Pids.rpm);
      expect(rpm.value, 760);
      final dtcs = await s.readDtcs(DtcStatus.stored);
      expect(dtcs.codes.map((c) => c.code), ['P0442']);
      final v = await s.readPid(Pids.moduleVoltage);
      expect(v.status, ReadingStatus.unsupported);
    });

    test('VIN is read but never logged', () async {
      final (s, _, log) = await openSession(SimulationScenario.healthyDriving);
      await s.identify();
      await s.initialise();
      await s.discoverSupportedPids();
      final vin = await s.readVin();
      expect(vin, 'MGHDEM00000000001');
      final allText = log.entries.map((e) => e.message).join('\n');
      expect(allText.contains('MGHDEM00000000001'), isFalse);
      expect(allText.contains('4D474844454D'), isFalse); // hex-encoded VIN
    });

    test('ignition off → UNABLE TO CONNECT surfaces as typed error', () async {
      final (s, _, _) = await openSession(SimulationScenario.ignitionOff);
      await s.identify();
      await s.initialise();
      await expectLater(
        s.discoverSupportedPids(),
        throwsA(isA<ObdException>()
            .having((e) => e.failure, 'failure', ObdFailure.unableToConnect)),
      );
    });

    test('OBD requests are refused before initialisation', () async {
      final (s, _, _) = await openSession(SimulationScenario.healthyDriving);
      expect(() => s.readPid(Pids.rpm), throwsA(isA<ObdException>()));
    });
  });

  group('Safety gates', () {
    test('non-ELM device: only ATZ is sent, then session refuses', () async {
      final t = ScriptedTransport({'ATZ': 'HELLO FROM PUMP\r\r>'});
      await t.open();
      final log = DiagnosticLog();
      final s = Elm327Session(channel: ElmChannel(transport: t, log: log), log: log);
      await expectLater(
        s.identify(),
        throwsA(isA<ObdException>()
            .having((e) => e.failure, 'failure', ObdFailure.notElmCompatible)),
      );
      expect(() => s.initialise(), throwsA(isA<ObdException>()));
      expect(t.written, ['ATZ']);
    });

    test('unverified transport: nothing is written at all', () async {
      final t = ScriptedTransport({'ATZ': 'ELM327 v1.5\r\r>'}, elm: false);
      await t.open();
      final log = DiagnosticLog();
      final ch = ElmChannel(transport: t, log: log);
      await expectLater(ch.send('ATZ'), throwsA(isA<ObdException>()));
      expect(t.written, isEmpty);
    });

    test('blocked command never reaches the transport', () async {
      final t = ScriptedTransport({});
      await t.open();
      final ch = ElmChannel(transport: t, log: DiagnosticLog());
      await expectLater(
        ch.send('04'),
        throwsA(isA<ObdException>()
            .having((e) => e.failure, 'failure', ObdFailure.commandBlocked)),
      );
      expect(t.written, isEmpty);
    });
  });

  group('Timeouts and resynchronisation', () {
    test('timeout is retried, then the late reply is not misattributed', () async {
      final t = ScriptedTransport({'ATRV': null, 'ATI': 'ELM327 v1.5\r\r>'});
      await t.open();
      final ch = ElmChannel(
        transport: t,
        log: DiagnosticLog(),
        resyncWindow: const Duration(milliseconds: 50),
      );
      await expectLater(
        ch.send('ATRV', timeout: const Duration(milliseconds: 30), retries: 1),
        throwsA(isA<ObdException>()
            .having((e) => e.failure, 'failure', ObdFailure.timeout)),
      );
      expect(t.written, ['ATRV', 'ATRV']);
      expect(ch.timeouts, 2);
      // A stale prompt arrives late; the next command must not consume it.
      t.inject('12.4V\r\r>');
      final r = await ch.send('ATI');
      expect(r.lines, ['ELM327 v1.5']);
    });

    test('disconnect fails the pending command', () async {
      final t = ScriptedTransport({'0100': null});
      await t.open();
      final ch = ElmChannel(transport: t, log: DiagnosticLog());
      final f = ch.send('0100', timeout: const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      await t.close();
      await expectLater(f, throwsA(isA<TransportException>()));
    });
  });
}

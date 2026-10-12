import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_garage_hero_iq/core/errors/app_exception.dart';
import 'package:my_garage_hero_iq/core/telemetry/diagnostic_log.dart';
import 'package:my_garage_hero_iq/obd/commands/elm_channel.dart';
import 'package:my_garage_hero_iq/obd/elm327_session.dart';
import 'package:my_garage_hero_iq/obd/pids.dart';
import 'package:my_garage_hero_iq/transport/ble/ble_elm_transport.dart';
import 'package:my_garage_hero_iq/transport/ble/ble_gateway.dart';
import 'package:my_garage_hero_iq/transport/ble/ble_profiles.dart';
import 'package:my_garage_hero_iq/transport/iq/iq_adapter.dart';
import 'package:my_garage_hero_iq/transport/obd_transport.dart';
import 'package:my_garage_hero_iq/transport/simulated/simulated_elm327.dart';
import 'package:my_garage_hero_iq/transport/simulated/simulated_vehicle.dart';

/// Fake radio. A peripheral is a GATT table plus, optionally, an ELM327
/// emulator wired behind the documented write/notify characteristics.
class FakeBleGateway implements BleGateway {
  FakeBleGateway({required this.services, this.elm});

  final List<GattServiceInfo> services;
  final SimulatedElm327? elm;
  final List<(String, String, String)> writes = [];
  final List<String> subscriptions = [];
  final _values = StreamController<(String, Uint8List)>.broadcast();
  final _conn = StreamController<bool>.broadcast();
  final StringBuffer _line = StringBuffer();
  String? _notifyChar;
  bool connected = false;

  @override
  Future<void> connect(String deviceId, {Duration timeout = Duration.zero}) async {
    connected = true;
    _conn.add(true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    connected = false;
    _conn.add(false);
  }

  @override
  Stream<bool> connectionChanges(String deviceId) => _conn.stream;

  @override
  Future<List<GattServiceInfo>> discoverServices(String deviceId) async => services;

  @override
  Future<void> subscribe(String deviceId, String service, String characteristic,
      {bool indicate = false}) async {
    subscriptions.add(characteristic);
    _notifyChar = characteristic;
  }

  @override
  Stream<Uint8List> values(String deviceId, String characteristic) => _values.stream
      .where((e) => e.$1 == characteristic)
      .map((e) => e.$2);

  @override
  Future<void> write(String deviceId, String service, String characteristic,
      Uint8List value, {bool withoutResponse = false}) async {
    writes.add((service, characteristic, latin1.decode(value)));
    final e = elm;
    if (e == null) return;
    for (final ch in latin1.decode(value).split('')) {
      if (ch != '\r') {
        _line.write(ch);
        continue;
      }
      final out = latin1.encode(e.process(_line.toString()));
      _line.clear();
      scheduleMicrotask(() {
        for (var i = 0; i < out.length; i += 20) {
          _values.add((_notifyChar!, Uint8List.fromList(out.sublist(i, (i + 20).clamp(0, out.length)))));
        }
      });
    }
  }

  // Unused by the transport.
  @override
  Future<BleAvailability> availability() async => BleAvailability.poweredOn;
  @override
  Stream<BleAvailability> get availabilityChanges => const Stream.empty();
  @override
  Future<void> requestPermissions() async {}
  @override
  Stream<BleScanHit> get scanResults => const Stream.empty();
  @override
  Future<void> startScan({List<String> withServices = const []}) async {}
  @override
  Future<void> stopScan() async {}
}

GattServiceInfo svc(String uuid, Map<String, List<String>> chars) => GattServiceInfo(
      uuid: bleUuid(uuid),
      characteristics: [
        for (final e in chars.entries)
          GattCharacteristicInfo(uuid: bleUuid(e.key), properties: e.value),
      ],
    );

void main() {
  final genericAccess = svc('1800', {'2A00': ['read']});

  test('documented FFF0 profile: full session over BLE chunks', () async {
    final gw = FakeBleGateway(
      services: [
        genericAccess,
        svc('FFF0', {'FFF1': ['read', 'notify'], 'FFF2': ['write', 'writeWithoutResponse']}),
      ],
      elm: SimulatedElm327(
        vehicle: SimulatedVehicle.forScenario(SimulationScenario.healthyDriving,
            clock: () => DateTime(2026)),
      ),
    );
    final log = DiagnosticLog();
    final t = BleElmTransport(gateway: gw, deviceId: 'AA:BB:CC:DD:EE:FF', deviceName: 'OBDII', log: log);
    await t.open();
    expect(t.carriesElmSerial, isTrue);
    expect(t.details.profileName, contains('FFF0'));
    expect(gw.subscriptions, [bleUuid('FFF1')]);

    final s = Elm327Session(channel: ElmChannel(transport: t, log: log), log: log);
    await s.identify();
    await s.initialise();
    await s.discoverSupportedPids();
    final rpm = await s.readPid(Pids.rpm);
    expect(rpm.value, 820);
    // Every write went to the documented write characteristic.
    expect(gw.writes.every((w) => w.$2 == bleUuid('FFF2')), isTrue);
    // Device MAC is masked in logs.
    expect(log.entries.any((e) => e.message.contains('AA:BB:CC:DD:EE:FF')), isFalse);
  });

  test('FFE0 single-characteristic profile is matched', () {
    final m = BleProfiles.match([
      svc('FFE0', {'FFE1': ['read', 'write', 'notify']}),
    ]);
    expect(m.matched, isTrue);
    expect(m.profile!.id, 'ffe0');
  });

  test('profile service present but wrong properties → no match', () {
    final m = BleProfiles.match([
      svc('FFF0', {'FFF1': ['read'], 'FFF2': ['read']}),
    ]);
    expect(m.matched, isFalse);
  });

  test('unknown GATT layout: inspected read-only, never written', () async {
    final gw = FakeBleGateway(services: [
      genericAccess,
      svc('6E400001-B5A3-F393-E0A9-E50E24DCCA9E', {
        '6E400002-B5A3-F393-E0A9-E50E24DCCA9E': ['write'],
        '6E400003-B5A3-F393-E0A9-E50E24DCCA9E': ['notify'],
      }),
    ]);
    final t = BleElmTransport(gateway: gw, deviceId: 'dev', deviceName: 'Mystery', log: DiagnosticLog());
    await expectLater(
      t.open(),
      throwsA(isA<TransportException>()
          .having((e) => e.failure, 'failure', TransportFailure.unsupportedProfile)),
    );
    expect(gw.writes, isEmpty);
    expect(gw.subscriptions, isEmpty);
    expect(gw.connected, isFalse);
    expect(t.details.gattServices, hasLength(2)); // kept for the dev screen
    await expectLater(t.write(Uint8List.fromList([0x41])), throwsA(isA<TransportException>()));
    expect(gw.writes, isEmpty);
  });

  test('inspectOnly never writes', () async {
    final gw = FakeBleGateway(services: [
      svc('FFF0', {'FFF1': ['notify'], 'FFF2': ['write']}),
    ]);
    final t = BleElmTransport(gateway: gw, deviceId: 'dev', deviceName: 'X', log: DiagnosticLog());
    final services = await t.inspectOnly();
    expect(services, hasLength(1));
    expect(gw.writes, isEmpty);
    expect(t.state, LinkState.disconnected);
  });

  test('IQ adapter is unverified and refuses to be used', () {
    expect(IqAdapterSpec.verified, isFalse);
    expect(
      IqAdapterSpec.isIq(const BleScanHit(
          deviceId: 'x', name: 'IQ-1234', rssi: -50, serviceUuids: [], manufacturerIds: [])),
      isFalse,
    );
    expect(IqAdapterSpec.requireVerified, throwsA(isA<TransportException>()));
  });
}

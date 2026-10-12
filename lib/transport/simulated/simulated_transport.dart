import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../obd_transport.dart';
import 'simulated_elm327.dart';
import 'simulated_vehicle.dart';

/// Transport backed by [SimulatedElm327]. Responses are delivered in 20-byte
/// chunks with realistic latency, mimicking BLE notifications, so the framer
/// and command queue are exercised exactly as with real hardware.
class SimulatedTransport extends BaseTransport {
  SimulatedTransport({
    required SimulationScenario scenario,
    this.latency = const Duration(milliseconds: 45),
    this.searchDelay = const Duration(milliseconds: 1200),
    this.chunkSize = 20,
    DateTime Function()? clock,
  }) : device = SimulatedElm327(
          vehicle: SimulatedVehicle.forScenario(scenario, clock: clock),
        );

  final SimulatedElm327 device;
  final Duration latency;
  final Duration searchDelay;
  final int chunkSize;
  final StringBuffer _line = StringBuffer();
  Future<void> _outbox = Future.value();

  static const String simulatedDeviceId = 'SIMULATED-IQ-0001';

  @override
  TransportKind get kind => TransportKind.simulated;

  @override
  TransportDetails get details => TransportDetails(
        kind: TransportKind.simulated,
        deviceId: simulatedDeviceId,
        deviceName: 'Demo IQ (simulated)',
        profileName: 'Simulated ELM327 v1.5 – ${device.vehicle.scenario.title}',
        profileSource: 'Built-in simulator (no hardware)',
      );

  @override
  bool get carriesElmSerial => state == LinkState.connected;

  @override
  Future<void> open({Duration timeout = const Duration(seconds: 10)}) async {
    setState(LinkState.connecting);
    await Future<void>.delayed(latency * 4);
    setState(LinkState.connected);
  }

  @override
  Future<void> write(Uint8List data) async {
    if (state != LinkState.connected) {
      throw StateError('Simulated scanner not connected');
    }
    for (final ch in latin1.decode(data).split('')) {
      if (ch == '\r') {
        final cmd = _line.toString();
        _line.clear();
        _respond(cmd);
      } else {
        _line.write(ch);
      }
    }
  }

  void _respond(String cmd) {
    final slow = device.willSearch(cmd);
    final text = device.process(cmd);
    final bytes = latin1.encode(text);
    _outbox = _outbox.then((_) async {
      await Future<void>.delayed(slow ? searchDelay : latency);
      for (var i = 0; i < bytes.length; i += chunkSize) {
        if (state != LinkState.connected) return;
        final end = (i + chunkSize).clamp(0, bytes.length);
        emit(Uint8List.fromList(bytes.sublist(i, end)));
        if (latency > Duration.zero) await Future<void>.delayed(Duration.zero);
      }
    });
  }

  @override
  Future<void> close() async {
    setState(LinkState.disconnecting);
    await Future<void>.delayed(latency);
    setState(LinkState.disconnected);
  }
}

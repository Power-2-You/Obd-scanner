import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/telemetry/diagnostic_log.dart';
import '../core/telemetry/redactor.dart';
import '../transport/ble/ble_gateway.dart';
import 'discovered_device.dart';

/// Scans for nearby BLE devices and classifies them. Scanning is passive –
/// it only listens to advertisements and never connects or writes.
class DeviceDiscovery extends ChangeNotifier {
  DeviceDiscovery({required this.gateway, required this.log});

  final BleGateway gateway;
  final DiagnosticLog log;

  BleAvailability availability = BleAvailability.unknown;
  bool scanning = false;
  String? error;
  final Map<String, DiscoveredDevice> _devices = {};
  StreamSubscription<BleScanHit>? _sub;
  Timer? _timer;
  bool _disposed = false;

  List<DiscoveredDevice> get devices {
    final list = _devices.values.toList();
    list.sort((a, b) {
      final c = a.compatibility.index.compareTo(b.compatibility.index);
      if (c != 0) return c;
      return (b.rssi ?? -200).compareTo(a.rssi ?? -200);
    });
    return list;
  }

  List<DiscoveredDevice> get candidates => devices
      .where((d) => d.compatibility != DeviceCompatibility.unknown)
      .toList();

  List<DiscoveredDevice> get others => devices
      .where((d) => d.compatibility == DeviceCompatibility.unknown)
      .toList();

  DiscoveredDevice? byId(String id) => _devices[id];

  Future<BleAvailability> refreshAvailability() async {
    try {
      availability = await gateway.availability();
    } catch (e) {
      availability = BleAvailability.unsupported;
    }
    _notify();
    return availability;
  }

  Future<void> start({Duration duration = const Duration(seconds: 12)}) async {
    if (scanning) return;
    error = null;
    try {
      await gateway.requestPermissions();
    } catch (e) {
      error =
          'Bluetooth permission is needed to find your IQ. '
          'Open Settings › My Garage Hero IQ › Bluetooth and allow access.';
      log.warn(LogCategory.connection, 'Bluetooth permission denied: $e');
      availability = BleAvailability.unauthorized;
      _notify();
      return;
    }
    await refreshAvailability();
    if (availability != BleAvailability.poweredOn) {
      error = switch (availability) {
        BleAvailability.poweredOff =>
          'Bluetooth is turned off. Turn it on in Control Centre.',
        BleAvailability.unauthorized => 'Bluetooth access is not allowed. Open Settings › My Garage Hero IQ › Bluetooth.',
        BleAvailability.unsupported =>
          'Bluetooth is not available on this device.',
        _ => 'Bluetooth is not ready yet. Please try again.',
      };
      _notify();
      return;
    }

    _devices.removeWhere(
      (_, d) =>
          DateTime.now().difference(d.lastSeen) > const Duration(minutes: 2),
    );
    scanning = true;
    _notify();
    log.info(LogCategory.connection, 'BLE scan started');
    _sub = gateway.scanResults.listen(_onHit);
    try {
      await gateway.startScan();
    } catch (e) {
      error = 'Could not start scanning: $e';
      await stop();
      return;
    }
    _timer = Timer(duration, stop);
  }

  void _onHit(BleScanHit hit) {
    final isNew = !_devices.containsKey(hit.deviceId);
    final d = DiscoveredDevice.fromScan(hit);
    _devices[hit.deviceId] = d;
    if (isNew) {
      log.debug(
        LogCategory.connection,
        'Found ${d.name} [${Redactor.deviceId(d.id)}] ${d.rssi ?? '?'} dBm – '
        '${d.compatibility.label}',
      );
    }
    _notify();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (!scanning) return;
    scanning = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await gateway.stopScan();
    } catch (_) {}
    log.info(
      LogCategory.connection,
      'BLE scan stopped (${_devices.length} devices)',
    );
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

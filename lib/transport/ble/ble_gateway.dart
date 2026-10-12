import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../obd_transport.dart';

enum BleAvailability {
  unknown,
  unsupported,
  unauthorized,
  poweredOff,
  poweredOn,
  resetting,
}

/// One advertisement seen while scanning.
@immutable
class BleScanHit {
  const BleScanHit({
    required this.deviceId,
    required this.name,
    required this.rssi,
    required this.serviceUuids,
    required this.manufacturerIds,
  });

  final String deviceId;
  final String? name;
  final int? rssi;
  final List<String> serviceUuids;

  /// Bluetooth SIG company identifiers found in manufacturer data.
  final List<int> manufacturerIds;
}

/// Thin seam over the BLE plugin so the transport can be tested with a fake
/// radio. Only read-style operations plus [write] exist; [write] is called
/// exclusively by [BleElmTransport] after a documented profile match.
abstract interface class BleGateway {
  Future<BleAvailability> availability();
  Stream<BleAvailability> get availabilityChanges;
  Future<void> requestPermissions();
  Stream<BleScanHit> get scanResults;
  Future<void> startScan({List<String> withServices});
  Future<void> stopScan();
  Future<void> connect(String deviceId, {Duration timeout});
  Future<void> disconnect(String deviceId);
  Stream<bool> connectionChanges(String deviceId);
  Future<List<GattServiceInfo>> discoverServices(String deviceId);
  Future<void> subscribe(
    String deviceId,
    String service,
    String characteristic, {
    bool indicate,
  });
  Stream<Uint8List> values(String deviceId, String characteristic);
  Future<void> write(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value, {
    bool withoutResponse,
  });
}

/// Production gateway backed by universal_ble (BSD-3-Clause).
class UniversalBleGateway implements BleGateway {
  static BleAvailability _map(AvailabilityState s) => switch (s) {
    AvailabilityState.poweredOn => BleAvailability.poweredOn,
    AvailabilityState.poweredOff => BleAvailability.poweredOff,
    AvailabilityState.unauthorized => BleAvailability.unauthorized,
    AvailabilityState.unsupported => BleAvailability.unsupported,
    AvailabilityState.resetting => BleAvailability.resetting,
    _ => BleAvailability.unknown,
  };

  @override
  Future<BleAvailability> availability() async =>
      _map(await UniversalBle.getBluetoothAvailabilityState());

  @override
  Stream<BleAvailability> get availabilityChanges =>
      UniversalBle.availabilityStream.map(_map);

  @override
  Future<void> requestPermissions() => UniversalBle.requestPermissions();

  @override
  Stream<BleScanHit> get scanResults => UniversalBle.scanStream.map(
    (d) => BleScanHit(
      deviceId: d.deviceId,
      name: d.name,
      rssi: d.rssi,
      serviceUuids: d.services.map((s) => s.toLowerCase()).toList(),
      manufacturerIds: d.manufacturerDataList.map((m) => m.companyId).toList(),
    ),
  );

  @override
  Future<void> startScan({List<String> withServices = const []}) =>
      UniversalBle.startScan(
        scanFilter: withServices.isEmpty
            ? null
            : ScanFilter(withServices: withServices),
      );

  @override
  Future<void> stopScan() => UniversalBle.stopScan();

  @override
  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
  }) => UniversalBle.connect(deviceId, timeout: timeout);

  @override
  Future<void> disconnect(String deviceId) => UniversalBle.disconnect(deviceId);

  @override
  Stream<bool> connectionChanges(String deviceId) =>
      UniversalBle.connectionStream(deviceId);

  @override
  Future<List<GattServiceInfo>> discoverServices(String deviceId) async {
    final services = await UniversalBle.discoverServices(deviceId);
    return [
      for (final s in services)
        GattServiceInfo(
          uuid: s.uuid.toLowerCase(),
          characteristics: [
            for (final c in s.characteristics)
              GattCharacteristicInfo(
                uuid: c.uuid.toLowerCase(),
                properties: c.properties.map((p) => p.name).toList(),
              ),
          ],
        ),
    ];
  }

  @override
  Future<void> subscribe(
    String deviceId,
    String service,
    String characteristic, {
    bool indicate = false,
  }) {
    return indicate
        ? UniversalBle.subscribeIndications(deviceId, service, characteristic)
        : UniversalBle.subscribeNotifications(
            deviceId,
            service,
            characteristic,
          );
  }

  @override
  Stream<Uint8List> values(String deviceId, String characteristic) =>
      UniversalBle.characteristicValueStream(deviceId, characteristic);

  @override
  Future<void> write(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value, {
    bool withoutResponse = false,
  }) {
    return UniversalBle.write(
      deviceId,
      service,
      characteristic,
      value,
      withoutResponse: withoutResponse,
    );
  }
}

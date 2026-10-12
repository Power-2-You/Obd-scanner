import 'package:flutter/foundation.dart';

import '../obd_transport.dart';

/// Expands a 16-bit Bluetooth SIG-style UUID to the 128-bit lowercase form
/// used by universal_ble.
String bleUuid(String short) {
  final s = short.toLowerCase();
  if (s.length == 4) return '0000$s-0000-1000-8000-00805f9b34fb';
  if (s.length == 8) return '$s-0000-1000-8000-00805f9b34fb';
  return s;
}

String shortUuid(String uuid) {
  final u = uuid.toLowerCase();
  if (u.length == 36 && u.endsWith('-0000-1000-8000-00805f9b34fb') && u.startsWith('0000')) {
    return u.substring(4, 8).toUpperCase();
  }
  return u.toUpperCase();
}

/// A documented BLE serial ("UART") layout used by ELM327-compatible adapters.
///
/// The app writes ONLY to the [writeUuid] of a matched profile, and only after
/// the device has identified itself as ELM327/STN in reply to `ATZ`. Devices
/// that match no documented profile are inspected read-only (service
/// discovery) and never written to.
@immutable
class BleSerialProfile {
  const BleSerialProfile({
    required this.id,
    required this.name,
    required this.service,
    required this.notify,
    required this.write,
    required this.source,
    required this.notes,
  });

  final String id;
  final String name;
  final String service;
  final String notify;
  final String write;
  final String source;
  final String notes;

  String get serviceUuid => bleUuid(service);
  String get notifyUuid => bleUuid(notify);
  String get writeUuid => bleUuid(write);
}

class BleProfiles {
  const BleProfiles._();

  static const String _swiftObd2 =
      'SwiftOBD2 (MIT) – Sources/SwiftOBD2/Communication/BLE/'
      'BLEConnection.swift & BLECharacteristicHandler.swift, '
      'github.com/kkonteh97/SwiftOBD2';

  /// Profiles documented in the open-source SwiftOBD2 library that the
  /// referenced SwiftOBD2App uses on iOS. None of these has been confirmed on
  /// the Boost N' Inflate IQ yet.
  static const List<BleSerialProfile> documented = [
    BleSerialProfile(
      id: 'fff0',
      name: 'ELM327 BLE (FFF0 / FFF1 notify / FFF2 write)',
      service: 'FFF0',
      notify: 'FFF1',
      write: 'FFF2',
      source: _swiftObd2,
      notes: 'Common layout on generic ELM327 BLE adapters.',
    ),
    BleSerialProfile(
      id: 'ffe0',
      name: 'ELM327 BLE (FFE0 / FFE1 notify+write)',
      service: 'FFE0',
      notify: 'FFE1',
      write: 'FFE1',
      source: _swiftObd2,
      notes: 'Single characteristic used for both directions.',
    ),
    BleSerialProfile(
      id: '18f0',
      name: 'ELM327 BLE (18F0 / 2AF0 notify / 2AF1 write)',
      service: '18F0',
      notify: '2AF0',
      write: '2AF1',
      source: _swiftObd2,
      notes: 'Documented in SwiftOBD2 as used by e.g. Vgate iCar Pro.',
    ),
  ];

  static List<String> get serviceUuids =>
      documented.map((p) => p.serviceUuid).toList();

  /// Result of matching a discovered GATT table against documented profiles.
  static ProfileMatch match(List<GattServiceInfo> services) {
    for (final profile in documented) {
      final service = services.where((s) => s.uuid.toLowerCase() == profile.serviceUuid);
      if (service.isEmpty) continue;
      final chars = service.first.characteristics;
      final notify = chars.where((c) => c.uuid.toLowerCase() == profile.notifyUuid);
      final write = chars.where((c) => c.uuid.toLowerCase() == profile.writeUuid);
      if (notify.isEmpty || write.isEmpty) continue;
      final canNotify = notify.first.properties.any((p) => p == 'notify' || p == 'indicate');
      final canWrite = write.first.properties.any((p) => p == 'write' || p == 'writeWithoutResponse');
      if (!canNotify || !canWrite) continue;
      return ProfileMatch(
        profile: profile,
        useIndicate: !notify.first.properties.contains('notify'),
        writeWithoutResponse: !write.first.properties.contains('write'),
      );
    }
    return const ProfileMatch(profile: null);
  }
}

@immutable
class ProfileMatch {
  const ProfileMatch({
    required this.profile,
    this.useIndicate = false,
    this.writeWithoutResponse = false,
  });
  final BleSerialProfile? profile;
  final bool useIndicate;
  final bool writeWithoutResponse;
  bool get matched => profile != null;
}

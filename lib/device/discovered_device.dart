import 'package:flutter/foundation.dart';

import '../transport/ble/ble_gateway.dart';
import '../transport/ble/ble_profiles.dart';
import '../transport/iq/iq_adapter.dart';

enum DeviceCompatibility {
  /// Advertises a documented ELM327 BLE service UUID.
  documentedProfile('Standard OBD Bluetooth profile'),

  /// Name suggests an OBD scanner, but no documented service is advertised.
  /// Many adapters only reveal their services after connecting.
  likelyScanner('Possible OBD scanner'),

  /// Positively identified as a Boost N' Inflate IQ (requires verified spec).
  iq('Boost N\' Inflate IQ'),

  unknown('Other Bluetooth device');

  const DeviceCompatibility(this.label);
  final String label;
}

@immutable
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.compatibility,
    required this.serviceUuids,
    required this.manufacturerIds,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final int? rssi;
  final DeviceCompatibility compatibility;
  final List<String> serviceUuids;
  final List<int> manufacturerIds;
  final DateTime lastSeen;

  bool get hasName => name.isNotEmpty && name != 'Unnamed device';

  /// 0-4 bars from RSSI.
  int get signalBars {
    final r = rssi;
    if (r == null) return 0;
    if (r >= -60) return 4;
    if (r >= -70) return 3;
    if (r >= -80) return 2;
    if (r >= -90) return 1;
    return 0;
  }

  static DiscoveredDevice fromScan(BleScanHit hit) {
    final documented = BleProfiles.serviceUuids.toSet();
    final DeviceCompatibility c;
    if (IqAdapterSpec.isIq(hit)) {
      c = DeviceCompatibility.iq;
    } else if (hit.serviceUuids.any(
      (u) => documented.contains(u.toLowerCase()),
    )) {
      c = DeviceCompatibility.documentedProfile;
    } else if (ScannerNameHints.looksLikeScanner(hit.name)) {
      c = DeviceCompatibility.likelyScanner;
    } else {
      c = DeviceCompatibility.unknown;
    }
    return DiscoveredDevice(
      id: hit.deviceId,
      name: (hit.name == null || hit.name!.isEmpty)
          ? 'Unnamed device'
          : hit.name!,
      rssi: hit.rssi,
      compatibility: c,
      serviceUuids: hit.serviceUuids,
      manufacturerIds: hit.manufacturerIds,
      lastSeen: DateTime.now(),
    );
  }
}

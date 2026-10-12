import 'dart:convert';

import '../../core/config/app_config.dart';
import '../../core/telemetry/redactor.dart';
import '../../device/connection_controller.dart';
import '../../device/device_discovery.dart';
import '../../transport/ble/ble_profiles.dart';
import '../../transport/iq/iq_adapter.dart';

/// Builds the "hardware verification report" the user shares so the IQ's
/// communication details can be confirmed. Contains no personal data:
/// device ids are masked and no VIN is included.
class HardwareReport {
  const HardwareReport._();

  static String build(ConnectionController c, DeviceDiscovery d) {
    final details = c.details;
    final s = c.session;
    final map = <String, Object?>{
      'app': 'My Garage Hero IQ ${AppConfig.appVersion}',
      'generatedAt': DateTime.now().toIso8601String(),
      'iqAdapterVerified': IqAdapterSpec.verified,
      'connection': {
        'phase': c.phase.name,
        'transport': details?.kind.name,
        'deviceName': details?.deviceName,
        'deviceIdMasked': details == null
            ? null
            : Redactor.deviceId(details.deviceId),
        'matchedProfile': details?.profileName,
        'serviceUuid': details?.serviceUuid,
        'notifyUuid': details?.notifyUuid,
        'writeUuid': details?.writeUuid,
        'endpoint': details?.endpoint,
        'error': c.error?.userMessage,
        'errorDetail': c.error?.detail,
      },
      'scanner': s == null
          ? null
          : {
              'atzBanner': s.identity?.banner,
              'family': s.identity?.family,
              'version': s.identity?.version,
              'protocol': s.protocol.label,
              'supportedPids': s.supported.pids
                  .map((p) => p.toRadixString(16).padLeft(2, '0').toUpperCase())
                  .toList(),
              'initWarnings': s.warnings,
            },
      'gatt': details?.gattServices
          .map(
            (svc) => {
              'service': shortUuid(svc.uuid),
              'characteristics': svc.characteristics
                  .map(
                    (ch) => {
                      'uuid': shortUuid(ch.uuid),
                      'properties': ch.properties,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'scanResults': d.devices
          .map(
            (dev) => {
              'name': dev.name,
              'idMasked': Redactor.deviceId(dev.id),
              'rssi': dev.rssi,
              'classification': dev.compatibility.name,
              'advertisedServices': dev.serviceUuids.map(shortUuid).toList(),
              'manufacturerCompanyIds': dev.manufacturerIds
                  .map(
                    (i) =>
                        '0x${i.toRadixString(16).padLeft(4, '0').toUpperCase()}',
                  )
                  .toList(),
            },
          )
          .toList(),
      'recentExchanges': c.channel?.history
          .take(40)
          .map(
            (e) => {
              'cmd': e.command,
              'resp': e.response,
              'status': e.status?.name,
              'ms': e.elapsed.inMilliseconds,
              if (e.error != null) 'error': e.error,
            },
          )
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}

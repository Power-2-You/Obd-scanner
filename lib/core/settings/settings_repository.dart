import 'package:flutter/foundation.dart';

import '../../storage/document_store.dart';
import '../../transport/obd_transport.dart';

/// The last scanner that connected AND identified successfully.
@immutable
class SavedDevice {
  const SavedDevice({required this.kind, required this.id, required this.name});
  final TransportKind kind;

  /// BLE device id (iOS: per-app UUID) or host:port for Wi-Fi.
  final String id;
  final String name;

  Map<String, Object> toJson() => {'kind': kind.name, 'id': id, 'name': name};

  static SavedDevice? fromJson(Object? j) {
    if (j is! Map) return null;
    try {
      return SavedDevice(
        kind: TransportKind.values.byName(j['kind'] as String),
        id: j['id'] as String,
        name: j['name'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

class SettingsRepository extends ChangeNotifier {
  SettingsRepository(this._store);

  final DocumentStore _store;
  static const _key = 'settings';

  bool onboardingComplete = false;
  SavedDevice? savedDevice;
  int pollingIntervalMs = 1000;
  String wifiHost = '192.168.0.10';
  int wifiPort = 35000;
  bool loaded = false;

  /// Transient (not persisted): open the connect screen when home appears.
  bool openConnectOnHome = false;

  Future<void> load() async {
    try {
      final j = await _store.read(_key);
      if (j is Map) {
        onboardingComplete = j['onboardingComplete'] == true;
        savedDevice = SavedDevice.fromJson(j['savedDevice']);
        pollingIntervalMs = (j['pollingIntervalMs'] as num?)?.toInt() ?? 1000;
        wifiHost = j['wifiHost'] as String? ?? wifiHost;
        wifiPort = (j['wifiPort'] as num?)?.toInt() ?? wifiPort;
      }
    } catch (_) {
      // Corrupt settings fall back to defaults.
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    await _store.write(_key, {
      'onboardingComplete': onboardingComplete,
      if (savedDevice != null) 'savedDevice': savedDevice!.toJson(),
      'pollingIntervalMs': pollingIntervalMs,
      'wifiHost': wifiHost,
      'wifiPort': wifiPort,
    });
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    onboardingComplete = true;
    await _save();
  }

  Future<void> rememberDevice(SavedDevice? d) async {
    savedDevice = d;
    await _save();
  }

  Future<void> setPollingInterval(int ms) async {
    pollingIntervalMs = ms;
    await _save();
  }

  Future<void> setWifiEndpoint(String host, int port) async {
    wifiHost = host;
    wifiPort = port;
    await _save();
  }
}

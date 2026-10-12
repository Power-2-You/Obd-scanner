import 'dart:async';

import 'package:flutter/foundation.dart';

/// How the phone talks to the scanner hardware.
enum TransportKind {
  /// In-app simulated ELM327 + vehicle. Never presented as real data.
  simulated('Simulated scanner'),

  /// ELM327-compatible adapter over a documented BLE serial (UART) profile.
  bleElm327('Bluetooth LE (ELM327 serial profile)'),

  /// ELM327-compatible adapter over Wi-Fi TCP.
  wifiElm327('Wi-Fi TCP (ELM327)'),

  /// Boost N' Inflate IQ specific adapter – pending protocol verification.
  iq('Boost N\' Inflate IQ adapter');

  const TransportKind(this.label);
  final String label;
}

enum LinkState { disconnected, connecting, connected, disconnecting }

@immutable
class GattCharacteristicInfo {
  const GattCharacteristicInfo({required this.uuid, required this.properties});
  final String uuid;
  final List<String> properties;

  Map<String, Object> toJson() => {'uuid': uuid, 'properties': properties};
}

@immutable
class GattServiceInfo {
  const GattServiceInfo({required this.uuid, required this.characteristics});
  final String uuid;
  final List<GattCharacteristicInfo> characteristics;

  Map<String, Object> toJson() => {
        'uuid': uuid,
        'characteristics': characteristics.map((c) => c.toJson()).toList(),
      };
}

/// Identification details shown on the developer screen.
@immutable
class TransportDetails {
  const TransportDetails({
    required this.kind,
    required this.deviceId,
    required this.deviceName,
    this.profileName,
    this.profileSource,
    this.serviceUuid,
    this.notifyUuid,
    this.writeUuid,
    this.endpoint,
    this.gattServices = const [],
  });

  final TransportKind kind;
  final String deviceId;
  final String deviceName;

  /// Name of the documented profile this link matched, if any.
  final String? profileName;

  /// Where that profile is documented.
  final String? profileSource;
  final String? serviceUuid;
  final String? notifyUuid;
  final String? writeUuid;

  /// host:port for TCP transports.
  final String? endpoint;

  /// Everything discovered on the device (read-only enumeration).
  final List<GattServiceInfo> gattServices;

  TransportDetails copyWith({
    String? profileName,
    String? profileSource,
    String? serviceUuid,
    String? notifyUuid,
    String? writeUuid,
    List<GattServiceInfo>? gattServices,
  }) {
    return TransportDetails(
      kind: kind,
      deviceId: deviceId,
      deviceName: deviceName,
      profileName: profileName ?? this.profileName,
      profileSource: profileSource ?? this.profileSource,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      notifyUuid: notifyUuid ?? this.notifyUuid,
      writeUuid: writeUuid ?? this.writeUuid,
      endpoint: endpoint,
      gattServices: gattServices ?? this.gattServices,
    );
  }
}

/// Byte pipe between the app and a scanner.
///
/// A transport only moves bytes. It knows nothing about OBD. The OBD layer
/// checks [carriesElmSerial] before sending any ELM327 command, so a transport
/// that has not matched a documented serial profile can never be written to.
abstract interface class ObdTransport {
  TransportKind get kind;
  TransportDetails get details;
  LinkState get state;
  Stream<LinkState> get stateChanges;

  /// Raw bytes received from the scanner.
  Stream<Uint8List> get incoming;

  /// True only when the open link is a confirmed ELM327-style serial channel
  /// (documented BLE profile, TCP socket to an ELM327 endpoint, or simulator).
  bool get carriesElmSerial;

  Future<void> open({Duration timeout});
  Future<void> write(Uint8List data);
  Future<void> close();
}

/// Shared plumbing for transports.
abstract class BaseTransport implements ObdTransport {
  final StreamController<Uint8List> incomingController =
      StreamController<Uint8List>.broadcast();
  final StreamController<LinkState> _stateController =
      StreamController<LinkState>.broadcast();
  LinkState _state = LinkState.disconnected;

  @override
  LinkState get state => _state;

  @override
  Stream<LinkState> get stateChanges => _stateController.stream;

  @override
  Stream<Uint8List> get incoming => incomingController.stream;

  @protected
  void setState(LinkState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  @protected
  void emit(Uint8List bytes) {
    if (!incomingController.isClosed) incomingController.add(bytes);
  }

  /// Releases stream controllers. Call once the transport is discarded.
  Future<void> dispose() async {
    await incomingController.close();
    await _stateController.close();
  }
}

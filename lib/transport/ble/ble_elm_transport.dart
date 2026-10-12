import 'dart:async';
import 'dart:typed_data';

import '../../core/errors/app_exception.dart';
import '../../core/telemetry/diagnostic_log.dart';
import '../../core/telemetry/redactor.dart';
import '../obd_transport.dart';
import 'ble_gateway.dart';
import 'ble_profiles.dart';

/// ELM327-over-BLE transport.
///
/// Connection procedure:
///  1. Connect to the peripheral.
///  2. Discover services (read-only enumeration – nothing is written).
///  3. Match the GATT table against [BleProfiles.documented].
///  4. Only on a match: subscribe to the documented notify characteristic and
///     allow writes to the documented write characteristic.
///  5. No match: disconnect and report the discovered table so it can be
///     shared for verification. No bytes are ever written.
class BleElmTransport extends BaseTransport {
  BleElmTransport({
    required this.gateway,
    required this.deviceId,
    required this.deviceName,
    required this.log,
    this.mtuPayload = 20,
  }) : _details = TransportDetails(
         kind: TransportKind.bleElm327,
         deviceId: deviceId,
         deviceName: deviceName,
       );

  final BleGateway gateway;
  final String deviceId;
  final String deviceName;
  final DiagnosticLog log;

  /// Conservative write chunk size (default ATT MTU 23 − 3 bytes).
  final int mtuPayload;

  TransportDetails _details;
  ProfileMatch? _match;
  StreamSubscription<Uint8List>? _valueSub;
  StreamSubscription<bool>? _connSub;

  @override
  TransportKind get kind => TransportKind.bleElm327;

  @override
  TransportDetails get details => _details;

  @override
  bool get carriesElmSerial =>
      state == LinkState.connected && (_match?.matched ?? false);

  @override
  Future<void> open({Duration timeout = const Duration(seconds: 15)}) async {
    setState(LinkState.connecting);
    log.info(
      LogCategory.transport,
      'BLE connect → $deviceName [${Redactor.deviceId(deviceId)}]',
    );
    try {
      await gateway.connect(deviceId, timeout: timeout);
    } catch (e) {
      setState(LinkState.disconnected);
      throw TransportException(
        TransportFailure.connectFailed,
        'Could not connect to $deviceName.',
        detail: '$e',
      );
    }
    _connSub = gateway.connectionChanges(deviceId).listen((connected) {
      if (!connected && state != LinkState.disconnected) {
        log.warn(LogCategory.transport, 'BLE link lost');
        _teardown();
      }
    });

    final List<GattServiceInfo> services;
    try {
      services = await gateway.discoverServices(deviceId);
    } catch (e) {
      await _abort();
      throw TransportException(
        TransportFailure.connectFailed,
        'Connected, but could not read the device\'s services.',
        detail: '$e',
      );
    }
    _details = _details.copyWith(gattServices: services);
    for (final s in services) {
      log.info(
        LogCategory.transport,
        'GATT service ${shortUuid(s.uuid)}: '
        '${s.characteristics.map((c) => '${shortUuid(c.uuid)}(${c.properties.join('/')})').join(', ')}',
      );
    }

    final match = BleProfiles.match(services);
    if (!match.matched) {
      log.warn(
        LogCategory.transport,
        'No documented OBD serial profile found – disconnecting without '
        'sending any data.',
      );
      await _abort();
      throw const TransportException(
        TransportFailure.unsupportedProfile,
        'This device does not use a documented OBD-II Bluetooth profile, so '
        'the app did not send it any data. Its service list has been saved '
        'on the Developer screen for verification.',
      );
    }

    final p = match.profile!;
    _match = match;
    _details = _details.copyWith(
      profileName: p.name,
      profileSource: p.source,
      serviceUuid: p.serviceUuid,
      notifyUuid: p.notifyUuid,
      writeUuid: p.writeUuid,
    );
    log.info(LogCategory.transport, 'Matched documented profile: ${p.name}');

    try {
      _valueSub = gateway.values(deviceId, p.notifyUuid).listen(emit);
      await gateway.subscribe(
        deviceId,
        p.serviceUuid,
        p.notifyUuid,
        indicate: match.useIndicate,
      );
    } catch (e) {
      await _abort();
      throw TransportException(
        TransportFailure.connectFailed,
        'Could not subscribe to scanner data.',
        detail: '$e',
      );
    }
    setState(LinkState.connected);
  }

  /// Connects, enumerates the GATT table and disconnects. Never writes.
  /// Used by the developer screen to capture details of unknown hardware.
  Future<List<GattServiceInfo>> inspectOnly({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    setState(LinkState.connecting);
    try {
      await gateway.connect(deviceId, timeout: timeout);
      final services = await gateway.discoverServices(deviceId);
      _details = _details.copyWith(gattServices: services);
      final match = BleProfiles.match(services);
      if (match.matched) {
        _details = _details.copyWith(profileName: match.profile!.name);
      }
      return services;
    } finally {
      await _abort();
    }
  }

  @override
  Future<void> write(Uint8List data) async {
    final m = _match;
    if (m == null || !m.matched || state != LinkState.connected) {
      throw const TransportException(
        TransportFailure.notVerified,
        'Refusing to write: no verified serial characteristic.',
      );
    }
    final p = m.profile!;
    for (var i = 0; i < data.length; i += mtuPayload) {
      final end = (i + mtuPayload).clamp(0, data.length);
      await gateway.write(
        deviceId,
        p.serviceUuid,
        p.writeUuid,
        Uint8List.sublistView(data, i, end),
        withoutResponse: m.writeWithoutResponse,
      );
    }
  }

  Future<void> _abort() async {
    try {
      await gateway.disconnect(deviceId);
    } catch (_) {}
    _teardown();
  }

  void _teardown() {
    _valueSub?.cancel();
    _valueSub = null;
    _connSub?.cancel();
    _connSub = null;
    _match = null;
    setState(LinkState.disconnected);
  }

  @override
  Future<void> close() async {
    setState(LinkState.disconnecting);
    log.info(LogCategory.transport, 'BLE disconnect');
    await _abort();
  }
}

import 'dart:async';
import 'dart:typed_data';

import '../../core/errors/app_exception.dart';
import '../../core/telemetry/diagnostic_log.dart';
import '../obd_transport.dart';
import 'byte_socket.dart';
import 'socket_connector_stub.dart'
    if (dart.library.io) 'socket_connector_io.dart';

/// ELM327 over Wi-Fi (TCP).
///
/// The phone must first join the scanner's Wi-Fi network in iOS Settings.
/// 192.168.0.10:35000 is the default endpoint used by SwiftOBD2's
/// wifiManager.swift and by many ELM327 Wi-Fi adapters; it is NOT verified
/// for the Boost N' Inflate IQ and can be changed on the developer screen.
class WifiElmTransport extends BaseTransport {
  WifiElmTransport({
    required this.host,
    required this.port,
    required this.log,
    SocketConnector? connector,
  }) : _connector = connector ?? platformSocketConnector;

  static const String defaultHost = '192.168.0.10';
  static const int defaultPort = 35000;

  final String host;
  final int port;
  final DiagnosticLog log;
  final SocketConnector _connector;
  ByteSocket? _socket;
  StreamSubscription<Uint8List>? _sub;

  @override
  TransportKind get kind => TransportKind.wifiElm327;

  @override
  TransportDetails get details => TransportDetails(
    kind: TransportKind.wifiElm327,
    deviceId: '$host:$port',
    deviceName: 'Wi-Fi scanner',
    endpoint: '$host:$port',
    profileName: 'ELM327 TCP',
    profileSource:
        'Default endpoint from SwiftOBD2 wifiManager.swift (unverified for IQ)',
  );

  /// A TCP stream to a user-chosen ELM327 endpoint. Identification via ATZ
  /// still has to succeed before any OBD request is sent.
  @override
  bool get carriesElmSerial => state == LinkState.connected;

  @override
  Future<void> open({Duration timeout = const Duration(seconds: 8)}) async {
    setState(LinkState.connecting);
    log.info(LogCategory.transport, 'TCP connect → $host:$port');
    try {
      final socket = await _connector(host, port, timeout);
      _socket = socket;
      _sub = socket.input.listen(
        emit,
        onDone: () {
          log.warn(LogCategory.transport, 'TCP connection closed by scanner');
          _teardown();
        },
        onError: (Object e) {
          log.error(LogCategory.transport, 'TCP error: $e');
          _teardown();
        },
      );
      setState(LinkState.connected);
    } on UnsupportedError catch (e) {
      setState(LinkState.disconnected);
      throw TransportException(
        TransportFailure.bluetoothUnavailable,
        'Wi-Fi scanners are not supported on this platform.',
        detail: '$e',
      );
    } catch (e) {
      setState(LinkState.disconnected);
      throw TransportException(
        TransportFailure.connectFailed,
        'Could not reach a Wi-Fi scanner at $host:$port. Join the scanner\'s '
        'Wi-Fi network in Settings first.',
        detail: '$e',
      );
    }
  }

  @override
  Future<void> write(Uint8List data) async {
    final s = _socket;
    if (s == null || state != LinkState.connected) {
      throw const TransportException(
        TransportFailure.disconnected,
        'Wi-Fi scanner not connected.',
      );
    }
    s.add(data);
    await s.flush();
  }

  void _teardown() {
    _sub?.cancel();
    _sub = null;
    _socket = null;
    setState(LinkState.disconnected);
  }

  @override
  Future<void> close() async {
    setState(LinkState.disconnecting);
    try {
      await _socket?.close();
    } catch (_) {}
    _teardown();
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'byte_socket.dart';

class _IoByteSocket implements ByteSocket {
  _IoByteSocket(this._socket) {
    _socket.setOption(SocketOption.tcpNoDelay, true);
  }
  final Socket _socket;

  @override
  Stream<Uint8List> get input => _socket;

  @override
  void add(Uint8List data) => _socket.add(data);

  @override
  Future<void> flush() => _socket.flush();

  @override
  Future<void> close() async {
    await _socket.close();
    _socket.destroy();
  }
}

Future<ByteSocket> platformSocketConnector(
  String host,
  int port,
  Duration timeout,
) async {
  final s = await Socket.connect(host, port, timeout: timeout);
  return _IoByteSocket(s);
}

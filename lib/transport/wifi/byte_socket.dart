import 'dart:typed_data';

/// Minimal TCP socket seam so the Wi-Fi transport compiles on every platform
/// (dart:io is unavailable on the web preview build).
abstract interface class ByteSocket {
  Stream<Uint8List> get input;
  void add(Uint8List data);
  Future<void> flush();
  Future<void> close();
}

typedef SocketConnector = Future<ByteSocket> Function(
  String host,
  int port,
  Duration timeout,
);

import 'byte_socket.dart';

Future<ByteSocket> platformSocketConnector(
  String host,
  int port,
  Duration timeout,
) {
  throw UnsupportedError('Wi-Fi scanners are not supported on this platform.');
}

/// Typed failures surfaced to the UI. Each carries a short, plain-English
/// [userMessage] and a [detail] string for the developer screen.
sealed class AppException implements Exception {
  const AppException(this.userMessage, {this.detail});

  final String userMessage;
  final String? detail;

  @override
  String toString() =>
      '$runtimeType: $userMessage${detail == null ? '' : ' ($detail)'}';
}

enum TransportFailure {
  bluetoothUnavailable,
  bluetoothOff,
  permissionDenied,
  deviceNotFound,
  connectFailed,
  timeout,
  disconnected,
  unsupportedProfile,
  writeFailed,
  notVerified,
}

class TransportException extends AppException {
  const TransportException(this.failure, super.userMessage, {super.detail});
  final TransportFailure failure;
}

enum ObdFailure {
  timeout,
  noData,
  unableToConnect,
  notElmCompatible,
  busError,
  malformedResponse,
  unsupported,
  notReady,
  adapterError,
  commandBlocked,
}

class ObdException extends AppException {
  const ObdException(this.failure, super.userMessage, {super.detail});
  final ObdFailure failure;
}

enum AiFailure { notConfigured, network, server, rateLimited, invalidResponse }

class AiException extends AppException {
  const AiException(this.failure, super.userMessage, {super.detail});
  final AiFailure failure;
}

class StorageException extends AppException {
  const StorageException(super.userMessage, {super.detail});
}

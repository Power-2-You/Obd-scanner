import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import 'ai_models.dart';

/// AI diagnostic assistant. Implementations must never call an AI provider
/// directly from the device – requests go through the backend proxy, which
/// holds the provider key.
abstract interface class AiMechanicService {
  bool get isConfigured;
  Future<AiMechanicAnswer> ask(AiMechanicRequest request);
}

class UnconfiguredAiMechanicService implements AiMechanicService {
  const UnconfiguredAiMechanicService();
  @override
  bool get isConfigured => false;
  @override
  Future<AiMechanicAnswer> ask(AiMechanicRequest request) async {
    throw const AiException(
      AiFailure.notConfigured,
      'The AI mechanic is not connected yet. Build the app with '
      '--dart-define=AI_PROXY_URL=<your proxy URL>.',
    );
  }
}

/// Calls POST {baseUrl}/v1/mechanic on the My Garage Hero AI proxy.
class BackendAiMechanicService implements AiMechanicService {
  BackendAiMechanicService({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  @override
  bool get isConfigured => baseUrl.isNotEmpty;

  @override
  Future<AiMechanicAnswer> ask(AiMechanicRequest request) async {
    final uri = Uri.parse(baseUrl).resolve('/v1/mechanic');
    final http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'x-app-client': AppConfig.appClientId,
              'x-app-version': AppConfig.appVersion,
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException(
        AiFailure.network,
        'The AI mechanic took too long to answer. Please try again.',
      );
    } catch (e) {
      throw AiException(
        AiFailure.network,
        'Could not reach the AI mechanic. Check your internet connection.',
        detail: '$e',
      );
    }

    if (res.statusCode == 429) {
      throw const AiException(
        AiFailure.rateLimited,
        'Too many questions in a short time. Please wait a minute.',
      );
    }
    if (res.statusCode != 200) {
      throw AiException(
        AiFailure.server,
        'The AI mechanic is unavailable right now.',
        detail: 'HTTP ${res.statusCode}',
      );
    }
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map) throw const FormatException('not an object');
      final answer = AiMechanicAnswer.fromJson(Map<String, dynamic>.from(body));
      if (answer.summary.isEmpty) throw const FormatException('empty summary');
      return answer;
    } catch (e) {
      throw AiException(
        AiFailure.invalidResponse,
        'The AI mechanic returned an unexpected answer.',
        detail: '$e',
      );
    }
  }
}

AiMechanicService createAiMechanicService() => AppConfig.aiConfigured
    ? BackendAiMechanicService(baseUrl: AppConfig.aiProxyUrl)
    : const UnconfiguredAiMechanicService();

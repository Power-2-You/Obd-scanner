/// Build-time configuration, supplied with --dart-define. Nothing secret is
/// ever compiled into the app: the AI provider key lives only on the backend
/// proxy (see backend/ai_proxy).
class AppConfig {
  const AppConfig._();

  /// Base URL of the AI mechanic proxy, e.g. https://ai.mygaragehero.com.au
  /// Empty = AI mechanic disabled (the screen explains how to enable it).
  static const String aiProxyUrl = String.fromEnvironment('AI_PROXY_URL');

  /// Public app identifier sent to the proxy for rate-limiting/abuse
  /// controls. This is NOT a secret and must not be treated as one.
  static const String appClientId = String.fromEnvironment(
    'APP_CLIENT_ID',
    defaultValue: 'mgh-iq-ios',
  );

  static const String appVersion = '1.0.0';

  static bool get aiConfigured => aiProxyUrl.isNotEmpty;
}

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Public client settings only. Never put server-side secrets in this file.
class AppConfig {
  static const defaultApiBaseUrl = 'https://prsyiadiplvumfjesfdf.supabase.co/functions/v1/upyogi-api';

  static String _value(String key) =>
      dotenv.isInitialized ? (dotenv.env[key] ?? '').trim() : '';

  static String normalizeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        uri.host.endsWith('.invalid')) {
      throw const FormatException('Use a valid HTTPS server URL.');
    }
    return uri.toString().replaceFirst(RegExp(r'/+$'), '');
  }

  static String get apiBaseUrl {
    final configured = _value('API_BASE_URL');
    if (configured.isNotEmpty) return normalizeUrl(configured);
    final legacy = _value('AUTH_BASE_URL');
    if (legacy.isNotEmpty && !legacy.contains('example.invalid')) {
      return normalizeUrl(legacy.replaceFirst(RegExp(r'/api/Auth/?$', caseSensitive: false), ''));
    }
    return defaultApiBaseUrl;
  }

  static String endpoint(String name) => '$apiBaseUrl/api/$name';
  static String get authBaseUrl => endpoint('Auth');
  static String get locationHubUrl => '$apiBaseUrl/hubs/location';
  static String? serverStripePublishableKey;
  static String get stripePublishableKey => serverStripePublishableKey ?? _value('STRIPE_PUBLISHABLE_KEY');
  static bool get paymentsEnabled => stripePublishableKey.startsWith('pk_test_') ||
      stripePublishableKey.startsWith('pk_live_');
}

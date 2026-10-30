import 'package:flutter/foundation.dart';

enum Environment {
  staging,
  production;

  static Environment resolve() {
    const env = String.fromEnvironment('APP_ENV');
    if (env.isNotEmpty) {
      return env.toLowerCase().startsWith('prod')
          ? Environment.production
          : Environment.staging;
    }
    return kReleaseMode ? Environment.production : Environment.staging;
  }
}

/// Secure Supabase runtime & build configuration.
class SupabaseConfig {
  static final Environment activeEnvironment = Environment.resolve();

  static const String _defaultUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _defaultAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String _stagingUrl = String.fromEnvironment('SUPABASE_STAGING_URL');
  static const String _stagingAnonKey = String.fromEnvironment('SUPABASE_STAGING_ANON_KEY');

  static const String _prodUrl = String.fromEnvironment('SUPABASE_PROD_URL');
  static const String _prodAnonKey = String.fromEnvironment('SUPABASE_PROD_ANON_KEY');

  static bool get isProduction => activeEnvironment == Environment.production;
  static bool get isStaging => activeEnvironment == Environment.staging;

  static String get url {
    if (isProduction) return _prodUrl.isNotEmpty ? _prodUrl : _defaultUrl;
    return _stagingUrl.isNotEmpty ? _stagingUrl : _defaultUrl;
  }

  static String get anonKey {
    if (isProduction) return _prodAnonKey.isNotEmpty ? _prodAnonKey : _defaultAnonKey;
    return _stagingAnonKey.isNotEmpty ? _stagingAnonKey : _defaultAnonKey;
  }

  static bool get isConfigured =>
      url.trim().isNotEmpty &&
      anonKey.trim().isNotEmpty &&
      !anonKey.contains('PLACEHOLDER');

  static String get environmentName =>
      isProduction ? 'PRODUCTION (LIVE)' : 'STAGING (TEST DATABASE)';
}


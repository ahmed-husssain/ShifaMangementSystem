import 'package:flutter/foundation.dart';

enum Environment {
  staging,
  production,
}

/// Secure Supabase runtime & build configuration.
/// 
/// Credentials are read dynamically from compile-time environment variables
/// (e.g. `--dart-define=SUPABASE_URL=...` or `--dart-define-from-file=.env`).
/// No live secrets are hardcoded in the codebase.
class SupabaseConfig {
  /// Toggle to automatically switch between staging and production based on build mode
  static const bool useAutomaticSwitch = bool.fromEnvironment(
    'SUPABASE_AUTO_SWITCH',
    defaultValue: false,
  );

  /// Manual selection: Change between Environment.staging and Environment.production
  static const Environment currentEnvironment = Environment.production;

  // -------------------------------------------------------------------------
  // 1. STAGING CREDENTIALS (Injected via environment or .env)
  // -------------------------------------------------------------------------
  static const String _stagingUrl = String.fromEnvironment(
    'SUPABASE_STAGING_URL',
    defaultValue: String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
  );
  static const String _stagingAnonKey = String.fromEnvironment(
    'SUPABASE_STAGING_ANON_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
  );

  // -------------------------------------------------------------------------
  // 2. PRODUCTION CREDENTIALS (Injected via environment or .env)
  // -------------------------------------------------------------------------
  static const String _prodUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _prodAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // -------------------------------------------------------------------------
  // RESOLVERS
  // -------------------------------------------------------------------------
  static Environment get activeEnvironment {
    if (useAutomaticSwitch) {
      return kReleaseMode ? Environment.production : Environment.staging;
    }
    return currentEnvironment;
  }

  static bool get isStaging => activeEnvironment == Environment.staging;
  static bool get isProduction => activeEnvironment == Environment.production;

  static String get url => isProduction ? _prodUrl : _stagingUrl;
  static String get anonKey => isProduction ? _prodAnonKey : _stagingAnonKey;

  static bool get isConfigured =>
      url.trim().isNotEmpty &&
      anonKey.trim().isNotEmpty &&
      !anonKey.contains('PLACEHOLDER');

  static String get environmentName =>
      isProduction ? 'PRODUCTION (LIVE)' : 'STAGING (TEST DATABASE)';
}

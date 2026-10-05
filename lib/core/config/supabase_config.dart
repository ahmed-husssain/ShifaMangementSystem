import 'package:flutter/foundation.dart';

enum Environment {
  staging,    // Temporary / Testing Database (REDACTED_PROJECT_ID)
  production, // Main / Real Patient Database (REDACTED_PROJECT_ID)
}

class SupabaseConfig {
  // =========================================================================
  // ENVIRONMENT CONFIGURATION:
  //
  // 🔘 OPTION 1 (MANUAL TOGGLE):
  //    Change `currentEnvironment` below to switch databases anytime.
  //
  // 🔘 OPTION 2 (AUTOMATIC):
  //    Set `useAutomaticSwitch = true`.
  //    - Debug mode (flutter run) ➔ Automatically connects to STAGING (Test DB)
  //    - Release mode (APK build)  ➔ Automatically connects to PRODUCTION (Live DB)
  // =========================================================================

  /// Set to true to automatically use Production on APK builds and Staging during development
  static const bool useAutomaticSwitch = false;

  /// Manual selection: Change between Environment.staging and Environment.production
  static const Environment currentEnvironment = Environment.production;

  // -------------------------------------------------------------------------
  // 1. STAGING / TEMPORARY TEST DATABASE CREDENTIALS (REDACTED_PROJECT_ID)
  // -------------------------------------------------------------------------
  static const String _stagingUrl = 'https://staging.supabase.co';
  static const String _stagingAnonKey = 'sb_publishable_REDACTED';

  // -------------------------------------------------------------------------
  // 2. PRODUCTION / REAL PATIENT DATABASE CREDENTIALS (REDACTED_PROJECT_ID)
  // -------------------------------------------------------------------------
  static const String _prodUrl = 'https://production.supabase.co';
  static const String _prodAnonKey = 'sb_publishable_REDACTED';

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

  static String get environmentName =>
      isProduction ? 'PRODUCTION (LIVE)' : 'STAGING (TEST DATABASE)';
}

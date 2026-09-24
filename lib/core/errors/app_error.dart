import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized error handling utility that converts technical exceptions
/// (Supabase, Auth, Postgrest, Network) into clean, user-friendly messages.
class AppError {
  /// Maps any exception or error object to a clean, user-friendly message.
  /// Logs the raw technical error to debug console for developer inspection.
  static String map(dynamic error, {String? defaultMessage}) {
    debugPrint('[AppError Log] Technical exception caught: $error');

    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('banned') || msg.contains('disabled')) {
        return 'This account has been deactivated. Please contact your administrator.';
      }
      if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
        return 'Incorrect username or password. Please try again.';
      }
      if (msg.contains('already registered') || msg.contains('already in use')) {
        return 'An account with this username already exists.';
      }
      if (msg.contains('rate limit') || msg.contains('too many')) {
        return 'Too many attempts. Please wait a few moments and try again.';
      }
      return _cleanRawMessage(error.message);
    }

    if (error is PostgrestException) {
      if (error.code == '23505') {
        return 'A record with this identifier already exists.';
      }
      if (error.code == '42501' || error.message.toLowerCase().contains('permission denied')) {
        return 'Permission denied: Only active administrators can perform this action.';
      }
      if (error.code == '42P17') {
        return 'Database security policy recursion detected. Please contact administrator.';
      }
      return _cleanRawMessage(error.message);
    }

    final rawStr = error.toString();
    if (rawStr.toLowerCase().contains('user_banned') || rawStr.toLowerCase().contains('deactivated')) {
      return 'This account has been deactivated. Please contact your administrator.';
    }
    return _cleanRawMessage(rawStr, fallback: defaultMessage);
  }

  /// Strips technical prefixes like Exception:, FormatException:, etc.
  static String _cleanRawMessage(String msg, {String? fallback}) {
    var clean = msg;
    clean = clean.replaceAll(RegExp(r'^(Exception|FormatException|StateError):\s*'), '');
    clean = clean.replaceAll(RegExp(r'^\[[\w/-]+\]\s*'), '');
    clean = clean.replaceAll(RegExp(r'^(PostgrestException|AuthException):\s*'), '');
    clean = clean.trim();

    if (clean.isEmpty) {
      return fallback ?? 'An unexpected error occurred. Please try again.';
    }

    if (clean.isNotEmpty) {
      clean = clean[0].toUpperCase() + clean.substring(1);
    }

    return clean;
  }
}

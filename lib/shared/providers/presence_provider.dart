import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

/// Information about a currently online user
class UserPresenceInfo {
  final String userId;
  final String username;
  final String email;
  final String role;
  final DateTime onlineAt;
  final String platform;

  const UserPresenceInfo({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    required this.onlineAt,
    required this.platform,
  });

  factory UserPresenceInfo.fromMap(Map<String, dynamic> map) {
    return UserPresenceInfo(
      userId: (map['user_id'] ?? map['id'] ?? map['uid'] ?? '').toString(),
      username: (map['username'] ?? '').toString().toUpperCase(),
      email: (map['email'] ?? '').toString().toLowerCase(),
      role: (map['role'] ?? 'staff').toString().toLowerCase(),
      onlineAt: DateTime.tryParse(map['online_at']?.toString() ?? '') ?? DateTime.now(),
      platform: (map['platform'] ?? (kIsWeb ? 'web' : defaultTargetPlatform.name)).toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'role': role,
      'online_at': onlineAt.toIso8601String(),
      'platform': platform,
    };
  }
}

/// State holding all currently online users indexed by ID, username, and email
class OnlinePresenceState {
  final Map<String, UserPresenceInfo> usersById;
  final Map<String, UserPresenceInfo> usersByUsername;
  final Map<String, UserPresenceInfo> usersByEmail;

  const OnlinePresenceState({
    this.usersById = const {},
    this.usersByUsername = const {},
    this.usersByEmail = const {},
  });

  /// Check whether a user is online using any available identifier
  bool isOnline({String? userId, String? username, String? email}) {
    if (userId != null && userId.isNotEmpty && usersById.containsKey(userId)) {
      return true;
    }
    if (username != null && username.isNotEmpty && usersByUsername.containsKey(username.toUpperCase())) {
      return true;
    }
    if (email != null && email.isNotEmpty && usersByEmail.containsKey(email.toLowerCase())) {
      return true;
    }
    return false;
  }

  /// Get presence info for a user
  UserPresenceInfo? getPresence({String? userId, String? username, String? email}) {
    if (userId != null && userId.isNotEmpty && usersById.containsKey(userId)) {
      return usersById[userId];
    }
    if (username != null && username.isNotEmpty && usersByUsername.containsKey(username.toUpperCase())) {
      return usersByUsername[username.toUpperCase()];
    }
    if (email != null && email.isNotEmpty && usersByEmail.containsKey(email.toLowerCase())) {
      return usersByEmail[email.toLowerCase()];
    }
    return null;
  }

  int get onlineCount => usersById.length;
}

/// Notifier managing real-time presence subscription and tracking
class OnlinePresenceNotifier extends Notifier<OnlinePresenceState> {
  RealtimeChannel? _channel;
  Map<String, dynamic>? _lastProfile;
  bool _isTracking = false;

  @override
  OnlinePresenceState build() {
    // Listen to user profile to track/untrack when login state changes
    ref.listen(userProfileProvider, (previous, next) {
      final profile = next.value;
      if (profile != null && profile['id'] != null) {
        _lastProfile = profile;
        _trackSelf();
      } else {
        _lastProfile = null;
        _untrackSelf();
      }
    });

    // Initialize channel and subscribe
    _initChannel();

    ref.onDispose(() {
      _channel?.unsubscribe();
      _channel = null;
    });

    return const OnlinePresenceState();
  }

  void _initChannel() {
    final supabase = ref.read(supabaseClientProvider);
    _channel = supabase.channel('staff-presence');

    _channel!.onPresenceSync((payload) {
      _syncPresenceFromChannel();
    });

    _channel!.onPresenceJoin((payload) {
      _syncPresenceFromChannel();
    });

    _channel!.onPresenceLeave((payload) {
      _syncPresenceFromChannel();
    });

    _channel!.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        final profile = _lastProfile ?? ref.read(userProfileProvider).value;
        if (profile != null) {
          _lastProfile = profile;
          await _trackSelf();
        }
        _syncPresenceFromChannel();
      }
    });
  }

  void _syncPresenceFromChannel() {
    if (_channel == null) return;
    try {
      final list = _channel!.presenceState();
      final byId = <String, UserPresenceInfo>{};
      final byUsername = <String, UserPresenceInfo>{};
      final byEmail = <String, UserPresenceInfo>{};

      for (final presenceState in list) {
        for (final presence in presenceState.presences) {
          try {
            final raw = presence.payload;
            final map = Map<String, dynamic>.from(raw as Map);
            final info = UserPresenceInfo.fromMap(map);
            if (info.userId.isNotEmpty) byId[info.userId] = info;
            if (info.username.isNotEmpty) byUsername[info.username] = info;
            if (info.email.isNotEmpty) byEmail[info.email] = info;
          } catch (_) {}
        }
      }

      state = OnlinePresenceState(
        usersById: byId,
        usersByUsername: byUsername,
        usersByEmail: byEmail,
      );
    } catch (_) {
      // In case presenceState is parsing during transient socket reconnect
    }
  }

  Future<void> _trackSelf() async {
    if (_channel == null || _lastProfile == null) return;
    try {
      final p = _lastProfile!;
      final uid = (p['id'] ?? p['uid'] ?? '').toString();
      final username = (p['username'] ?? '').toString().toUpperCase();
      final email = (p['email'] ?? '').toString().toLowerCase();
      final role = (p['role'] ?? 'staff').toString().toLowerCase();

      if (uid.isEmpty) return;

      await _channel!.track({
        'user_id': uid,
        'username': username,
        'email': email,
        'role': role,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'online_at': DateTime.now().toIso8601String(),
      });
      _isTracking = true;
    } catch (_) {}
  }

  Future<void> _untrackSelf() async {
    if (_channel == null || !_isTracking) return;
    try {
      await _channel!.untrack();
      _isTracking = false;
    } catch (_) {}
  }

  /// Called when the app lifecycle changes (e.g. app paused or closed)
  void onAppLifecycleChanged(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      _trackSelf();
    } else if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.detached ||
        appState == AppLifecycleState.hidden) {
      _untrackSelf();
    }
  }
}

final onlinePresenceProvider = NotifierProvider<OnlinePresenceNotifier, OnlinePresenceState>(
  OnlinePresenceNotifier.new,
);

/// A wrapper widget that hooks into Flutter's app lifecycle
/// to untrack presence immediately when minimized or closed on mobile,
/// and re-track when brought back to the foreground.
class AppLifecyclePresenceWatcher extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecyclePresenceWatcher({super.key, required this.child});

  @override
  ConsumerState<AppLifecyclePresenceWatcher> createState() => _AppLifecyclePresenceWatcherState();
}

class _AppLifecyclePresenceWatcherState extends ConsumerState<AppLifecyclePresenceWatcher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Trigger presence notifier initialization
    Future.microtask(() {
      if (mounted) {
        ref.read(onlinePresenceProvider.notifier);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(onlinePresenceProvider.notifier).onAppLifecycleChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

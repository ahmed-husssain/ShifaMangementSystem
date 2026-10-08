import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'shared/providers/presence_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } else {
    debugPrint(
      '⚠️ [SupabaseConfig] No Supabase credentials configured.\n'
      'Pass credentials via --dart-define or --dart-define-from-file=.env',
    );
  }

  runApp(const ProviderScope(child: ShifaApp()));
}

class ShifaApp extends ConsumerWidget {
  const ShifaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SHHC Management System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      routerConfig: router,
      builder: (context, child) {
        return AppLifecyclePresenceWatcher(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

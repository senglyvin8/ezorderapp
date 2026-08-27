import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/backend_config.dart';
import 'platform/platform_app.dart';
import 'platform/platform_store.dart';

/// Entry point for the **platform operator console**, a separate app from the
/// restaurant one.
///
///     flutter build web -t lib/main_platform.dart \
///       --dart-define=SUPABASE_URL=... \
///       --dart-define=SUPABASE_ANON_KEY=...
///
/// Two builds, two deployments, one database. Keeping them apart is not
/// decoration: the diner's bundle has no business carrying code that lists
/// every restaurant on the platform, and this one has no business carrying a
/// cart. RESTAURANT_SLUG is not used here — the console is not any one
/// restaurant.
///
/// The separation is defence in depth, not the defence itself. Both apps ship
/// the same publishable key, so what actually stops a diner reaching this data
/// is that every platform function checks `is_platform_admin()` in Postgres.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!_configured) {
    runApp(const PlatformUnavailable(
      message: 'Build it with SUPABASE_URL and SUPABASE_ANON_KEY set. '
          'See supabase/README.md.',
    ));
    return;
  }

  try {
    await Supabase.initialize(
      url: BackendConfig.supabaseUrl,
      publishableKey: BackendConfig.supabaseAnonKey,
    );
  } catch (error) {
    runApp(PlatformUnavailable(message: '$error'));
    return;
  }

  runApp(
    ChangeNotifierProvider<PlatformStore>(
      create: (_) => PlatformStore(Supabase.instance.client),
      child: const PlatformApp(),
    ),
  );
}

/// The console needs the project, but not a restaurant.
bool get _configured =>
    BackendConfig.supabaseUrl.isNotEmpty &&
    BackendConfig.supabaseAnonKey.isNotEmpty;

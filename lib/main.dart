import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/backend_config.dart';
import 'data/app_store.dart';
import 'data/backend/backend.dart';
import 'data/backend/local_backend.dart';
import 'data/backend/supabase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = AppStore(backend: await _openBackend());
  await store.load();

  runApp(
    ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const RestaurantApp(),
    ),
  );
}

/// Connects to Supabase if this build was given a project, and falls back to
/// the on-device demo if it was not.
///
/// The fallback also catches a project that is unreachable at startup: a
/// misconfigured build showing a working demo is a far better failure than a
/// blank screen, and the sign-in screen says which it is.
Future<Backend> _openBackend() async {
  if (!BackendConfig.usesSupabase) return LocalBackend();

  try {
    await Supabase.initialize(
      url: BackendConfig.supabaseUrl,
      // Named `publishableKey` since Supabase renamed it; it still accepts the
      // legacy `anon` JWT that older projects show.
      publishableKey: BackendConfig.supabaseAnonKey,
    );
    return SupabaseBackend(Supabase.instance.client);
  } catch (error) {
    debugPrint('EZ Order: could not reach Supabase, running the demo. $error');
    return LocalBackend();
  }
}

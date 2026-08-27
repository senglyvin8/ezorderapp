import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'config/backend_config.dart';
import 'data/app_store.dart';
import 'data/backend/backend.dart';
import 'data/backend/local_backend.dart';
import 'data/backend/supabase_backend.dart';
import 'l10n/app_text.dart';
import 'theme/app_theme.dart';
import 'widgets/app_chrome.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

/// Opens the restaurant before showing it.
///
/// This is a screen rather than a few lines in `main()` for one reason: on a
/// real backend, loading can fail. A restaurant's wifi drops, a project is
/// paused, DNS goes odd mid-service. Awaiting that in `main()` means a throw
/// never reaches `runApp` and the staff are left holding a white rectangle
/// with no way forward — the worst thing a till can do.
///
/// So: a splash while it loads, and if it fails, something that says what
/// happened and offers to try again.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  AppStore? _store;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() => _error = null);
    try {
      final store = AppStore(backend: await _openBackend());
      await store.load();
      if (mounted) setState(() => _store = store);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError
            ? error.message
            : 'Could not reach the restaurant. $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store != null) {
      return ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: const RestaurantApp(),
      );
    }
    return MaterialApp(
      title: Brand.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _error == null
          ? const _Opening()
          : _CannotOpen(message: _error!, onRetry: _open),
    );
  }
}

class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _CannotOpen extends StatelessWidget {
  const _CannotOpen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // No store yet, so no language preference to read — fall back to the
    // build's default.
    const t = AppText(Brand.defaultLanguage);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: PageWidth(
          maxWidth: 460,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 54, color: AppColors.inkFaint),
                  const SizedBox(height: 16),
                  Text(
                    t.cannotReachRestaurant,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(message,
                      textAlign: TextAlign.center, style: AppType.body),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(t.tryAgain),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Connects to Supabase if this build was given a project, and falls back to
/// the on-device demo if it was not configured at all.
///
/// A *configured* build that cannot reach its project does not fall back —
/// it reports the failure. Quietly showing a seeded demo restaurant to staff
/// who are looking for today's orders would be worse than saying nothing.
Future<Backend> _openBackend() async {
  if (!BackendConfig.usesSupabase) return LocalBackend();

  await Supabase.initialize(
    url: BackendConfig.supabaseUrl,
    // Named `publishableKey` since Supabase renamed it; it still accepts the
    // legacy `anon` JWT that older projects show.
    publishableKey: BackendConfig.supabaseAnonKey,
  );
  return SupabaseBackend(Supabase.instance.client);
}

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
import 'data/merchant_binding.dart';
import 'l10n/app_text.dart';
import 'models/merchant_code.dart';
import 'screens/auth/merchant_bind_screen.dart';
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

  /// This build has a project but no idea which restaurant to open in it, so
  /// somebody has to say. See [MerchantBinding].
  bool _needsBinding = false;
  MerchantBinding? _binding;
  bool _supabaseReady = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _error = null;
      _needsBinding = false;
    });
    try {
      if (BackendConfig.hasProject) {
        await _initSupabase();
        _binding = await MerchantBinding.read();
        BackendConfig.bindSlug(_binding?.slug);
        if (!BackendConfig.hasRestaurant) {
          // Nothing to open yet, and that is not an error — it is a device
          // nobody has set up. Ask, rather than reporting a failure.
          if (mounted) setState(() => _needsBinding = true);
          return;
        }
      }
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

  Future<void> _initSupabase() async {
    if (_supabaseReady) return;
    await Supabase.initialize(
      url: BackendConfig.supabaseUrl,
      // Named `publishableKey` since Supabase renamed it; it still accepts the
      // legacy `anon` JWT that older projects show.
      publishableKey: BackendConfig.supabaseAnonKey,
    );
    _supabaseReady = true;
  }

  Future<void> _bind(MerchantBinding binding) async {
    await binding.save();
    BackendConfig.bindSlug(binding.slug);
    if (mounted) await _open();
  }

  /// Points this device at a different merchant: forget, then ask again. The
  /// store goes with it — it holds a restaurant that is no longer this
  /// device's.
  Future<void> _rebind() async {
    await MerchantBinding.clear();
    BackendConfig.bindSlug(null);
    if (!mounted) return;
    setState(() {
      _store = null;
      _binding = null;
    });
    await _open();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store != null) {
      return ChangeNotifierProvider<AppStore>.value(
        value: store,
        // Only a build that could be pointed somewhere else gets the
        // affordance: on the demo, and on a build compiled for one shop,
        // there is nowhere to go.
        child: RestaurantApp(
          onRebind: BackendConfig.hasProject &&
                  BackendConfig.restaurantSlug.isEmpty
              ? _rebind
              : null,
        ),
      );
    }
    return MaterialApp(
      title: Brand.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: switch ((_needsBinding, _error)) {
        (true, _) => MerchantBindScreen(
            // No store yet, so no language preference to read — the build's
            // default, same as the failure screen below.
            text: const AppText(Brand.defaultLanguage),
            resolve: resolveMerchantByCode,
            signIn: signInAsOwner,
            onBound: _bind,
            current: _binding,
          ),
        (_, final String message) => _CannotOpen(message: message, onRetry: _open),
        _ => const _Opening(),
      },
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
  return SupabaseBackend(Supabase.instance.client);
}

/// Signs an owner in and works out which restaurant they run.
///
/// The other door onto the same room. An owner installing the app from a store
/// knows their email and their password and should not have to go looking for
/// a merchant ID before they can use either — their staff row already says
/// where they work.
///
/// The session survives this, so the app opens with them already signed in
/// rather than asking for the same password twice in a row.
Future<MerchantBinding?> signInAsOwner(String email, String password) async {
  final client = Supabase.instance.client;
  try {
    await client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  } on AuthException {
    // Wrong address, wrong password, no such account — one answer for all
    // three, so none of them can be told apart by trying.
    return null;
  }

  try {
    final rows = await client.rpc<List<dynamic>>('my_restaurant');
    if (rows.isEmpty) {
      // A real account that works for nobody: a platform admin, or a diner's
      // anonymous session that somehow got here. Nothing to bind to.
      await client.auth.signOut();
      throw StateError('That account does not belong to a restaurant');
    }
    final row = rows.first as Map<String, dynamic>;
    return MerchantBinding(
      code: MerchantCode.normalize(row['code'] as String? ?? '') ?? '',
      slug: row['slug'] as String,
      name: row['name'] as String? ?? '',
      logo: row['logo'] as String? ?? '🍽️',
    );
  } on StateError {
    rethrow;
  } catch (error) {
    await client.auth.signOut();
    throw StateError('Could not reach the service. $error');
  }
}

/// Looks a merchant ID up in the project this build is pointed at.
///
/// `restaurant_by_code` is an exact match and returns only what is needed to
/// show whose restaurant this is — see `0011_merchant_code.sql` for why that
/// is safe to leave open to a caller with no account.
Future<MerchantBinding?> resolveMerchantByCode(String code) async {
  try {
    final rows = await Supabase.instance.client
        .rpc<List<dynamic>>('restaurant_by_code', params: {'p_code': code});
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return MerchantBinding(
      code: code,
      slug: row['slug'] as String,
      name: row['name'] as String? ?? '',
      logo: row['logo'] as String? ?? '🍽️',
    );
  } on StateError {
    rethrow;
  } catch (error) {
    throw StateError('Could not reach the service. $error');
  }
}

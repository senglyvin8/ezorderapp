/// ============================================================================
///  WHERE YOUR DATA LIVES
/// ============================================================================
///
/// Out of the box EZ Order runs entirely on the device: a demo restaurant,
/// seeded menu, and everything kept in SharedPreferences. That is what you get
/// with no configuration at all, and it is what the test suite runs against.
///
/// Point it at a Supabase project and it becomes a real product instead — one
/// database behind every device, so the kitchen tablet, the till and the
/// diner's phone are looking at the same orders, and roles are enforced by
/// Postgres rather than by the app being polite.
///
/// See `supabase/README.md` for how to set the project up. Then pass the three
/// values at build time:
///
///     flutter run \
///       --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///       --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi... \
///       --dart-define=RESTAURANT_SLUG=demo
///
/// They are compile-time constants, so a build with no defines is a demo build
/// and cannot accidentally talk to your live restaurant.
///
/// The anon key is *designed* to ship inside client apps — it grants nothing on
/// its own, because every table has row level security. The key that must never
/// appear here, or anywhere in this repository, is the `service_role` key.
library;

import 'app_config.dart';

abstract class BackendConfig {
  /// `https://<project>.supabase.co`, from Project Settings → API.
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  /// The key from the same page — labelled **Publishable key** on new
  /// projects and **anon public** on older ones. Either works, and either is
  /// safe to ship: on its own it grants nothing, because every table has row
  /// level security.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Which restaurant this build serves.
  ///
  /// One Supabase project holds many restaurants, so the app has to say which
  /// one it is. It is the `slug` you passed to `provision_restaurant()`, and
  /// it is also what appears in the table QR links.
  static const String restaurantSlug =
      String.fromEnvironment('RESTAURANT_SLUG', defaultValue: '');

  /// True only when all three are present. Anything less and the app runs the
  /// on-device demo, rather than half-connecting and failing at the first tap.
  static bool get usesSupabase =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      restaurantSlug.isNotEmpty;

  /// The slug actually in force: the configured restaurant when connected,
  /// and the bundled demo's slug otherwise.
  ///
  /// Table QR identifiers are built from this, which is what keeps them unique
  /// once one Supabase project holds more than one restaurant.
  static String get slug =>
      usesSupabase ? restaurantSlug.toLowerCase() : Brand.slug;

  /// What is missing, for the diagnostic shown on the sign-in screen when
  /// someone expected a live build and got the demo.
  static List<String> get missing => [
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
        if (restaurantSlug.isEmpty) 'RESTAURANT_SLUG',
      ];

  /// The login address for a member of staff.
  ///
  /// Staff never type an email. An admin's is derived from the username they
  /// type; everyone else's from the id the PIN pad already holds. This mirrors
  /// `staff_login_email()` in `supabase/migrations/0004_accounts.sql` — change
  /// one and you must change the other.
  static String loginEmail(String local) =>
      '${local.toLowerCase()}@$slug.staff.ezorder.app';
}

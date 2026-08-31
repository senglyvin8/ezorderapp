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
/// See `supabase/README.md` for how to set the project up. Then pass the
/// project at build time:
///
///     flutter run \
///       --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///       --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
///
/// That is one app for every restaurant on the project. Which one a given
/// device serves is decided on the device, by entering the merchant ID or
/// scanning the owner's code once — see [MerchantBinding].
///
/// Adding `--dart-define=RESTAURANT_SLUG=demo` locks the build to one
/// restaurant instead, which is what you want when a single shop has its own
/// app in its own store listing. Nothing then asks, and nothing can wander.
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

  /// Which restaurant this build serves, if it serves exactly one.
  ///
  /// Optional now. A build with a slug is locked to that restaurant, which is
  /// what you want for a single shop with its own app. A build without one
  /// serves whichever merchant the device was bound to — see
  /// [MerchantBinding] — which is what you want for a hundred of them.
  static const String restaurantSlug =
      String.fromEnvironment('RESTAURANT_SLUG', defaultValue: '');

  /// The merchant this device was bound to at run time, if any.
  ///
  /// A mutable static is not a thing to reach for lightly, and it is here
  /// because the slug is read from static context all over the app —
  /// [loginEmail], [tableLink], the staff directory. Threading a value through
  /// all of those would be a larger change than the one being made. It is set
  /// once, by the bootstrap, before any of them is called.
  static String? _boundSlug;

  static void bindSlug(String? slug) {
    final value = slug?.trim().toLowerCase();
    _boundSlug = (value == null || value.isEmpty) ? null : value;
  }

  /// True when this build has a project to talk to at all. Whether it knows
  /// *which* restaurant is a separate question — see [hasRestaurant].
  static bool get hasProject =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// True when there is a project and a restaurant to open in it. Anything
  /// less and the app runs the on-device demo, rather than half-connecting
  /// and failing at the first tap.
  static bool get usesSupabase => hasProject && hasRestaurant;

  /// Either the build was told, or the device was bound.
  static bool get hasRestaurant =>
      restaurantSlug.isNotEmpty || (_boundSlug?.isNotEmpty ?? false);

  /// Where the customer-facing web app is hosted, e.g.
  /// `https://ezorder.vercel.app`. No trailing slash.
  ///
  /// This is what a printed table QR code points at. It has to be a public
  /// address a diner's phone can reach — not `localhost`, and not the app
  /// itself, because the phone showing the QR code is not the phone scanning
  /// it. Without it the codes are only useful to the in-app scanner.
  static const String publicUrl =
      String.fromEnvironment('PUBLIC_URL', defaultValue: '');

  static bool get hasPublicUrl => publicUrl.isNotEmpty;

  /// Where a password-recovery link should land.
  ///
  /// The hosted web app, deliberately, even when the reset was asked for on a
  /// phone. A link that opens an installed app needs universal links set up on
  /// both stores and a signed association file; a link that opens a web page
  /// works from any email client on any device today. The owner sets a new
  /// password there and signs into the phone with it.
  ///
  /// Null when this build has no public address, which is every demo build —
  /// and those have nothing to email anybody about.
  static String? get passwordResetUrl =>
      hasPublicUrl ? publicUrl.replaceAll(RegExp(r'/+$'), '') : null;

  /// The link a table's QR code should carry.
  ///
  /// Hash form on purpose: Flutter web routes on the fragment unless told
  /// otherwise, so `/#/order/demo/table/05` is served by any static host
  /// without a rewrite rule. A plain path would 404 everywhere except a dev
  /// server.
  static String tableLink(String tableNumber) =>
      '${publicUrl.replaceAll(RegExp(r'/+$'), '')}'
      '/#/order/$slug/table/$tableNumber';

  /// The slug actually in force: what the device was bound to, else the
  /// restaurant this build was compiled for, else the bundled demo's.
  ///
  /// The binding wins over the compile-time value so a tablet that has been
  /// deliberately pointed at a merchant stays pointed there.
  ///
  /// Table QR identifiers are built from this, which is what keeps them unique
  /// once one Supabase project holds more than one restaurant.
  static String get slug {
    final bound = _boundSlug;
    if (bound != null && bound.isNotEmpty) return bound;
    return restaurantSlug.isNotEmpty ? restaurantSlug.toLowerCase() : Brand.slug;
  }

  /// What is missing, for the diagnostic shown on the sign-in screen when
  /// someone expected a live build and got the demo.
  ///
  /// The slug is only listed when there is a project but nothing has been
  /// bound: with a device binding it is not missing, it is answered elsewhere.
  static List<String> get missing => [
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
        if (!hasRestaurant) 'RESTAURANT_SLUG (or a device binding)',
      ];

  /// The login address derived for a member of staff.
  ///
  /// Kitchen and cashier staff never type an address: theirs is built from the
  /// id the PIN pad already holds. The same shape was once used for admins,
  /// derived from a username, and still is for the accounts that were created
  /// that way. Mirrors `staff_login_email()` in
  /// `supabase/migrations/0004_accounts.sql` — change one and you must change
  /// the other.
  static String loginEmail(String local) =>
      '${local.toLowerCase()}@$slug.staff.ezorder.app';

  /// What to actually sign in with, given whatever the person typed.
  ///
  /// An owner now types their own email address, which is used as it stands.
  /// Anything without an `@` is the older username form and is derived as it
  /// always was — a restaurant whose owner has signed in the same way for a
  /// year should not discover one morning that it has stopped working.
  static String authAddressFor(String typed) {
    final value = typed.trim();
    return value.contains('@') ? value.toLowerCase() : loginEmail(value);
  }
}

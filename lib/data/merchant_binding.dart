import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Which merchant this device serves.
///
/// The app used to be told at build time, with `--dart-define=RESTAURANT_SLUG`.
/// That works for one restaurant and cannot work for a hundred: it means one
/// build of the app per merchant, forever.
///
/// So the device is bound instead — once, by the owner signing in on it — and
/// it remembers. A kitchen tablet is set up on the day it arrives and never
/// asked again; the staff who use it from then on tap a name and key in a PIN.
///
/// What is stored is deliberately thin: the slug that the sign-in machinery
/// runs on, and just enough branding to show whose restaurant this is before
/// anybody has signed in. It is not a credential — anyone holding the tablet
/// can read it — and it grants nothing on its own.
class MerchantBinding {
  const MerchantBinding({
    required this.slug,
    required this.name,
    this.logo = '🍽️',
  });

  /// What the login addresses and the staff directory are built from.
  final String slug;

  final String name;
  final String logo;

  static const String _prefsKey = 'rqo_merchant_binding_v1';

  Map<String, dynamic> toJson() =>
      {'slug': slug, 'name': name, 'logo': logo};

  static MerchantBinding? _fromJson(Map<String, dynamic> json) {
    final slug = (json['slug'] as String? ?? '').trim();
    // The slug is what opens the restaurant, so a binding without one is not a
    // binding.
    if (slug.isEmpty) return null;
    return MerchantBinding(
      slug: slug,
      name: json['name'] as String? ?? '',
      logo: json['logo'] as String? ?? '🍽️',
    );
  }

  /// What this device was bound to, or null if nobody has set it up.
  static Future<MerchantBinding?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    try {
      return _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A binding that will not parse is one nobody can act on. Forget it and
      // let the device be set up again rather than failing to open at all.
      await prefs.remove(_prefsKey);
      return null;
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toJson()));
  }

  /// Forgets the merchant. Used when a tablet moves to another restaurant, and
  /// it deliberately takes nothing else with it — the orders and the menu were
  /// never on the device.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

}

/// Lets a screen ask whoever opened the app to point this device at a
/// different merchant.
///
/// Provided by the bootstrap and null everywhere else — the demo has one
/// restaurant and a build compiled for a single shop is not supposed to wander
/// off to another one, so the affordance simply is not there in either case.
class RebindDevice {
  const RebindDevice(this._request);

  final Future<void> Function() _request;

  Future<void> call() => _request();
}

/// Signs an owner in and reports which restaurant they turned out to work for.
///
/// The other way to set a device up, and the one an owner installing the app
/// from a store will reach for: they know their own email and password, and
/// they should not have to find a merchant ID to type in before they can use
/// either. Null means the credentials were wrong.
typedef MerchantSignIn = Future<MerchantBinding?> Function(
    String email, String password);

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/merchant_code.dart';

/// Which merchant this device serves.
///
/// The app used to be told at build time, with `--dart-define=RESTAURANT_SLUG`.
/// That works for one restaurant and cannot work for a hundred: it means one
/// build of the app per merchant, forever.
///
/// So the device is bound instead — once, by somebody holding it — and it
/// remembers. A kitchen tablet is set up on the day it arrives and never asked
/// again. What is stored is deliberately thin: the merchant ID, the slug that
/// the sign-in machinery runs on, and just enough branding to show whose
/// restaurant this is before anybody has signed in.
///
/// It is not a credential. Anyone holding the tablet can read it and anyone can
/// bind a device with a code — a PIN or a password still stands between this
/// and any data.
class MerchantBinding {
  const MerchantBinding({
    required this.code,
    required this.slug,
    required this.name,
    this.logo = '🍽️',
  });

  /// `EZ-4K7Q2M`, canonical. Empty when the device was bound by an owner
  /// signing in rather than by typing a code.
  final String code;

  /// What the login addresses and the staff directory are built from.
  final String slug;

  final String name;
  final String logo;

  static const String _prefsKey = 'rqo_merchant_binding_v1';

  Map<String, dynamic> toJson() =>
      {'code': code, 'slug': slug, 'name': name, 'logo': logo};

  static MerchantBinding? _fromJson(Map<String, dynamic> json) {
    final slug = (json['slug'] as String? ?? '').trim();
    // The slug is what opens the restaurant, so a binding without one is not a
    // binding. The code is not load-bearing here: an owner who signed in with
    // their email never typed one, and a project that predates merchant IDs
    // has none to give.
    if (slug.isEmpty) return null;
    return MerchantBinding(
      code: MerchantCode.normalize(json['code'] as String? ?? '') ?? '',
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

  /// The payload behind the join QR code an owner shows a new device.
  ///
  /// An app scheme rather than an https link on purpose: this code is scanned
  /// by this app's own scanner, and a link that opened a web page instead
  /// would be a worse answer to "point the tablet at this".
  String get joinPayload => joinPayloadFor(code);

  static String joinPayloadFor(String code) => 'ezorder://join?m=$code';

  /// Reads a merchant ID out of whatever was scanned.
  ///
  /// Accepts the join payload, any URL carrying the code as `?m=` or a
  /// `/join/<code>` path, and a bare code typed by hand — the same spread of
  /// forms the table scanner already accepts, for the same reason: whoever is
  /// holding the camera should not have to know which shape they are pointing
  /// it at.
  static String? codeFromScan(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null) {
      final param = uri.queryParameters['m'];
      if (param != null) {
        final code = MerchantCode.normalize(param);
        if (code != null) return code;
      }
      // Both the path and the fragment: a Flutter web link routes on the
      // fragment, so `/#/join/EZ-4K7Q2M` keeps the code after the hash.
      for (final part in [uri.path, uri.fragment]) {
        final match = RegExp(r'join/([^/?#]+)').firstMatch(part);
        if (match != null) {
          final code = MerchantCode.normalize(match.group(1)!);
          if (code != null) return code;
        }
      }
    }

    return MerchantCode.normalize(value);
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

/// Turns a merchant ID into a binding, or null if there is no such merchant.
///
/// A function rather than a method so the bind screen does not have to know
/// whether it is talking to Postgres or to the on-device demo — and so the
/// tests can answer without either.
typedef MerchantResolver = Future<MerchantBinding?> Function(String code);

/// Signs an owner in and reports which restaurant they turned out to work for.
///
/// The other way to set a device up, and the one an owner installing the app
/// from a store will reach for: they know their own email and password, and
/// they should not have to find a merchant ID to type in before they can use
/// either. Null means the credentials were wrong.
typedef MerchantSignIn = Future<MerchantBinding?> Function(
    String email, String password);

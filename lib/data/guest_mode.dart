import 'package:shared_preferences/shared_preferences.dart';

/// Whether this device is having a look round rather than running a shop.
///
/// Somebody who has just downloaded the app has no merchant ID, no account and
/// nobody to ask for either — and until now the app met them with a setup
/// screen demanding both. That is a fair thing to ask of a tablet arriving at a
/// restaurant and an absurd thing to ask of a person deciding whether the
/// product is any good.
///
/// So there is a third door: the seeded demo restaurant, on the device, with
/// nothing behind it. Every screen works — the menu, the kitchen board, the
/// till, the owner's side — and none of it is anybody's real data. There is
/// nothing to sign up for, nothing to abuse, and no shared sandbox for one
/// visitor to spoil for the next, because each visitor gets their own copy on
/// their own phone.
///
/// Kept apart from [MerchantBinding] deliberately: a device that is looking
/// round is not bound to a merchant at all, and folding the two together would
/// have meant inventing a fake merchant to bind it to.
abstract class GuestMode {
  static const String _prefsKey = 'rqo_guest_mode_v1';

  /// True when the app should open the on-device demo, whatever project this
  /// build was compiled against.
  static Future<bool> isOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  static Future<void> enter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  /// Stops looking round. Deliberately leaves the demo data where it is: a
  /// visitor who comes back should find the tables they laid out rather than a
  /// fresh restaurant with no explanation of where theirs went.
  static Future<void> leave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

/// Whether the screens are looking at the demo, handed down from the bootstrap
/// so a widget anywhere in the tree can say so without going to storage to ask.
class GuestSession {
  const GuestSession(this.isGuest);

  final bool isGuest;
}

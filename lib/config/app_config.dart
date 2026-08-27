/// ============================================================================
///  THE ONE FILE TO EDIT
/// ============================================================================
///
/// Everything you would normally want to change about this app — the
/// restaurant's identity, the colours, the corner radii, the demo staff
/// logins, how many tables get created — lives here and nowhere else.
///
/// Change a value, save, and press `r` in the terminal running `flutter run`
/// for a hot reload. Colours and sizes appear instantly. Anything under
/// [Seed] only takes effect on a *fresh* install, because the app remembers
/// its data — see the note on that section for how to re-seed.
///
/// Nothing here is read from a server. This is a prototype: the whole app runs
/// on the device.
library;

import 'package:flutter/material.dart';

import '../l10n/app_text.dart';

// =============================================================================
//  1. WHO YOU ARE
// =============================================================================

/// Name, contact details and money. These are the seed values for Admin →
/// Settings; once the app is running the owner can edit them in the app, and
/// the edited version wins.
abstract class Brand {
  /// Shown on the customer menu header, kitchen tickets and printed receipts.
  static const String name = 'ABC Restaurant';

  /// Khmer name. Leave `''` to reuse [name] when the app is set to Khmer.
  static const String nameKm = 'ភោជនីយដ្ឋាន ABC';

  /// The restaurant mark. One emoji, or two or three initials — it is drawn as
  /// text in a rounded tile, so anything short works.
  static const String logo = '🍜';

  static const String phone = '+855 12 345 678';
  static const String address = 'St. 271, Toul Kork, Phnom Penh';

  /// Printed in front of every price, e.g. `$3.50`. Use `'៛'` for riel.
  static const String currencySymbol = r'$';

  /// Three-letter code shown on receipts, e.g. `USD`, `KHR`.
  static const String currencyCode = 'USD';

  /// Rule 10 — what the cashier can accept. Order matters; the first is the
  /// default selection on the payment screen.
  static const List<String> paymentMethods = ['Cash', 'KHQR', 'Card', 'Other'];

  /// The title iOS and Android show in the app switcher.
  ///
  /// The name on the *home screen* is set separately, per platform:
  /// `CFBundleDisplayName` in `ios/Runner/Info.plist`.
  static const String appTitle = 'EZ Order';

  /// The language the app opens in on a fresh install. Either
  /// `AppLanguage.km` (Khmer) or `AppLanguage.en` (English).
  ///
  /// Once someone taps the language button their choice is remembered and
  /// wins over this. To force everyone back to this default, bump
  /// `AppStore._prefsKey` — that discards the stored snapshot.
  static const AppLanguage defaultLanguage = AppLanguage.km;

  /// Short identifier that appears inside every table QR code, as
  /// `restaurant-<slug>-table-05` and `/order/<slug>/table/05`.
  ///
  /// Only lowercase letters, digits and dashes. Changing it invalidates QR
  /// codes you have already printed, so pick it once, before you print.
  static const String slug = 'demo';
}

// =============================================================================
//  2. HOW IT LOOKS
// =============================================================================

/// The visual system. One warm accent for anything you can tap, a cool neutral
/// ramp for everything else, and a status set that stays legible beside the
/// accent.
///
/// To rebrand the app you normally only need the three [accent] values.
abstract class Palette {
  // ---------------------------------------------------------------- accent
  // Reserved for interactive things: buttons, the selected tab, the cart bar.
  // Prices and body text stay near-black on purpose, so the only accent on a
  // menu screen is something you can actually tap.

  /// The main brand colour. Buttons, selected tabs, the cart bar.
  static const Color accent = Color(0xFFEA580C); // warm orange

  /// A darker step of [accent], used for text and icons that sit on white and
  /// need contrast. Pick something roughly 15% darker than [accent].
  static const Color accentDark = Color(0xFFC2410C);

  /// A very pale wash of [accent], used behind selected tabs and badges. This
  /// should be light enough for dark text to sit on it comfortably.
  static const Color accentTint = Color(0xFFFFF1E8);

  // --------------------------------------------------------------- neutrals

  /// Page background, behind the cards.
  static const Color surface = Color(0xFFF7F8FA);

  /// Card and sheet background.
  static const Color card = Colors.white;

  /// Hairline around a card.
  static const Color border = Color(0xFFEBEDF2);

  /// A heavier border, used on outlined buttons and inputs.
  static const Color borderStrong = Color(0xFFDDE1E8);

  // ------------------------------------------------------------------- text

  /// Headings, prices, anything that must be read first.
  static const Color ink = Color(0xFF0F1319);

  /// Body copy and secondary labels.
  static const Color inkSoft = Color(0xFF4C5563);

  /// Timestamps and hints. Do not put anything important in this colour.
  static const Color inkFaint = Color(0xFF77808E);

  // ----------------------------------------------------------------- status
  // The order lifecycle, in colour. These drive the badges, the customer's
  // progress tracker and the admin dashboard tiles all at once.

  static const Color statusNew = Color(0xFF2563EB); // blue   — waiting
  static const Color statusCooking = Color(0xFFD97706); // amber  — on the stove
  static const Color statusReady = Color(0xFF059669); // green  — serve it
  static const Color statusPaid = Color(0xFF7C3AED); // purple — money taken
  static const Color statusCompleted = Color(0xFF64748B); // grey   — closed

  /// Destructive actions: delete, cancel, sold out.
  static const Color danger = Color(0xFFDC2626);

  /// Customer notes ("no onion"). Deliberately separate from the status ramp,
  /// so restyling one never quietly restyles the other.
  static const Color note = Color(0xFFB45309);
}

/// Shape and type. These are the tokens the whole app is built from — no
/// screen should hard-code a radius or a font size of its own.
abstract class Style {
  /// Corner radius on cards, sheets and photos.
  static const double cardRadius = 16;

  /// Corner radius on buttons, inputs and chips.
  static const double controlRadius = 12;

  /// Corner radius on small things: badges, tags, the quantity stepper.
  static const double smallRadius = 10;

  /// The bundled font family, declared under `flutter: fonts:` in
  /// `pubspec.yaml`. Kantumruy Pro is drawn for Khmer and Latin together, so a
  /// Khmer dish name and an English one share one voice instead of switching
  /// typeface mid-sentence.
  ///
  /// To swap it: drop a `.ttf` into `assets/fonts/`, point `pubspec.yaml` at
  /// it, and change this string to the family name you gave it there. If you
  /// use a Latin-only font, Khmer will fall back to the system face.
  static const String fontFamily = 'KantumruyPro';

  /// How far the app will follow the phone's own text-size setting.
  ///
  /// `1.3` means someone who has turned text up gets larger type here too, but
  /// only to 130% — beyond that a kitchen ticket stops fitting its card.
  /// `test/app_flow_test.dart` renders every screen at this maximum, in both
  /// languages, and fails on any overflow. Raise it and run the tests.
  static const double maxTextScale = 1.3;
}

// =============================================================================
//  3. WHAT THE APP STARTS WITH
// =============================================================================

/// First-run seed data.
///
/// **These only apply to a fresh install.** The app mirrors its state into the
/// device's local storage after every change, so on second launch it restores
/// what was there rather than re-reading this file. To pick up a change here,
/// either use **Admin → Settings → Reset demo data**, or delete and reinstall
/// the app.
abstract class Seed {
  /// How many tables to create on first run, numbered `01`, `02`, … Each one
  /// gets its own QR code, printable from Admin → Tables.
  static const int tableCount = 10;

  /// The number the first order of the demo day is given. Real orders continue
  /// upward from the last demo order.
  static const int firstOrderNumber = 101;

  // ------------------------------------------------------------- staff logins
  // The prototype prints these on the sign-in screen so anyone can open it.
  // A real deployment would force a change on first run.
  //
  // Passwords and PINs are never stored as typed — they are salted, iterated
  // HMAC-SHA256 and compared in constant time. That is the right shape, but it
  // is not a substitute for a server: anyone with access to the device can
  // edit what is on the device.

  /// The owner signs in with a username and password and can do everything.
  static const String adminUsername = 'admin';
  static const String adminPassword = 'admin1234';
  static const String adminDisplayName = 'Restaurant Owner';

  /// Kitchen and cashier tap their name and key in a PIN.
  /// **PINs must be exactly six digits** — the pad signs in on the sixth key,
  /// so a shorter or longer PIN can never be entered.
  static const String kitchenName = 'Sophal';
  static const String kitchenPin = '110011';

  static const String cashierName = 'Bopha';
  static const String cashierPin = '220022';
}

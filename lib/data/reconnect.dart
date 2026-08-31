import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Tells you when the device has picked up a network again.
///
/// A hint, not a promise. `connectivity_plus` reports what the device is
/// *attached* to — a wifi access point, a mobile network — and a restaurant
/// router that has come back up but has no line to the internet looks exactly
/// like one that works. So this is a reason to try again, never evidence that
/// trying will succeed.
///
/// That is enough, because trying again is cheap and safe: sending an order
/// twice places it once (see `0013_idempotent_orders.sql`), and an attempt that
/// fails leaves the order where it was.
///
/// Wrapped rather than used directly so the widget that listens can be tested
/// without a plugin channel, and so swapping the package later touches one
/// file.
abstract class Reconnect {
  /// Fires each time the device goes from having no network to having one.
  ///
  /// Deliberately only that edge. The raw stream also reports a change from
  /// wifi to mobile and back, which would set off a flush on a phone walking
  /// past the door.
  static Stream<void> hints() {
    var wasOffline = false;
    return Connectivity().onConnectivityChanged.expand((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      final cameBack = online && wasOffline;
      wasOffline = !online;
      return cameBack ? const [null] : const [];
    });
  }
}

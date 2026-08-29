import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/config/backend_config.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stranger with a phone camera and no account.
///
/// This is the whole premise of a QR ordering app: the sticker is on a public
/// table, anybody may scan it, and what they get has to be the menu. Not a
/// sign-in, not a merchant ID, not a device-setup screen — those exist for the
/// tablet behind the counter and must never reach a diner.
///
/// The app mounts *cold* here, with the deep link as its initial route, which
/// is what actually happens when a camera opens the link in a browser tab.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Boots the app the way a scanned link does: the route is already set
  /// before the first frame, rather than pushed later by a test.
  Future<AppStore> boot(WidgetTester tester, String route) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = route;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );

    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    addTearDown(store.dispose);

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const RestaurantApp(),
    ));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('a cold open on a table link lands on that table, signed in as '
      'nobody', (tester) async {
    final store = await boot(tester, '/order/${BackendConfig.slug}/table/05');

    expect(store.activeTable?.number, '05',
        reason: 'the sticker named table 05');
    expect(store.isSignedIn, isFalse, reason: 'a diner has no account');
    expect(store.mode, AppMode.customer);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the diner can read the menu and order without an account',
      (tester) async {
    final store = await boot(tester, '/order/${BackendConfig.slug}/table/05');
    final before = store.orders.length;

    // Add the first dish straight from its card, the way a diner would.
    await tester.tap(find.text(store.text.add).first);
    await tester.pumpAndSettle();
    expect(store.cartItemCount, 1);

    await tester.tap(find.text(store.text.viewOrder));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 
        '${store.text.submitOrder}  ·  ${store.money(store.cartTotal)}'));
    await tester.pumpAndSettle();

    expect(store.orders.length, before + 1, reason: 'the kitchen heard it');
    final placed = store.orders.last;
    expect(placed.tableNumber, '05');
    expect(placed.placedBy, isNull, reason: 'no member of staff was involved');
    expect(tester.takeException(), isNull);
  });

  // Each sticker is its own cold open, which is what a second diner at another
  // table actually is: a different phone, a different link.
  for (final number in ['01', '03', '05']) {
    testWidgets('table $number opens table $number', (tester) async {
      final store = await boot(tester, '/order/${BackendConfig.slug}/table/$number');
      expect(store.activeTable?.number, number);
      expect(tester.takeException(), isNull);
    });
  }
}

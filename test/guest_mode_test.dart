import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/guest_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Looking round without an account.
///
/// Somebody who has just downloaded the app has no merchant ID and nobody to
/// ask for one. What matters here is that they can get in, that they are told
/// plainly that none of it is real, and that the way out exists.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStore> pump(WidgetTester tester, {required bool guest}) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    addTearDown(store.dispose);
    await store.load();

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: RestaurantApp(
          guest: guest,
          // A guest always has a way out, which is what makes the banner's
          // action appear.
          onRebind: guest ? () async {} : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  group('the flag on the device', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('is off until somebody asks to look round', () async {
      expect(await GuestMode.isOn(), isFalse);
    });

    test('survives a restart — the demo is where they left it', () async {
      await GuestMode.enter();
      expect(await GuestMode.isOn(), isTrue);
    });

    test('and comes off when they set up their own restaurant', () async {
      await GuestMode.enter();
      await GuestMode.leave();
      expect(await GuestMode.isOn(), isFalse);
    });
  });

  group('what a guest sees', () {
    testWidgets('a standing reminder that none of it is real', (tester) async {
      final store = await pump(tester, guest: true);
      final t = store.text;

      expect(find.text(t.guestMode), findsOneWidget);
      expect(find.text(t.leaveGuestMode), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and the menu underneath it, working', (tester) async {
      final store = await pump(tester, guest: true);
      // The demo is the whole product, not a screenshot of it: a real menu
      // from the seeded restaurant, orderable.
      expect(store.menuItems, isNotEmpty);
      expect(find.text(store.text.guestMode), findsOneWidget);
    });

    testWidgets('leaving is asked about, not done on the first tap',
        (tester) async {
      final store = await pump(tester, guest: true);
      final t = store.text;

      await tester.tap(find.text(t.leaveGuestMode).first);
      await tester.pumpAndSettle();

      // A confirm dialog, because it closes the demo and asks for credentials
      // the visitor may not have to hand.
      expect(find.text(t.leaveGuestModeBody), findsOneWidget);
      expect(find.text(t.cancel), findsOneWidget);
    });
  });

  testWidgets('a real restaurant is never told it is a demo', (tester) async {
    final store = await pump(tester, guest: false);
    expect(find.text(store.text.guestMode), findsNothing);
    expect(find.text(store.text.leaveGuestMode), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/demo_data.dart';
import 'package:restaurant_qr_ordering/data/guest_mode.dart';
import 'package:restaurant_qr_ordering/models/staff_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Looking round without an account.
///
/// Somebody who has just downloaded the app has no merchant ID and nobody to
/// ask for one. What matters here is that they can get in, that they are told
/// plainly that none of it is real, and that the way out exists.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStore> pump(
    WidgetTester tester, {
    required bool guest,
    // The session bar drops the labels off its mode toggle below 560, so a
    // test that reads them needs the room.
    Size size = const Size(420, 900),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    addTearDown(store.dispose);
    await store.load();

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
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

  group('what a guest gets to play with', () {
    /// A guest is put behind the owner's desk, which is what the bootstrap
    /// does for them on the boot that follows choosing to look round.
    Future<AppStore> asGuestOwner(WidgetTester tester,
        {Size size = const Size(420, 900)}) async {
      final store = await pump(tester, guest: true, size: size);
      // Hashing is deliberately slow, and inside a widget test its timer only
      // fires while the tester pumps — so the pump has to happen with the
      // future still in flight rather than after awaiting it.
      final pending = store.signInWithPassword(
          DemoData.adminEmail, DemoData.adminPassword);
      await tester.pumpAndSettle();
      expect(await pending, isTrue);
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('the owner\'s home, not the diner\'s menu', (tester) async {
      final store = await asGuestOwner(tester);
      final t = store.text;

      expect(store.currentUser?.role, StaffRole.admin);
      expect(store.mode, AppMode.staff);
      // The owner's workspace, with its tabs — not the diner's menu, which is
      // the one screen they could have seen without downloading anything.
      for (final tab in [t.dashboard, t.kitchen, t.roleCashier, t.more]) {
        expect(find.text(tab), findsWidgets, reason: tab);
      }
    });

    testWidgets('and the kitchen and the till are a tap away', (tester) async {
      final store = await asGuestOwner(tester);
      final t = store.text;

      // The owner is a superset of both roles, so no password stands between
      // a visitor and either of them.
      await tester.tap(find.text(t.kitchen).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(t.roleCashier).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('and so is the diner\'s side', (tester) async {
      final store = await asGuestOwner(tester, size: const Size(760, 900));
      final t = store.text;

      await tester.tap(find.text(t.customerView).last);
      await tester.pumpAndSettle();

      expect(store.mode, AppMode.customer);
      expect(tester.takeException(), isNull);
    });

  });
}

@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/demo_data.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/models/staff_account.dart';
import 'package:restaurant_qr_ordering/widgets/order_ticket.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the main screens to PNGs so the design can be reviewed without a
/// browser. Regenerate with:
///
///     flutter test --update-goldens test/design
///
/// These are reference images, not assertions about pixels — review them by
/// eye and re-record when the design changes on purpose.
/// Set `DESIGN_SHOTS=1` to run these. They are skipped in a normal
/// `flutter test` so an intentional design change does not read as a failure.
final bool _enabled = Platform.environment['DESIGN_SHOTS'] == '1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('KantumruyPro')
      ..addFont(rootBundle.load('assets/fonts/KantumruyPro.ttf'));
    await loader.load();
  });

  /// Signs the store in as [role] and shows that workspace.
  ///
  /// Sign-in is async (hashing is deliberately slow), and inside a widget test
  /// its timer only fires when the tester pumps — so the pump has to happen
  /// while the future is still in flight, not after awaiting it.
  Future<void> signIn(
    WidgetTester tester,
    AppStore store,
    StaffRole role,
  ) async {
    final pending = role == StaffRole.admin
        ? store.signInWithPassword(
            DemoData.adminUsername, DemoData.adminPassword)
        : store.signInWithPin(
            store.accounts.firstWhere((a) => a.role == role).id,
            role == StaffRole.kitchen
                ? DemoData.kitchenPin
                : DemoData.cashierPin,
          );
    await tester.pumpAndSettle();
    expect(await pending, isTrue);
    store.setMode(AppMode.staff);
    await tester.pumpAndSettle();
  }

  Future<AppStore> pump(
    WidgetTester tester, {
    Size size = const Size(400, 860),
    AppLanguage language = AppLanguage.en,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    // The store debounces its writes, so a pending timer would outlive the
    // widget tree and trip the test binding's invariant check.
    addTearDown(store.dispose);
    store.setLanguage(language);

    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = size * 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: const RestaurantApp(),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  /// Images decode asynchronously; without this the goldens capture grey boxes.
  Future<void> settleImages(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final widget = element.widget as Image;
        await precacheImage(widget.image, element);
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pumpAndSettle();
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await settleImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/$name.png'),
    );
  }

  testWidgets(skip: !_enabled, 'customer menu', (tester) async {
    final store = await pump(tester);
    store.openTable(store.tableByNumber('05')!.id);
    store.addToCart(store.menuItem('food-01')!, quantity: 2);
    await tester.pumpAndSettle();
    await shoot(tester, '01-customer-menu');
  });

  testWidgets(skip: !_enabled, 'customer cart', (tester) async {
    final store = await pump(tester);
    store.openTable(store.tableByNumber('05')!.id);
    store.addToCart(store.menuItem('food-01')!, quantity: 2, note: 'No onion');
    store.addToCart(store.menuItem('food-06')!);
    await tester.pumpAndSettle();
    await tester.tap(find.text(store.text.viewOrder));
    await tester.pumpAndSettle();
    await shoot(tester, '02-customer-cart');
  });

  testWidgets(skip: !_enabled, 'customer tracker', (tester) async {
    final store = await pump(tester);
    store.openTable(store.tableByNumber('05')!.id);
    store.addToCart(store.menuItem('food-01')!);
    final order = store.submitOrder();

    // The kitchen has to be signed in to move the order along.
    await signIn(tester, store, StaffRole.kitchen);
    store.startCooking(order.id);
    store.signOut();

    await tester.pumpAndSettle();
    await tester.tap(find.text(store.text.myOrderTab));
    await tester.pumpAndSettle();
    await shoot(tester, '03-customer-tracker');
  });

  testWidgets(skip: !_enabled, 'kitchen board', (tester) async {
    final store = await pump(tester, size: const Size(900, 760));
    await signIn(tester, store, StaffRole.kitchen);
    await tester.pumpAndSettle();
    await shoot(tester, '04-kitchen');
  });

  testWidgets(skip: !_enabled, 'cashier', (tester) async {
    final store = await pump(tester);
    await signIn(tester, store, StaffRole.cashier);
    await tester.pumpAndSettle();
    await shoot(tester, '05-cashier');
  });

  testWidgets(skip: !_enabled, 'cashier taking an order at the counter',
      (tester) async {
    final store = await pump(tester);
    await signIn(tester, store, StaffRole.cashier);
    await tester.pumpAndSettle();
    await tester.tap(find.text(store.text.newOrder));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle_rounded).first);
    await tester.pumpAndSettle();
    await shoot(tester, '14-cashier-new-order');
  });

  testWidgets(skip: !_enabled, 'cashier editing what is on an order',
      (tester) async {
    final store = await pump(tester);
    store.openTable(store.tableByNumber('10')!.id);
    store.addToCart(store.menuItem('food-01')!, quantity: 2);
    store.addToCart(store.menuItem('food-06')!, note: 'Less ice');
    final order = store.submitOrder();

    // A second order after it, so the ticket being edited is not the last card
    // on the board: scrolling to the bottom would otherwise leave its buttons
    // underneath the New order FAB, which then swallows the tap.
    store.addToCart(store.menuItem('food-02')!);
    final below = store.submitOrder();

    await signIn(tester, store, StaffRole.cashier);
    await tester.pumpAndSettle();

    // The demo seed already has orders on the floor, so these sort below the
    // fold on a phone.
    await tester.dragUntilVisible(
      find.text(store.text.orderNo(below.orderNumber)),
      find.byType(ListView).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.ancestor(
        of: find.text(store.text.orderNo(order.orderNumber)),
        matching: find.byType(OrderTicket),
      ),
      matching: find.text(store.text.editItems),
    ));
    await tester.pumpAndSettle();

    expect(find.text(store.text.editItemsBody), findsOneWidget);
    await shoot(tester, '16-cashier-edit-order');
  });

  testWidgets(skip: !_enabled, 'the table picker a takeaway order gets',
      (tester) async {
    final store = await pump(tester);
    store.startTakeaway();
    store.addToCart(store.menuItem('food-01')!, quantity: 2);
    await tester.pumpAndSettle();
    await tester.tap(find.text(store.text.dineIn).first);
    await tester.pumpAndSettle();
    await shoot(tester, '15-table-picker');
  });

  testWidgets(skip: !_enabled, 'admin dashboard', (tester) async {
    final store = await pump(tester);
    await signIn(tester, store, StaffRole.admin);
    await tester.pumpAndSettle();
    await shoot(tester, '06-admin-dashboard');
  });

  testWidgets(skip: !_enabled, 'admin menu management', (tester) async {
    final store = await pump(tester);
    await signIn(tester, store, StaffRole.admin);
    store.updateMenuItem(store.menuItem('food-02')!.copyWith(
      discountPercent: 20,
      signature: true,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(store.text.menu).last);
    await tester.pumpAndSettle();
    await shoot(tester, '07-admin-menu');
  });

  testWidgets(skip: !_enabled, 'staff sign in', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.lock_open_rounded));
    await tester.pumpAndSettle();
    await shoot(tester, '09-sign-in');
  });

  testWidgets(skip: !_enabled, 'pin pad', (tester) async {
    final store = await pump(tester);
    await tester.tap(find.byIcon(Icons.lock_open_rounded));
    await tester.pumpAndSettle();
    final kitchen =
        store.accounts.firstWhere((a) => a.role == StaffRole.kitchen);
    await tester.tap(find.text(kitchen.name).first);
    await tester.pumpAndSettle();
    await shoot(tester, '10-pin-pad');
  });

  testWidgets(skip: !_enabled, 'staff management', (tester) async {
    final store = await pump(tester);
    await signIn(tester, store, StaffRole.admin);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(store.text.staff).last);
    await tester.pumpAndSettle();
    await shoot(tester, '11-staff');
  });

  testWidgets(skip: !_enabled, 'takeaway cart', (tester) async {
    final store = await pump(tester);
    store.startTakeaway();
    store.addToCart(store.menuItem('food-01')!, quantity: 2);
    store.addToCart(store.menuItem('food-06')!);
    await tester.pumpAndSettle();
    await tester.tap(find.text(store.text.viewOrder));
    await tester.pumpAndSettle();
    await shoot(tester, '12-takeaway-cart');
  });

  testWidgets(skip: !_enabled, 'kitchen with a takeaway ticket',
      (tester) async {
    final store = await pump(tester, size: const Size(900, 760));
    store.startTakeaway();
    store.addToCart(store.menuItem('food-01')!, quantity: 2);
    store.submitOrder();
    await signIn(tester, store, StaffRole.kitchen);
    await tester.pumpAndSettle();
    await shoot(tester, '13-kitchen-takeaway');
  });

  testWidgets(skip: !_enabled, 'customer menu in Khmer', (tester) async {
    final store = await pump(tester, language: AppLanguage.km);
    store.openTable(store.tableByNumber('05')!.id);
    store.addToCart(store.menuItem('food-01')!);
    await tester.pumpAndSettle();
    await shoot(tester, '08-customer-menu-khmer');
  });
}

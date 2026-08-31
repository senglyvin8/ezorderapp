import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/widgets/session_bar.dart';
import 'package:restaurant_qr_ordering/data/demo_data.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/models/order.dart';
import 'package:restaurant_qr_ordering/models/plan.dart';
import 'package:restaurant_qr_ordering/widgets/upgrade_sheet.dart';
import 'package:restaurant_qr_ordering/screens/customer/food_detail_sheet.dart';
import 'package:restaurant_qr_ordering/models/staff_account.dart';
import 'package:restaurant_qr_ordering/widgets/cart_summary_bar.dart';
import 'package:restaurant_qr_ordering/widgets/food_image.dart';
import 'package:restaurant_qr_ordering/widgets/order_ticket.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke tests that actually render the app.
///
/// Their real job is catching layout breakage: a RenderFlex overflow throws
/// during `pump`, so these fail loudly if a Khmer label — usually longer than
/// its English counterpart — no longer fits its button or tab.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  /// Steps past the staff sign-in the installed app now opens on.
  ///
  /// `flutter test` is a non-web build, so the shell greets it as a staff
  /// device. Tests about the diner's side take the same door staff take.
  Future<void> browseAsCustomer(WidgetTester tester, AppStore store) async {
    await tester.tap(find.text(store.text.browseAsCustomer));
    await tester.pumpAndSettle();
  }

  Future<AppStore> pumpApp(
    WidgetTester tester, {
    Size? size,
    double textScale = 1.0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    // The store debounces its writes, so a pending timer would outlive the
    // widget tree and trip the test binding's invariant check.
    addTearDown(store.dispose);

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size ?? const Size(420, 900);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: const RestaurantApp(),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  for (final language in AppLanguage.values) {
    group('renders in ${language.name}', () {
      testWidgets('every role screen lays out on a phone', (tester) async {
        final store = await pumpApp(tester);
        store.setLanguage(language);
        await tester.pumpAndSettle();

        // Signed out: the customer experience.
        store.setMode(AppMode.customer);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'customer screen threw in ${language.name}');

        for (final role in StaffRole.values) {
          await store.signOut();
          await signIn(tester, store, role);
          expect(tester.takeException(), isNull,
              reason: '${role.name} workspace threw in ${language.name}');
        }
      });

      testWidgets('the customer menu and cart lay out', (tester) async {
        final store = await pumpApp(tester);
        store.setLanguage(language);
        store.openTable(store.tableByNumber('05')!.id);
        await tester.pumpAndSettle();

        store.addToCart(store.menuItem('food-01')!, quantity: 2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byIcon(Icons.shopping_bag_rounded).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('the admin reaches the dish editor through Manage',
          (tester) async {
        final store = await pumpApp(tester);
        store.setLanguage(language);
        await signIn(tester, store, StaffRole.admin);
        await tester.pumpAndSettle();

        // Manage tab -> Menu -> first dish.
        await tester.tap(find.byIcon(Icons.tune_rounded).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(store.text.menu).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
        await tester.pumpAndSettle();

        expect(find.text(store.text.editDish), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('a tablet-width kitchen board lays out', (tester) async {
    final store = await pumpApp(tester, size: const Size(1024, 768));
    await signIn(tester, store, StaffRole.kitchen);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    store.setLanguage(AppLanguage.km);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cooking an order keeps it in the New tab', (tester) async {
    final store = await pumpApp(tester, size: const Size(800, 1000));
    await signIn(tester, store, StaffRole.kitchen);
    await tester.pumpAndSettle();

    final t = store.text;
    expect(find.text(t.startCooking), findsWidgets);

    await tester.tap(find.text(t.startCooking).first);
    await tester.pumpAndSettle();

    // Still on the New tab, now offering the second step.
    expect(find.text(t.readyToServe), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('cart summary bar', () {
    testWidgets('appears on the first add and tracks the running total',
        (tester) async {
      final store = await pumpApp(tester);
      store.openTable(store.tableByNumber('05')!.id);
      await tester.pumpAndSettle();

      expect(find.byType(CartSummaryBar), findsOneWidget);
      expect(find.text(store.text.viewOrder), findsNothing);

      // Quick-add the first dish from its card.
      await tester.tap(find.text(store.text.add).first);
      await tester.pumpAndSettle();

      final item = store.itemsInCategory(kPopularCategoryId).first;
      expect(find.text(store.text.viewOrder), findsOneWidget);
      expect(find.text(store.text.itemsCount(1)), findsOneWidget);
      expect(find.text(store.money(item.effectivePrice)), findsWidgets);

      // A second add updates the total in place.
      await tester.tap(find.text(store.text.add).first);
      await tester.pumpAndSettle();
      expect(find.text(store.text.itemsCount(2)), findsOneWidget);
      expect(store.cartTotal, closeTo(item.effectivePrice * 2, 0.001));
    });

    testWidgets('tapping it opens the order summary', (tester) async {
      final store = await pumpApp(tester);
      store.openTable(store.tableByNumber('05')!.id);
      store.addToCart(store.menuItem('food-01')!);
      await tester.pumpAndSettle();

      await tester.tap(find.text(store.text.viewOrder));
      await tester.pumpAndSettle();

      expect(find.text(store.text.yourOrder), findsOneWidget);
      expect(find.text(store.text.reviewBeforeSubmit), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('items can be removed from the summary before submitting',
        (tester) async {
      final store = await pumpApp(tester);
      store.openTable(store.tableByNumber('05')!.id);
      store.addToCart(store.menuItem('food-01')!);
      store.addToCart(store.menuItem('food-06')!);
      await tester.pumpAndSettle();

      await tester.tap(find.text(store.text.viewOrder));
      await tester.pumpAndSettle();
      expect(store.cart.length, 2);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      expect(store.cart.length, 1);
      expect(find.text(store.money(store.cartTotal)), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bar disappears once the order is submitted',
        (tester) async {
      final store = await pumpApp(tester);
      store.openTable(store.tableByNumber('05')!.id);
      store.addToCart(store.menuItem('food-01')!);
      await tester.pumpAndSettle();
      expect(find.text(store.text.viewOrder), findsOneWidget);

      await store.submitOrder();
      await tester.pumpAndSettle();
      expect(find.text(store.text.viewOrder), findsNothing);
    });
  });

  testWidgets('switching language swaps the whole menu', (tester) async {
    final store = await pumpApp(tester);
    store.openTable(store.tableByNumber('05')!.id);
    await tester.pumpAndSettle();

    final dish = store.menuItem('food-01')!;
    final category = store.sortedCategories.first;

    // The app opens in Khmer — see Brand.defaultLanguage.
    expect(store.language, AppLanguage.km);
    expect(find.text(dish.nameKm), findsOneWidget);
    expect(find.text(category.nameKm), findsOneWidget);
    expect(find.text(dish.name), findsNothing);

    // The customer taps the language mark in the bar.
    await tester.tap(find.byKey(languageToggleKey));
    await tester.pumpAndSettle();

    expect(find.text(dish.name), findsOneWidget);
    expect(find.text(dish.description), findsOneWidget);
    expect(find.text(category.name), findsOneWidget);
    expect(find.text(dish.nameKm), findsNothing);
    expect(find.text(store.text.browsingAsCustomer), findsOneWidget);

    // And back again, so the mark is a real toggle rather than a one-way trip.
    await tester.tap(find.byKey(languageToggleKey));
    await tester.pumpAndSettle();

    expect(find.text(dish.nameKm), findsOneWidget);
    expect(find.text(dish.name), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('sign in', () {
    testWidgets('a signed-out visitor gets the customer app, not a workspace',
        (tester) async {
      final store = await pumpApp(tester);
      final t = store.text;
      await browseAsCustomer(tester, store);

      expect(find.text(t.browsingAsCustomer), findsOneWidget);
      expect(find.text(t.kitchen), findsNothing);
      expect(find.text(t.dashboard), findsNothing);
      expect(find.text(t.staff), findsNothing);
    });

    testWidgets('kitchen staff sign in with a PIN and land in the kitchen',
        (tester) async {
      final store = await pumpApp(tester);
      final t = store.text;

      // The installed app opens here; nothing to tap to get in.
      expect(find.text(t.chooseYourName), findsOneWidget);

      final kitchen =
          store.accounts.firstWhere((a) => a.role == StaffRole.kitchen);
      await tester.tap(find.text(kitchen.name).first);
      await tester.pumpAndSettle();
      expect(find.text(t.enterPin), findsOneWidget);

      for (final digit in DemoData.kitchenPin.split('')) {
        await tester.tap(find.widgetWithText(InkWell, digit).last);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(store.currentUser?.role, StaffRole.kitchen);
      expect(find.textContaining(t.tabNew), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a wrong PIN keeps the door shut', (tester) async {
      final store = await pumpApp(tester);

      final kitchen =
          store.accounts.firstWhere((a) => a.role == StaffRole.kitchen);
      await tester.tap(find.text(kitchen.name).first);
      await tester.pumpAndSettle();

      for (final digit in '999999'.split('')) {
        await tester.tap(find.widgetWithText(InkWell, digit).last);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(store.isSignedIn, isFalse);
      expect(find.text(store.text.wrongPin), findsOneWidget);
    });

    testWidgets('kitchen staff never see the admin tabs', (tester) async {
      final store = await pumpApp(tester);
      await signIn(tester, store, StaffRole.kitchen);
      await tester.pumpAndSettle();
      final t = store.text;

      expect(find.textContaining(t.tabNew), findsWidgets);
      expect(find.text(t.dashboard), findsNothing);
      expect(find.text(t.more), findsNothing);
      expect(find.text(t.roleCashier), findsNothing);
    });

    testWidgets('only the admin workspace offers Manage', (tester) async {
      final store = await pumpApp(tester);
      await signIn(tester, store, StaffRole.admin);
      await tester.pumpAndSettle();

      expect(find.text(store.text.more), findsWidgets);
      expect(find.text(store.text.dashboard), findsWidgets);
    });

    testWidgets('signing out puts the device back behind sign-in',
        (tester) async {
      final store = await pumpApp(tester);
      await signIn(tester, store, StaffRole.cashier);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();

      expect(store.isSignedIn, isFalse);
      // A till whose cashier has gone home should ask for a PIN, not sit on
      // the diner's menu waiting for anybody to pick it up.
      expect(find.text(store.text.chooseYourName), findsOneWidget);
    });
  });

  group('takeaway', () {
    testWidgets('a customer can order takeaway without scanning a table',
        (tester) async {
      final store = await pumpApp(tester);
      final t = store.text;
      await browseAsCustomer(tester, store);

      await tester.tap(find.text(t.startTakeaway));
      await tester.pumpAndSettle();

      // Straight into the menu, headed Takeaway rather than a table.
      expect(find.text(t.takeaway), findsWidgets);
      expect(store.activeTable, isNull);

      await tester.tap(find.text(t.add).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.viewOrder));
      await tester.pumpAndSettle();

      expect(find.text(t.orderTypeQuestion), findsOneWidget);
      expect(store.orderType, OrderType.takeaway);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the kitchen ticket shouts TAKEAWAY instead of a table',
        (tester) async {
      final store = await pumpApp(tester, size: const Size(500, 900));
      store.startTakeaway();
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();

      await signIn(tester, store, StaffRole.kitchen);
      await tester.pumpAndSettle();

      expect(find.text(store.text.takeaway.toUpperCase()), findsWidgets);
      expect(store.order(order.id)!.tableNumber, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a dine-in customer still sees their table', (tester) async {
      final store = await pumpApp(tester);
      store.openTable(store.tableByNumber('05')!.id);
      await tester.pumpAndSettle();

      expect(find.text(store.text.table('05')), findsWidgets);
      expect(store.orderType, OrderType.dineIn);
    });
  });

  group('large text', () {
    // The app caps scaling at 1.3x, so this is the worst case a reader who has
    // turned text up on their phone can produce. Nothing may overflow.
    for (final language in AppLanguage.values) {
      testWidgets('every workspace survives 1.3x text in ${language.name}',
          (tester) async {
        final store = await pumpApp(tester, textScale: 1.3);
        store.setLanguage(language);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'customer entry');

        store.openTable(store.tableByNumber('05')!.id);
        store.addToCart(store.menuItem('food-01')!, quantity: 2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'menu');

        await tester.tap(find.text(store.text.viewOrder));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'cart');

        for (final role in StaffRole.values) {
          await store.signOut();
          await signIn(tester, store, role);
          expect(tester.takeException(), isNull,
              reason: '${role.name} at 1.3x in ${language.name}');
        }
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('the counter order screen survives 1.3x in ${language.name}',
          (tester) async {
        final store = await pumpApp(tester, textScale: 1.3);
        store.setLanguage(language);
        await signIn(tester, store, StaffRole.cashier);
        await tester.pumpAndSettle();

        await tester.tap(find.text(store.text.newOrder));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'counter order screen');

        await tester.tap(find.byIcon(Icons.add_circle_rounded).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'after adding a dish');

        // Dine in with no table opens the picker — the widest chrome here.
        await tester.tap(find.text(store.text.dineIn).first);
        await tester.pumpAndSettle();
        expect(find.text(store.text.chooseTable), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'table picker');
      });
    }

    testWidgets('the kitchen board survives 1.3x on a tablet', (tester) async {
      final store = await pumpApp(tester,
          size: const Size(1024, 768), textScale: 1.3);
      store.setLanguage(AppLanguage.km);
      await signIn(tester, store, StaffRole.kitchen);
      expect(tester.takeException(), isNull);
    });
  });

  group('picking a table instead of losing the cart', () {
    testWidgets('tapping Dine in from Takeaway asks which table',
        (tester) async {
      final store = await pumpApp(tester);
      final t = store.text;

      store.startTakeaway();
      store.addToCart(store.menuItem('food-01')!, quantity: 2);
      await tester.pumpAndSettle();

      // The Dine in segment on the menu strip.
      await tester.tap(find.text(t.dineIn).first);
      await tester.pumpAndSettle();

      expect(find.text(t.chooseTable), findsOneWidget);
      // Still on the menu with the basket intact — the old behaviour threw
      // the customer back to the QR screen and emptied it.
      expect(store.cartItemCount, 2);

      await tester.tap(find.text(t.table('04')));
      await tester.pumpAndSettle();

      expect(store.orderType, OrderType.dineIn);
      expect(store.activeTable?.number, '04');
      expect(store.cartItemCount, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dismissing the picker leaves the order on takeaway',
        (tester) async {
      final store = await pumpApp(tester);
      final t = store.text;

      store.startTakeaway();
      store.addToCart(store.menuItem('food-01')!);
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.dineIn).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(store.orderType, OrderType.takeaway);
      expect(store.cartItemCount, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('typing with the keyboard up', () {
    testWidgets('the dish sheet stays on screen and its note field is reachable',
        (tester) async {
      final store = await pumpApp(tester, size: const Size(400, 800));
      store.openTable(store.tableByNumber('05')!.id);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FoodImage).first);
      await tester.pumpAndSettle();
      expect(find.text(store.text.specialRequest), findsOneWidget);

      // A keyboard covering more than half the screen. The sheet lifts itself
      // by that much, so if it is still sized against the *whole* screen it
      // becomes taller than the room left. A ConstrainedBox is not clamped by
      // the space its parent has — it keeps its maxHeight and overflows — and
      // in a bottom-anchored sheet that overflow goes off the top, taking the
      // note field with it.
      tester.view.viewInsets = const FakeViewPadding(bottom: 427);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'the sheet must fit the space the keyboard leaves');
      // The action carries the running total alongside the label.
      final addToCart = find.textContaining(store.text.addToCart);
      expect(addToCart, findsOneWidget,
          reason: 'and its action bar must still be on screen');
      final action = tester.getRect(addToCart);
      expect(action.bottom, lessThanOrEqualTo(800 - 427 + 1),
          reason: 'sitting above the keyboard, not behind it');
    });
  });

  group('the cashier front desk', () {
    // A desk-sized window so every live ticket is on screen at once: the demo
    // seed already has four orders on the floor, and the one each test places
    // sorts to the bottom of the list.
    const desk = Size(1100, 1800);

    /// The cancel button belonging to one specific ticket, so a seeded order's
    /// button is never mistaken for the one under test.
    Finder cancelButtonFor(AppText t, Order order) => find.descendant(
          of: find.ancestor(
            of: find.text(t.orderNo(order.orderNumber)),
            matching: find.byType(OrderTicket),
          ),
          matching: find.text(t.cancelOrder),
        );

    Future<Order> placeOrder(AppStore store) async {
      store.openTable(store.tableByNumber('10')!.id);
      store.addToCart(store.menuItem('food-01')!);
      return store.submitOrder();
    }

    testWidgets('sees every live order, not just the payable ones',
        (tester) async {
      final store = await pumpApp(tester, size: desk);
      final t = store.text;
      final order = await placeOrder(store);

      await signIn(tester, store, StaffRole.cashier);
      await tester.pumpAndSettle();

      // A brand-new order is not payable yet, but it is on the Live tab.
      expect(store.order(order.id)!.status, OrderStatus.newOrder);
      expect(find.text(t.orderNo(order.orderNumber)), findsOneWidget);
      expect(cancelButtonFor(t, order), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancels a queued order for the customer', (tester) async {
      final store = await pumpApp(tester, size: desk);
      final t = store.text;
      final order = await placeOrder(store);

      await signIn(tester, store, StaffRole.cashier);
      await tester.pumpAndSettle();

      await tester.tap(cancelButtonFor(t, order));
      await tester.pumpAndSettle();
      // The dialog's confirm carries the same label; it is the last one added.
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(t.cancelOrder),
      ));
      await tester.pumpAndSettle();

      expect(store.order(order.id)!.status, OrderStatus.cancelled);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an order the kitchen has started offers no cancel button',
        (tester) async {
      final store = await pumpApp(tester, size: desk);
      final t = store.text;
      final order = await placeOrder(store);

      await signIn(tester, store, StaffRole.admin);
      await store.startCooking(order.id);
      await store.signOut();
      await signIn(tester, store, StaffRole.cashier);
      await tester.pumpAndSettle();

      expect(find.text(t.orderNo(order.orderNumber)), findsOneWidget);
      expect(cancelButtonFor(t, order), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('takes a dish off an order for the customer', (tester) async {
      final store = await pumpApp(tester, size: desk);
      final t = store.text;
      store.openTable(store.tableByNumber('10')!.id);
      store.addToCart(store.menuItem('food-01')!, quantity: 2);
      store.addToCart(store.menuItem('food-06')!);
      final order = await store.submitOrder();
      final drink = order.items.last;

      await signIn(tester, store, StaffRole.cashier);
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.ancestor(
          of: find.text(t.orderNo(order.orderNumber)),
          matching: find.byType(OrderTicket),
        ),
        matching: find.text(t.editItems),
      ));
      await tester.pumpAndSettle();

      // Remove the drink, leaving the dish.
      await tester.tap(find.text(t.removeDish).last);
      await tester.pumpAndSettle();

      final updated = store.order(order.id)!;
      expect(updated.items, hasLength(1));
      expect(updated.items.any((i) => i.id == drink.id), isFalse);
      expect(updated.total, updated.items.first.lineTotal);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an order the kitchen has started cannot be edited',
        (tester) async {
      final store = await pumpApp(tester, size: desk);
      final t = store.text;
      store.openTable(store.tableByNumber('10')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();

      await signIn(tester, store, StaffRole.admin);
      await store.startCooking(order.id);
      await store.signOut();
      await signIn(tester, store, StaffRole.cashier);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text(t.orderNo(order.orderNumber)),
            matching: find.byType(OrderTicket),
          ),
          matching: find.text(t.editItems),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('takes a takeaway order at the counter', (tester) async {
      final store = await pumpApp(tester, size: const Size(500, 900));
      final t = store.text;
      final before = store.orders.length;

      await signIn(tester, store, StaffRole.cashier);
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.newOrder));
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.takeaway).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sendToKitchen));
      await tester.pumpAndSettle();

      expect(store.orders.length, before + 1);
      final placed = store.orders.last;
      expect(placed.isTakeaway, isTrue);
      expect(placed.status, OrderStatus.newOrder);
      expect(placed.placedBy, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a counter order does not disturb the customer cart',
        (tester) async {
      final store = await pumpApp(tester, size: const Size(500, 900));
      final t = store.text;
      store.openTable(store.tableByNumber('10')!.id);
      store.addToCart(store.menuItem('food-02')!, quantity: 3);

      await signIn(tester, store, StaffRole.cashier);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.newOrder));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.takeaway).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sendToKitchen));
      await tester.pumpAndSettle();

      expect(store.cartItemCount, 3);
      expect(store.activeTable?.number, '10');
      expect(tester.takeException(), isNull);
    });
  });

  group('the menu scrolls as one list', () {
    /// The label of whichever category chip is currently lit. The chips are
    /// the only white 14.5pt text in the bar — the Dine in / Takeaway segments
    /// are a size smaller.
    String selectedChip(WidgetTester tester) {
      final lit = tester
          .widgetList<Text>(find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(Text),
          ))
          .where((text) =>
              text.style?.color == Colors.white &&
              text.style?.fontSize == 14.5)
          .toList();
      expect(lit, hasLength(1), reason: 'exactly one category chip is lit');
      return lit.single.data!;
    }

    /// The category strip only builds the chips near the visible window, so
    /// reaching a later one means scrolling it the way a thumb would.
    Future<void> revealChip(WidgetTester tester, String label) async {
      final strip = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Scrollable),
      );
      for (var i = 0; i < 6; i++) {
        final chip = find.descendant(of: strip, matching: find.text(label));
        if (chip.evaluate().isNotEmpty) return;
        await tester.drag(strip, const Offset(-160, 0));
        await tester.pumpAndSettle();
      }
      fail('the $label chip never came into the strip');
    }

    testWidgets('scrolling moves the highlighted tab along', (tester) async {
      final store = await pumpApp(tester);
      store.openTable(store.tableByNumber('05')!.id);
      await tester.pumpAndSettle();

      // Every category is on the one list now, under its own heading.
      final t = store.text;
      expect(selectedChip(tester), t.popular);
      expect(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.text(t.popular),
        ),
        findsOneWidget,
        reason: 'the list opens on the Popular heading',
      );

      // Reading on past the Popular block lands in the first real category.
      final rice = store.categoryDisplayName(store.sortedCategories.first.id);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(selectedChip(tester), rice);

      // And reading to the very end selects the last category, even though
      // its heading can never climb all the way to the top of the list.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(selectedChip(tester),
          store.categoryDisplayName(store.sortedCategories.last.id));
    });

    testWidgets('tapping a tab scrolls to that category', (tester) async {
      final store = await pumpApp(tester);
      store.openTable(store.tableByNumber('05')!.id);
      await tester.pumpAndSettle();

      final label = store.categoryDisplayName('cat-drinks');
      await revealChip(tester, label);
      await tester.tap(find.descendant(
        of: find.byType(AppBar),
        matching: find.text(label),
      ));
      await tester.pumpAndSettle();

      expect(selectedChip(tester), label);
      // That category's heading is now at the top of the list — the tap has
      // to reach a section far enough down that it had not been built yet.
      final header = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.text(label),
      );
      expect(header, findsOneWidget);
      final list = tester.getRect(find.byType(CustomScrollView));
      expect(tester.getRect(header).top - list.top, inInclusiveRange(0, 40),
          reason: 'the heading sits at the top of the list, not just on it');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the dish sheet shows the photo the dish actually has',
        (tester) async {
      final store = await pumpApp(tester);
      // A one pixel PNG, standing in for a photo the admin uploaded.
      const photo = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
          'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      await signIn(tester, store, StaffRole.admin);
      await store.updateMenuItem(
          store.menuItem('food-01')!.copyWith(photo: photo));
      store.setMode(AppMode.customer);
      store.openTable(store.tableByNumber('05')!.id);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FoodImage).first);
      await tester.pumpAndSettle();

      final sheetImage = tester.widget<FoodImage>(find.descendant(
        of: find.byType(FoodDetailSheet),
        matching: find.byType(FoodImage),
      ));
      expect(sheetImage.photo, photo,
          reason: 'the sheet must draw the dish photo, not just the '
              'bundled illustration');
    });
  });


  group('running out of plan', () {
    /// Owner, on the Staff screen, on a plan whose staff cap they have already
    /// filled. The demo seeds three accounts and Free allows two.
    Future<AppStore> atTheStaffCap(WidgetTester tester) async {
      final store = await pumpApp(tester, size: const Size(420, 900));
      await signIn(tester, store, StaffRole.admin);
      await store.updateSettings(store.settings.copyWith(plan: Plan.free));
      await tester.pumpAndSettle();

      await tester.tap(find.text(store.text.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text(store.text.staff).last);
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('the meter says so before the button does', (tester) async {
      final store = await atTheStaffCap(tester);
      // "3 of 2 used" is not a typo — the seeded restaurant is over a cap it
      // was moved onto, which is exactly what a downgrade looks like.
      expect(find.text(store.text.usedOf(store.accounts.length, 2)),
          findsOneWidget);
      expect(store.atStaffLimit, isTrue);
    });

    testWidgets('Add staff opens the upgrade sheet instead of a form',
        (tester) async {
      final store = await atTheStaffCap(tester);

      await tester.tap(find.text(store.text.addStaff));
      await tester.pumpAndSettle();

      expect(find.byType(UpgradeSheet), findsOneWidget);
      // The wall is named with the number, so the merchant can tell how much
      // bigger they need to go.
      expect(find.textContaining(store.text.planBasic), findsWidgets);
      expect(find.text(store.text.sendRequest), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sending a request shows that it landed', (tester) async {
      final store = await atTheStaffCap(tester);
      await tester.tap(find.text(store.text.addStaff));
      await tester.pumpAndSettle();

      await tester.tap(find.text(store.text.sendRequest));
      await tester.pumpAndSettle();

      expect(store.upgradeRequest?.toPlan, Plan.basic);
      // Proof on screen, not just in the database: the plan change and the
      // number we will ring.
      expect(find.text(store.text.upgradeRequestPending), findsOneWidget);
      expect(find.textContaining(store.settings.phone), findsWidgets);
      expect(find.text(store.text.sendRequest), findsNothing);

      // And it can be taken back.
      await tester.tap(find.text(store.text.withdrawRequest));
      await tester.pumpAndSettle();
      expect(store.upgradeRequest, isNull);
    });
  });
}

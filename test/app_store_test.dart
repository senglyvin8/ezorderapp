import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/demo_data.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/models/cart_line.dart';
import 'package:restaurant_qr_ordering/models/staff_account.dart';
import 'package:restaurant_qr_ordering/models/order.dart';
import 'package:restaurant_qr_ordering/models/plan.dart';
import 'package:restaurant_qr_ordering/models/upgrade_request.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers the business rules from the specification that are easy to get
/// wrong when the UI changes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore();
    addTearDown(store.dispose);
    await store.load();
    // Most scenarios exercise staff actions, which now require a signed-in
    // account. Tests that check the guards sign out first.
    await store.signInWithPassword(DemoData.adminUsername, DemoData.adminPassword);
  });

  test('Rule 3 & 11 — an order always carries the scanned table', () async {
    final table = store.tableByNumber('05')!;
    store.openTable(table.id);
    store.addToCart(store.menuItem('food-01')!);

    final order = await store.submitOrder();

    expect(order.tableId, table.id);
    expect(order.tableNumber, '05');
  });

  test('Rule 11 — submitting without a table is refused', () async {
    store.addToCart(store.menuItem('food-01')!);
    await expectLater(store.submitOrder(), throwsStateError);
  });

  test('an empty cart cannot be submitted', () async {
    store.openTable(store.tableByNumber('01')!.id);
    await expectLater(store.submitOrder(), throwsStateError);
  });

  test('Rule 12 — order numbers are unique and increase', () async {
    store.openTable(store.tableByNumber('01')!.id);
    store.addToCart(store.menuItem('food-01')!);
    final first = await store.submitOrder();
    store.addToCart(store.menuItem('food-02')!);
    final second = await store.submitOrder();

    expect(first.orderNumber, isNot(second.orderNumber));
    expect(int.parse(second.orderNumber), int.parse(first.orderNumber) + 1);
    expect(
      store.orders.map((o) => o.orderNumber).toSet().length,
      store.orders.length,
    );
  });

  test('Rule 9 — a sold out dish cannot be added to the cart', () async {
    store.openTable(store.tableByNumber('01')!.id);
    await store.setItemAvailability('food-01', false);

    expect(
      () => store.addToCart(store.menuItem('food-01')!),
      throwsStateError,
    );
  });

  test('Rule 5 — notes survive from the cart onto the order', () async {
    store.openTable(store.tableByNumber('02')!.id);
    store.addToCart(store.menuItem('food-01')!, quantity: 2, note: 'No onion');
    store.setCartNote('We are in a hurry');

    final order = await store.submitOrder();

    expect(order.items.single.note, 'No onion');
    expect(order.items.single.quantity, 2);
    expect(order.customerNote, 'We are in a hurry');
  });

  test('identical dishes merge only when the note matches', () async {
    store.openTable(store.tableByNumber('02')!.id);
    final item = store.menuItem('food-01')!;
    store.addToCart(item, note: 'No onion');
    store.addToCart(item, note: 'No onion');
    store.addToCart(item);

    expect(store.cart.length, 2);
    expect(store.cartItemCount, 3);
  });

  test('Rule 8 — the cart is emptied once the order is submitted', () async {
    store.openTable(store.tableByNumber('03')!.id);
    store.addToCart(store.menuItem('food-01')!);
    await store.submitOrder();

    expect(store.cart, isEmpty);
    expect(store.cartNote, isEmpty);
  });

  test('Rule 6 — the kitchen may only walk NEW -> COOKING -> READY', () async {
    store.openTable(store.tableByNumber('04')!.id);
    store.addToCart(store.menuItem('food-01')!);
    final order = await store.submitOrder();

    await expectLater(store.markReady(order.id), throwsStateError);

    await store.startCooking(order.id);
    expect(store.order(order.id)!.status, OrderStatus.cooking);
    await expectLater(store.startCooking(order.id), throwsStateError);

    await store.markReady(order.id);
    expect(store.order(order.id)!.status, OrderStatus.ready);
  });

  test('Rule 7 & 10 — the cashier settles READY -> PAID -> COMPLETED', () async {
    store.openTable(store.tableByNumber('05')!.id);
    store.addToCart(store.menuItem('food-06')!);
    final order = await store.submitOrder();

    await expectLater(store.collectPayment(order.id, 'Cash'), throwsStateError);

    await store.startCooking(order.id);
    await store.markReady(order.id);
    await store.collectPayment(order.id, 'KHQR');

    final paid = store.order(order.id)!;
    expect(paid.status, OrderStatus.paid);
    expect(paid.paymentMethod, 'KHQR');
    expect(paid.paidAt, isNotNull);

    await store.completeOrder(order.id);
    expect(store.order(order.id)!.status, OrderStatus.completed);
  });

  test('a table is occupied while any of its orders is still open', () async {
    final table = store.tableByNumber('04')!;
    store.openTable(table.id);
    store.addToCart(store.menuItem('food-01')!);
    final order = await store.submitOrder();

    expect(store.isTableOccupied(table.id), isTrue);
    await expectLater(store.deleteTable(table.id), throwsStateError);

    await store.startCooking(order.id);
    await store.markReady(order.id);
    await store.collectPayment(order.id, 'Cash');
    await store.completeOrder(order.id);

    expect(store.isTableOccupied(table.id), isFalse);
  });

  test('Rule 2 — every table has a unique QR identifier', () async {
    final ids = store.tables.map((t) => t.qrId).toList();
    expect(ids.toSet().length, ids.length);

    final added = await store.addTable();
    expect(store.tables.map((t) => t.qrId).toSet().length, ids.length + 1);
    expect(added.qrId, 'restaurant-demo-table-${added.number}');
  });

  test('a scanned payload resolves to its table', () async {
    expect(store.resolveScannedValue('restaurant-demo-table-05')?.number, '05');
    expect(store.resolveScannedValue('/order/demo/table/05')?.number, '05');
    expect(
      store.resolveScannedValue('https://demo.app/order/demo/table/5')?.number,
      '05',
    );
    expect(store.resolveScannedValue('something-else'), isNull);
  });

  test('deleting a category takes its dishes with it', () async {
    final before = store.menuItems.length;
    final count = store.itemCountInCategory('cat-drinks');
    await store.deleteCategory('cat-drinks');

    expect(store.menuItems.length, before - count);
    expect(store.itemsInCategory('cat-drinks'), isEmpty);
  });

  test("today's summary counts revenue from settled orders only", () async {
    final before = store.todaySummary;
    store.openTable(store.tableByNumber('06')!.id);
    store.addToCart(store.menuItem('food-02')!); // $4.00
    final order = await store.submitOrder();

    expect(store.todaySummary.orders, before.orders + 1);
    expect(store.todaySummary.revenue, before.revenue);

    await store.startCooking(order.id);
    await store.markReady(order.id);
    await store.collectPayment(order.id, 'Cash');

    expect(store.todaySummary.revenue, closeTo(before.revenue + 4.00, 0.001));
  });

  test('state survives a reload', () async {
    store.openTable(store.tableByNumber('07')!.id);
    store.addToCart(store.menuItem('food-01')!, note: 'No onion');
    final order = await store.submitOrder();

    await Future<void>.delayed(Duration.zero);

    final reloaded = AppStore();
    await reloaded.load();

    expect(reloaded.currentUser?.role, StaffRole.admin);
    expect(reloaded.order(order.id)?.items.single.note, 'No onion');
    expect(reloaded.activeTableId, store.activeTableId);
  });

  group('discounts', () {
    test('the discounted price is what reaches the order', () async {
      await store.updateMenuItem(store.menuItem('food-01')!.copyWith(
        price: 3.50,
        discountPercent: 20,
      ));
      final item = store.menuItem('food-01')!;
      expect(item.effectivePrice, 2.80);

      store.openTable(store.tableByNumber('01')!.id);
      store.addToCart(item, quantity: 2);
      expect(store.cartTotal, closeTo(5.60, 0.001));

      final order = await store.submitOrder();
      expect(order.items.single.price, 2.80);
      expect(order.total, closeTo(5.60, 0.001));
    });

    test('a price change after ordering does not alter a placed order', () async {
      store.openTable(store.tableByNumber('01')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();
      final charged = order.items.single.price;

      await store.updateMenuItem(
        store.menuItem('food-01')!.copyWith(discountPercent: 50),
      );

      expect(store.order(order.id)!.items.single.price, charged);
    });

    test('the same dish at two prices stays on separate cart lines', () async {
      store.openTable(store.tableByNumber('01')!.id);
      final item = store.menuItem('food-01')!;
      store.addToCart(item);
      await store.updateMenuItem(item.copyWith(discountPercent: 30));
      store.addToCart(store.menuItem('food-01')!);

      expect(store.cart.length, 2);
    });
  });

  group('language', () {
    test('the demo menu is fully bilingual', () async {
      expect(store.untranslatedItemCount, 0,
          reason: 'every seeded dish should ship with a Khmer name');
      expect(store.untranslatedCategoryCount, 0,
          reason: 'every seeded category should ship with a Khmer name');

      for (final item in store.menuItems) {
        expect(item.displayName(AppLanguage.km), isNot(item.name));
        expect(item.displayName(AppLanguage.en), item.name);
      }
      for (final category in store.sortedCategories) {
        expect(category.displayName(AppLanguage.km), isNot(category.name));
      }
    });

    test('a dish with no Khmer name falls back to the English one', () async {
      await store.addMenuItem(
        name: 'Fish Amok',
        description: 'Steamed fish curry.',
        price: 5.50,
        categoryId: 'cat-rice',
        image: 'placeholder',
      );
      final added = store.menuItems.last;

      expect(added.displayName(AppLanguage.km), 'Fish Amok');
      expect(added.displayDescription(AppLanguage.km), 'Steamed fish curry.');
      expect(store.untranslatedItemCount, 1);

      await store.updateMenuItem(added.copyWith(nameKm: 'អាម៉ុកត្រី'));
      expect(store.menuItems.last.displayName(AppLanguage.km), 'អាម៉ុកត្រី');
      expect(store.untranslatedItemCount, 0);
    });

    test('the restaurant name follows the selected language', () async {
      // The app opens in Khmer — see Brand.defaultLanguage.
      expect(store.language, AppLanguage.km);
      expect(store.restaurantDisplayName, 'ភោជនីយដ្ឋាន ABC');

      store.setLanguage(AppLanguage.en);
      expect(store.restaurantDisplayName, 'ABC Restaurant');

      store.setLanguage(AppLanguage.km);
      expect(store.restaurantDisplayName, 'ភោជនីយដ្ឋាន ABC');

      // A blank Khmer name falls back to the English one.
      await store.updateSettings(store.settings.copyWith(nameKm: ''));
      expect(store.restaurantDisplayName, 'ABC Restaurant');
    });

    test('the Khmer name travels with the order', () async {
      await store.updateMenuItem(
        store.menuItem('food-01')!.copyWith(nameKm: 'បាយឆា'),
      );
      store.openTable(store.tableByNumber('01')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();

      expect(order.items.single.displayName(AppLanguage.km), 'បាយឆា');
    });

    test('switching language is remembered across a reload', () async {
      store.setLanguage(AppLanguage.km);
      expect(store.text.menu, isNot('Menu'));
      await Future<void>.delayed(Duration.zero);

      final reloaded = AppStore();
      await reloaded.load();
      expect(reloaded.language, AppLanguage.km);
    });

    test('every status has a Khmer label', () async {
      store.setLanguage(AppLanguage.km);
      final t = store.text;
      for (final label in [
        t.statusNew,
        t.statusInProgress,
        t.statusReady,
        t.statusPaid,
        t.statusCompleted,
      ]) {
        expect(label.trim(), isNotEmpty);
        expect(RegExp(r'[\u1780-\u17FF]').hasMatch(label), isTrue,
            reason: '"$label" should contain Khmer script');
      }
    });
  });

  group('kitchen board', () {
    test('an order stays in the New column while it is being cooked', () async {
      store.openTable(store.tableByNumber('01')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();

      List<String> working() => [
            ...store.ordersWithStatus(OrderStatus.newOrder),
            ...store.ordersWithStatus(OrderStatus.cooking),
          ].map((o) => o.id).toList();

      expect(working(), contains(order.id));

      await store.startCooking(order.id);
      expect(working(), contains(order.id));
      expect(
        store.ordersWithStatus(OrderStatus.ready).map((o) => o.id),
        isNot(contains(order.id)),
      );

      await store.markReady(order.id);
      expect(working(), isNot(contains(order.id)));
      expect(
        store.ordersWithStatus(OrderStatus.ready).map((o) => o.id),
        contains(order.id),
      );
    });
  });

  test('a signature dish keeps its star through an edit', () async {
    await store.updateMenuItem(
      store.menuItem('food-03')!.copyWith(signature: true),
    );
    expect(store.menuItem('food-03')!.signature, isTrue);

    await store.updateMenuItem(
      store.menuItem('food-03')!.copyWith(price: 4.25),
    );
    expect(store.menuItem('food-03')!.signature, isTrue);
  });

  test('an uploaded photo survives a reload and can be removed', () async {
    const fakePhoto = 'aGVsbG8gd29ybGQ=';
    await store.updateMenuItem(store.menuItem('food-02')!.copyWith(photo: fakePhoto));
    await Future<void>.delayed(Duration.zero);

    final reloaded = AppStore();
    await reloaded.load();
    expect(reloaded.menuItem('food-02')!.photo, fakePhoto);

    await reloaded.updateMenuItem(
      reloaded.menuItem('food-02')!.copyWith(clearPhoto: true),
    );
    expect(reloaded.menuItem('food-02')!.photo, isNull);
  });

  test('a new category can be created and used immediately', () async {
    final created = await store.addCategory('Soups', nameKm: 'ស៊ុប');
    expect(store.sortedCategories.map((c) => c.id), contains(created.id));

    await store.addMenuItem(
      name: 'Chicken Soup',
      description: 'Clear broth.',
      price: 2.75,
      categoryId: created.id,
      image: 'placeholder',
    );
    expect(store.itemsInCategory(created.id).single.name, 'Chicken Soup');
    expect(created.displayName(AppLanguage.km), 'ស៊ុប');
  });

  group('takeaway', () {
    test('a takeaway order carries no table and is not tied to one', () async {
      store.startTakeaway();
      expect(store.hasCustomerSession, isTrue);
      expect(store.activeTable, isNull);

      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();

      expect(order.isTakeaway, isTrue);
      expect(order.tableId, isNull);
      expect(order.tableNumber, isNull);
      expect(order.orderNumber, isNotEmpty);
    });

    test('a takeaway order never marks a table occupied', () async {
      final table = store.tableByNumber('01')!;
      store.startTakeaway();
      store.addToCart(store.menuItem('food-01')!);
      await store.submitOrder();

      expect(store.isTableOccupied(table.id), isFalse);
    });

    test('dine in is the default and still records the table', () async {
      expect(store.orderType, OrderType.dineIn);
      store.openTable(store.tableByNumber('05')!.id);
      store.addToCart(store.menuItem('food-01')!);

      final order = await store.submitOrder();
      expect(order.isTakeaway, isFalse);
      expect(order.tableNumber, '05');
    });

    test('switching to dine in without a table is refused', () async {
      store.startTakeaway();
      expect(() => store.setOrderType(OrderType.dineIn), throwsStateError);

      store.openTable(store.tableByNumber('03')!.id);
      store.setOrderType(OrderType.takeaway);
      expect(store.activeTable, isNull);
    });

    test('takeaway survives a reload mid-order', () async {
      store.startTakeaway();
      store.addToCart(store.menuItem('food-06')!);
      await Future<void>.delayed(Duration.zero);

      final reloaded = AppStore();
      await reloaded.load();
      expect(reloaded.orderType, OrderType.takeaway);
      expect(reloaded.hasCustomerSession, isTrue);
      expect(reloaded.cart.length, 1);
    });
  });

  group('access control', () {
    Future<void> signInKitchen() async {
      final account =
          store.accounts.firstWhere((a) => a.role == StaffRole.kitchen);
      expect(await store.signInWithPin(account.id, DemoData.kitchenPin), isTrue);
    }

    Future<void> signInCashier() async {
      final account =
          store.accounts.firstWhere((a) => a.role == StaffRole.cashier);
      expect(await store.signInWithPin(account.id, DemoData.cashierPin), isTrue);
    }

    /// Puts an order into READY without using the role under test.
    Future<String> readyOrder() async {
      store.openTable(store.tableByNumber('05')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();
      await store.startCooking(order.id);
      await store.markReady(order.id);
      return order.id;
    }

    test('a wrong PIN does not sign anyone in', () async {
      await store.signOut();
      final account =
          store.accounts.firstWhere((a) => a.role == StaffRole.kitchen);
      expect(await store.signInWithPin(account.id, '999999'), isFalse);
      expect(store.isSignedIn, isFalse);
    });

    test('a wrong password does not sign anyone in', () async {
      await store.signOut();
      expect(await store.signInWithPassword('admin', 'wrong-password'), isFalse);
      expect(await store.signInWithPassword('nobody', 'admin1234'), isFalse);
      expect(store.isSignedIn, isFalse);
    });

    test('a disabled account cannot sign in', () async {
      final account =
          store.accounts.firstWhere((a) => a.role == StaffRole.kitchen);
      await store.setStaffActive(account.id, false);
      await store.signOut();

      expect(await store.signInWithPin(account.id, DemoData.kitchenPin), isFalse);
      expect(store.isSignedIn, isFalse);
    });

    test('signed out, no staff action is possible', () async {
      store.openTable(store.tableByNumber('05')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();
      await store.signOut();

      await expectLater(store.startCooking(order.id), throwsStateError);
      await expectLater(store.collectPayment(order.id, 'Cash'), throwsStateError);
      await expectLater(store.setItemAvailability('food-01', false),
          throwsStateError);
      await expectLater(store.addTable(), throwsStateError);
      await expectLater(store.addStaff(
            name: 'Nobody', role: StaffRole.kitchen, secret: '123456'),
        throwsStateError,
      );
    });

    test('but a customer can still order without signing in', () async {
      await store.signOut();
      store.openTable(store.tableByNumber('05')!.id);
      store.addToCart(store.menuItem('food-01')!);

      final order = await store.submitOrder();
      expect(order.status, OrderStatus.newOrder);
    });

    test('kitchen can cook but cannot take money or edit the menu', () async {
      final orderId = await readyOrder();
      await signInKitchen();

      await expectLater(store.collectPayment(orderId, 'Cash'), throwsStateError);
      await expectLater(store.setItemAvailability('food-01', false),
          throwsStateError);
      await expectLater(store.updateSettings(store.settings), throwsStateError);
      await expectLater(store.addStaff(
            name: 'Nobody', role: StaffRole.kitchen, secret: '123456'),
        throwsStateError,
      );

      store.openTable(store.tableByNumber('02')!.id);
      store.addToCart(store.menuItem('food-02')!);
      final fresh = await store.submitOrder();
      await store.startCooking(fresh.id);
      expect(store.order(fresh.id)!.status, OrderStatus.cooking);
    });

    test('cashier can take money but cannot cook or edit the menu', () async {
      final orderId = await readyOrder();
      await signInCashier();

      store.openTable(store.tableByNumber('02')!.id);
      store.addToCart(store.menuItem('food-02')!);
      final fresh = await store.submitOrder();
      await expectLater(store.startCooking(fresh.id), throwsStateError);
      await expectLater(store.deleteMenuItem('food-01'), throwsStateError);

      await store.collectPayment(orderId, 'KHQR');
      expect(store.order(orderId)!.status, OrderStatus.paid);
      await store.completeOrder(orderId);
      expect(store.order(orderId)!.status, OrderStatus.completed);
    });

    test('admin can do all three jobs', () async {
      final orderId = await readyOrder();
      await store.collectPayment(orderId, 'Cash');
      await store.completeOrder(orderId);
      await store.setItemAvailability('food-01', false);
      await store.addTable();

      expect(store.order(orderId)!.status, OrderStatus.completed);
      expect(store.menuItem('food-01')!.available, isFalse);
    });

    test('the last active admin cannot be removed or disabled', () async {
      final admin = store.accounts.firstWhere((a) => a.role == StaffRole.admin);
      await expectLater(store.setStaffActive(admin.id, false), throwsStateError);
      await expectLater(store.deleteStaff(admin.id), throwsStateError);

      final second = await store.addStaff(
        name: 'Second Owner',
        role: StaffRole.admin,
        secret: 'another-password',
        username: 'owner2',
      );
      await store.setStaffActive(second.id, false);
      expect(store.accounts.firstWhere((a) => a.id == second.id).active,
          isFalse);
    });

    test('a new account can sign in with the PIN the admin set', () async {
      final created = await store.addStaff(
        name: 'Dara',
        role: StaffRole.cashier,
        secret: '432100',
      );
      await store.signOut();

      expect(await store.signInWithPin(created.id, '123456'), isFalse);
      expect(await store.signInWithPin(created.id, '432100'), isTrue);
      expect(store.currentUser?.name, 'Dara');
      expect(store.canTakePayment, isTrue);
      expect(store.canManageRestaurant, isFalse);
    });

    test('resetting a PIN invalidates the old one', () async {
      final account =
          store.accounts.firstWhere((a) => a.role == StaffRole.kitchen);
      await store.resetStaffSecret(account.id, '567800');
      await store.signOut();

      expect(await store.signInWithPin(account.id, DemoData.kitchenPin),
          isFalse);
      expect(await store.signInWithPin(account.id, '567800'), isTrue);
    });

    test('secrets are never stored in the clear', () async {
      for (final account in store.accounts) {
        expect(account.secretHash, isNot(contains(DemoData.adminPassword)));
        expect(account.secretHash, isNot(contains(DemoData.kitchenPin)));
        expect(account.salt, isNotEmpty);
        expect(account.secretHash.length, greaterThan(20));
      }
      // Same secret, different accounts: the salt must make the hashes differ.
      final a = await store.addStaff(
          name: 'A', role: StaffRole.kitchen, secret: '123456');
      final b = await store.addStaff(
          name: 'B', role: StaffRole.kitchen, secret: '123456');
      expect(a.secretHash, isNot(b.secretHash));
    });
  });

  test('a PIN must be exactly six digits', () async {
    await expectLater(store.addStaff(
          name: 'Short', role: StaffRole.kitchen, secret: '1234'),
      throwsStateError,
    );
    await expectLater(store.addStaff(
          name: 'Long', role: StaffRole.kitchen, secret: '12345678'),
      throwsStateError,
    );

    final ok = await store.addStaff(
        name: 'Sokha', role: StaffRole.cashier, secret: '654321');
    expect(ok.name, 'Sokha');
    await expectLater(store.resetStaffSecret(ok.id, '12'), throwsStateError);
  });

  group('cancelling an order', () {
    test('a queued order can be pulled back, and frees its table', () async {
      // Table 10 carries only a completed seed order, so occupancy here is
      // entirely down to the order this test places.
      final table = store.tableByNumber('10')!;
      store.openTable(table.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();
      expect(store.isTableOccupied(table.id), isTrue);

      await store.cancelOrder(order.id);

      final cancelled = store.order(order.id)!;
      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.cancelledAt, isNotNull);
      expect(cancelled.cancelledBy, isNotNull);
      expect(store.isTableOccupied(table.id), isFalse);
    });

    test('once the kitchen has started, it is too late', () async {
      store.openTable(store.tableByNumber('03')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();

      await store.startCooking(order.id);
      await expectLater(store.cancelOrder(order.id), throwsStateError);
      expect(store.order(order.id)!.status, OrderStatus.cooking);
    });

    test('a paid order cannot be cancelled either', () async {
      store.openTable(store.tableByNumber('04')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();
      await store.startCooking(order.id);
      await store.markReady(order.id);
      await store.collectPayment(order.id, 'Cash');

      await expectLater(store.cancelOrder(order.id), throwsStateError);
    });

    test('the kitchen cannot cancel, only the till', () async {
      store.openTable(store.tableByNumber('05')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();

      await store.signOut();
      await store.signInWithPin(
        store.accounts.firstWhere((a) => a.role == StaffRole.kitchen).id,
        DemoData.kitchenPin,
      );
      await expectLater(store.cancelOrder(order.id), throwsStateError);
    });

    test('a cancelled order leaves the live list and the takings', () async {
      // Deltas, not absolutes: the demo seed already has orders on the floor.
      final pendingBefore = store.todaySummary.pending;
      final revenueBefore = store.todaySummary.revenue;

      store.openTable(store.tableByNumber('06')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();

      expect(store.liveOrders.map((o) => o.id), contains(order.id));
      expect(store.todaySummary.pending, pendingBefore + 1);

      await store.cancelOrder(order.id);

      expect(store.liveOrders.map((o) => o.id), isNot(contains(order.id)));
      expect(store.settledOrders.map((o) => o.id), contains(order.id));
      expect(store.todaySummary.pending, pendingBefore);
      expect(store.todaySummary.revenue, revenueBefore);
    });

    test('cancellation survives a reload', () async {
      store.openTable(store.tableByNumber('01')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final order = await store.submitOrder();
      await store.cancelOrder(order.id);
      await Future<void>.delayed(Duration.zero);

      final reloaded = AppStore();
      addTearDown(reloaded.dispose);
      await reloaded.load();
      final restored = reloaded.order(order.id)!;
      expect(restored.status, OrderStatus.cancelled);
      expect(restored.cancelledBy, isNotNull);
      expect(restored.cancelledAt, isNotNull);
    });
  });

  group('an order taken at the counter', () {
    List<CartLine> linesOf(AppStore store, List<String> foodIds) => [
          for (var i = 0; i < foodIds.length; i++)
            CartLine(
              id: 'line-$i',
              foodId: foodIds[i],
              name: store.menuItem(foodIds[i])!.name,
              price: store.menuItem(foodIds[i])!.effectivePrice,
              quantity: 1,
            ),
        ];

    test('reaches the kitchen like any other, and records who took it', () async {
      final table = store.tableByNumber('02')!;
      final order = await store.placeStaffOrder(
        type: OrderType.dineIn,
        tableId: table.id,
        lines: linesOf(store, ['food-01', 'food-02']),
        note: 'No chilli',
      );

      expect(order.status, OrderStatus.newOrder);
      expect(order.tableNumber, '02');
      expect(order.placedBy, isNotNull);
      expect(order.isStaffPlaced, isTrue);
      expect(order.customerNote, 'No chilli');
      expect(store.ordersWithStatus(OrderStatus.newOrder).map((o) => o.id),
          contains(order.id));
    });

    test('never touches the customer session on the same device', () async {
      store.openTable(store.tableByNumber('05')!.id);
      store.addToCart(store.menuItem('food-03')!);
      final customerCart = store.cart.length;

      await store.placeStaffOrder(
        type: OrderType.takeaway,
        lines: linesOf(store, ['food-01']),
      );

      expect(store.cart.length, customerCart);
      expect(store.activeTable?.number, '05');
      expect(store.orderType, OrderType.dineIn);
    });

    test('a dine-in order without a table is refused', () async {
      await expectLater(store.placeStaffOrder(
          type: OrderType.dineIn,
          lines: linesOf(store, ['food-01']),
        ),
        throwsStateError,
      );
    });

    test('an empty basket is refused', () async {
      await expectLater(store.placeStaffOrder(type: OrderType.takeaway, lines: []),
        throwsStateError,
      );
    });

    test('the kitchen cannot take orders at the till', () async {
      await store.signOut();
      await store.signInWithPin(
        store.accounts.firstWhere((a) => a.role == StaffRole.kitchen).id,
        DemoData.kitchenPin,
      );
      await expectLater(store.placeStaffOrder(
          type: OrderType.takeaway,
          lines: linesOf(store, ['food-01']),
        ),
        throwsStateError,
      );
    });

    test('it shares the one order-number sequence', () async {
      store.openTable(store.tableByNumber('01')!.id);
      store.addToCart(store.menuItem('food-01')!);
      final fromPhone = await store.submitOrder();
      final fromTill = await store.placeStaffOrder(
        type: OrderType.takeaway,
        lines: linesOf(store, ['food-02']),
      );

      expect(int.parse(fromTill.orderNumber),
          int.parse(fromPhone.orderNumber) + 1);
    });
  });

  group('choosing a table mid-order', () {
    test('switching from takeaway to dine in keeps the basket', () async {
      store.startTakeaway();
      store.addToCart(store.menuItem('food-01')!);
      store.addToCart(store.menuItem('food-02')!);

      store.chooseTable(store.tableByNumber('04')!.id);

      expect(store.orderType, OrderType.dineIn);
      expect(store.activeTable?.number, '04');
      expect(store.cart.length, 2);

      final order = await store.submitOrder();
      expect(order.tableNumber, '04');
      expect(order.isTakeaway, isFalse);
    });

    test('an unknown table is refused', () async {
      store.startTakeaway();
      expect(() => store.chooseTable('nope'), throwsStateError);
      expect(store.orderType, OrderType.takeaway);
    });
  });

  group('bug fixes', () {
    test('resetting the demo data keeps the admin signed in', () async {
      expect(store.canManageRestaurant, isTrue);

      await store.resetDemoData();

      // Previously this reseeded the accounts and left `currentUserId`
      // pointing at an id that no longer existed, silently signing the admin
      // out mid-screen.
      expect(store.isSignedIn, isTrue);
      expect(store.currentUser!.role, StaffRole.admin);
      expect(store.canManageRestaurant, isTrue);
      expect(store.mode, AppMode.staff);
    });

    test('two admins cannot share a username', () async {
      await store.addStaff(
        name: 'Second owner',
        role: StaffRole.admin,
        secret: 'longenoughpassword',
        username: 'newowner',
      );

      // Same name in different case is the same login, because sign-in
      // compares case-insensitively.
      await expectLater(store.addStaff(
          name: 'Impostor',
          role: StaffRole.admin,
          secret: 'anotherpassword',
          username: 'NewOwner',
        ),
        throwsStateError,
      );
      await expectLater(store.addStaff(
          name: 'Also the owner',
          role: StaffRole.admin,
          secret: 'yetanotherpass',
          username: DemoData.adminUsername,
        ),
        throwsStateError,
      );
    });

    test('every admin account can actually sign in', () async {
      final second = await store.addStaff(
        name: 'Second owner',
        role: StaffRole.admin,
        secret: 'longenoughpassword',
        username: 'newowner',
      );
      await store.signOut();

      expect(await store.signInWithPassword('newowner', 'longenoughpassword'),
          isTrue);
      expect(store.currentUser!.id, second.id);

      await store.signOut();
      expect(
        await store.signInWithPassword(
            DemoData.adminUsername, DemoData.adminPassword),
        isTrue,
      );
    });

    test('staff PINs may repeat — they are never used to pick the account',
        () async {
      final first = await store.addStaff(
          name: 'Dara', role: StaffRole.kitchen, secret: '112233');
      final second = await store.addStaff(
          name: 'Sopheak', role: StaffRole.cashier, secret: '112233');
      await store.signOut();

      expect(await store.signInWithPin(second.id, '112233'), isTrue);
      expect(store.currentUser!.id, second.id);
      expect(store.currentUser!.id, isNot(first.id));
    });
  });

  group('changing what is on an order', () {
    Future<Order> queuedOrder(AppStore store, String tableNumber) async {
      store.openTable(store.tableByNumber(tableNumber)!.id);
      store.addToCart(store.menuItem('food-01')!, quantity: 2);
      store.addToCart(store.menuItem('food-06')!);
      return store.submitOrder();
    }

    test('a dish can be taken off, and the total follows', () async {
      final order = await queuedOrder(store, '10');
      final drink = order.items.last;
      expect(order.items.length, 2);

      await store.removeOrderItem(order.id, drink.id);

      final updated = store.order(order.id)!;
      expect(updated.items.length, 1);
      expect(updated.items.any((i) => i.id == drink.id), isFalse);
      expect(updated.subtotal, updated.items.first.lineTotal);
      expect(updated.total, updated.subtotal);
      expect(updated.itemCount, 2);
    });

    test('a quantity can be reduced without removing the line', () async {
      final order = await queuedOrder(store, '10');
      final dish = order.items.first;

      await store.setOrderItemQuantity(order.id, dish.id, 1);

      final updated = store.order(order.id)!;
      expect(updated.items.length, 2);
      expect(updated.items.firstWhere((i) => i.id == dish.id).quantity, 1);
      expect(updated.total,
          updated.items.fold<double>(0, (sum, i) => sum + i.lineTotal));
    });

    test('the last dish cannot be removed — that is a cancellation', () async {
      final order = await queuedOrder(store, '10');
      await store.removeOrderItem(order.id, order.items.last.id);

      final remaining = store.order(order.id)!.items.single;
      await expectLater(store.removeOrderItem(order.id, remaining.id),
        throwsStateError,
      );
      expect(store.order(order.id)!.items, hasLength(1));
      expect(store.order(order.id)!.status, OrderStatus.newOrder);
    });

    test('once the kitchen has started, the order is frozen', () async {
      final order = await queuedOrder(store, '10');
      await store.startCooking(order.id);

      await expectLater(store.removeOrderItem(order.id, order.items.first.id),
        throwsStateError,
      );
      await expectLater(store.setOrderItemQuantity(order.id, order.items.first.id, 1),
        throwsStateError,
      );
      expect(store.order(order.id)!.items, hasLength(2));
    });

    test('a paid order is frozen too', () async {
      final order = await queuedOrder(store, '10');
      await store.startCooking(order.id);
      await store.markReady(order.id);
      await store.collectPayment(order.id, 'Cash');

      await expectLater(store.removeOrderItem(order.id, order.items.first.id),
        throwsStateError,
      );
    });

    test('the kitchen cannot edit an order, only the till', () async {
      final order = await queuedOrder(store, '10');
      await store.signOut();
      await store.signInWithPin(
        store.accounts.firstWhere((a) => a.role == StaffRole.kitchen).id,
        DemoData.kitchenPin,
      );

      await expectLater(store.removeOrderItem(order.id, order.items.first.id),
        throwsStateError,
      );
    });

    test('an unknown dish or order is refused', () async {
      final order = await queuedOrder(store, '10');
      await expectLater(store.removeOrderItem(order.id, 'nope'), throwsStateError);
      await expectLater(store.removeOrderItem('nope', order.items.first.id),
        throwsStateError,
      );
    });

    test('the edit survives a reload', () async {
      final order = await queuedOrder(store, '10');
      await store.removeOrderItem(order.id, order.items.last.id);
      final expectedTotal = store.order(order.id)!.total;
      await Future<void>.delayed(Duration.zero);

      final reloaded = AppStore();
      addTearDown(reloaded.dispose);
      await reloaded.load();
      final restored = reloaded.order(order.id)!;
      expect(restored.items, hasLength(1));
      expect(restored.total, expectedTotal);
    });
  });

  group('asking for a bigger plan', () {
    /// The demo runs on PRO so that it can show ten tables. A merchant who is
    /// about to hit a wall is on something smaller.
    Future<void> onPlan(Plan plan) async {
      await store.updateSettings(store.settings.copyWith(plan: plan));
    }

    test('the cap is what a merchant actually runs into', () async {
      await onPlan(Plan.free); // two staff, and the demo seeds three
      expect(store.atStaffLimit, isTrue);
      await expectLater(
        store.addStaff(name: 'Dara', role: StaffRole.kitchen, secret: '445566'),
        throwsStateError,
      );
    });

    test('the owner can ask, and sees that they asked', () async {
      await onPlan(Plan.basic);
      expect(store.upgradeRequest, isNull);

      await store.requestUpgrade(
        toPlan: Plan.pro,
        reason: UpgradeReason.staffCap,
        contactName: 'Owner',
        contactPhone: '012 345 678',
        note: 'Two more tills',
      );

      final request = store.upgradeRequest!;
      expect(request.isOpen, isTrue);
      expect(request.fromPlan, Plan.basic);
      expect(request.toPlan, Plan.pro);
      expect(request.reason, UpgradeReason.staffCap);
      expect(request.contactPhone, '012 345 678');
      expect(request.note, 'Two more tills');
    });

    test('asking twice edits the first request rather than filing a second',
        () async {
      await store.requestUpgrade(
        toPlan: Plan.basic,
        reason: UpgradeReason.tableCap,
        contactName: 'Owner',
        contactPhone: '012 345 678',
      );
      final first = store.upgradeRequest!;

      await store.requestUpgrade(
        toPlan: Plan.pro,
        reason: UpgradeReason.manual,
        contactName: 'Owner',
        contactPhone: '',
        note: 'Actually we want Pro',
      );

      final second = store.upgradeRequest!;
      expect(second.id, first.id, reason: 'the same request, edited');
      expect(second.toPlan, Plan.pro);
      expect(second.note, 'Actually we want Pro');
      // A blank phone means "leave it alone", not "wipe the number you were
      // going to call me on".
      expect(second.contactPhone, '012 345 678');
      // How long they have been waiting is the point of the queue, so the
      // clock does not restart when they edit.
      expect(second.createdAt, first.createdAt);
    });

    test('it can be withdrawn', () async {
      await store.requestUpgrade(
        toPlan: Plan.pro,
        reason: UpgradeReason.manual,
        contactName: 'Owner',
        contactPhone: '012 345 678',
      );
      expect(store.upgradeRequest, isNotNull);

      await store.cancelUpgradeRequest();
      expect(store.upgradeRequest, isNull);
    });

    test('only the owner can commit their employer to a bill', () async {
      await store.signOut();
      final cashier =
          store.accounts.firstWhere((a) => a.role == StaffRole.cashier);
      await store.signInWithPin(cashier.id, DemoData.cashierPin);

      await expectLater(
        store.requestUpgrade(
          toPlan: Plan.pro,
          reason: UpgradeReason.manual,
          contactName: 'Bopha',
          contactPhone: '012 345 678',
        ),
        throwsStateError,
      );
    });

    test('the request survives a reload', () async {
      await store.requestUpgrade(
        toPlan: Plan.pro,
        reason: UpgradeReason.staffCap,
        contactName: 'Owner',
        contactPhone: '012 345 678',
      );
      await Future<void>.delayed(Duration.zero);

      final reloaded = AppStore();
      addTearDown(reloaded.dispose);
      await reloaded.load();

      expect(reloaded.upgradeRequest?.toPlan, Plan.pro);
      expect(reloaded.upgradeRequest?.isOpen, isTrue);
    });
  });
}

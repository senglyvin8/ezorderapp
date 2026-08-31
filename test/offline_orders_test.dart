import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/widgets/pending_orders_bar.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/backend/backend.dart';
import 'package:restaurant_qr_ordering/data/backend/local_backend.dart';
import 'package:restaurant_qr_ordering/data/demo_data.dart';
import 'package:restaurant_qr_ordering/data/order_outbox.dart';
import 'package:restaurant_qr_ordering/models/cart_line.dart';
import 'package:restaurant_qr_ordering/models/order.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real on-device backend, behind a wifi router you can switch off.
///
/// Extending it rather than faking it keeps every rule intact — sold-out
/// dishes, table checks, idempotency — so only the connection is pretend.
/// `offline` fails the way a dropped connection does: never reaching the
/// restaurant, as opposed to reaching it and being refused.
class _FlakyBackend extends LocalBackend {
  bool offline = false;

  @override
  Future<Order> placeOrder({
    required OrderType type,
    String? tableId,
    required List<CartLine> lines,
    String note = '',
    bool onBehalfOfCustomer = false,
    String? clientKey,
  }) async {
    if (offline) throw TransientFailure('Could not reach the restaurant.');
    return super.placeOrder(
      type: type,
      tableId: tableId,
      lines: lines,
      note: note,
      onBehalfOfCustomer: onBehalfOfCustomer,
      clientKey: clientKey,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FlakyBackend net;
  late AppStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    net = _FlakyBackend();
    store = AppStore(backend: net);
    addTearDown(store.dispose);
    await store.load();
    await store.signInWithPassword(
        DemoData.adminUsername, DemoData.adminPassword);
    store.openTable(store.tableByNumber('05')!.id);
  });

  group('when the wifi drops mid-order', () {
    test('the order is held rather than lost, and the cart clears', () async {
      store.addToCart(store.menuItem('food-01')!, quantity: 2);
      net.offline = true;

      await expectLater(store.submitOrder(), throwsA(isA<OrderHeldOffline>()));

      expect(store.pendingOrderCount, 1);
      expect(store.cart, isEmpty, reason: 'the customer is done ordering');
      final held = store.pendingOrders.single;
      expect(held.itemCount, 2);
      expect(held.key, isNotEmpty);
    });

    test('it goes to the kitchen when the connection comes back', () async {
      store.addToCart(store.menuItem('food-01')!, quantity: 2);
      net.offline = true;
      await expectLater(store.submitOrder(), throwsA(isA<OrderHeldOffline>()));

      final before = store.orders.length;
      net.offline = false;
      final sent = await store.flushPendingOrders();

      expect(sent, 1);
      expect(store.pendingOrderCount, 0);
      expect(store.orders.length, before + 1);
      expect(store.orders.last.itemCount, 2);
    });

    test('several orders keep the order they were taken in', () async {
      net.offline = true;
      for (final id in ['food-01', 'food-02', 'food-03']) {
        store.addToCart(store.menuItem(id)!);
        await expectLater(
            store.submitOrder(), throwsA(isA<OrderHeldOffline>()));
        store.openTable(store.tableByNumber('05')!.id);
      }
      expect(store.pendingOrderCount, 3);

      net.offline = false;
      expect(await store.flushPendingOrders(), 3);

      final placed = store.orders.reversed.take(3).toList().reversed.toList();
      expect(placed.map((o) => o.items.single.foodId).toList(),
          ['food-01', 'food-02', 'food-03']);
    });

    test('a held order survives the app being closed', () async {
      store.addToCart(store.menuItem('food-01')!);
      net.offline = true;
      await expectLater(store.submitOrder(), throwsA(isA<OrderHeldOffline>()));

      // A phone that runs out of battery must not take the order with it.
      final reopened = AppStore(backend: _FlakyBackend());
      addTearDown(reopened.dispose);
      await reopened.load();

      expect(reopened.pendingOrderCount, 1);
      expect(reopened.pendingOrders.single.itemCount, 1);
    });

    test('still down: it stays queued and says why', () async {
      store.addToCart(store.menuItem('food-01')!);
      net.offline = true;
      await expectLater(store.submitOrder(), throwsA(isA<OrderHeldOffline>()));

      expect(await store.flushPendingOrders(), 0);
      expect(store.pendingOrderCount, 1);
      final held = store.pendingOrders.single;
      expect(held.attempts, 1);
      expect(held.lastError, contains('reach'));
    });
  });

  group('what must not happen', () {
    test('a retry never places the order twice', () async {
      store.addToCart(store.menuItem('food-01')!);
      net.offline = true;
      await expectLater(store.submitOrder(), throwsA(isA<OrderHeldOffline>()));

      final before = store.orders.length;
      net.offline = false;
      await store.flushPendingOrders();
      // Flushing again — a second tap, a second reconnect — must be harmless.
      await store.flushPendingOrders();

      expect(store.orders.length, before + 1,
          reason: 'the table would have been charged twice');
    });

    test('the same key sent twice is placed once, even straight through',
        () async {
      // The ambiguous case: the database committed, the reply was lost, the
      // app sends again.
      final item = store.menuItem('food-01')!;
      final lines = [
        CartLine(
          id: 'l1',
          foodId: item.id,
          name: item.name,
          price: item.effectivePrice,
          quantity: 1,
        )
      ];
      final first = await net.placeOrder(
          type: OrderType.takeaway, lines: lines, clientKey: 'same-key');
      final second = await net.placeOrder(
          type: OrderType.takeaway, lines: lines, clientKey: 'same-key');

      expect(second.id, first.id);
      expect(second.orderNumber, first.orderNumber);
    });

    test('an order the kitchen refuses leaves the queue with a reason',
        () async {
      final item = store.menuItem('food-01')!;
      store.addToCart(item);
      net.offline = true;
      await expectLater(store.submitOrder(), throwsA(isA<OrderHeldOffline>()));

      // It sold out while the order sat waiting.
      net.offline = false;
      await store.setItemAvailability(item.id, false);

      final sent = await store.flushPendingOrders();
      expect(sent, 0);
      expect(store.pendingOrderCount, 0,
          reason: 'retrying a sold-out dish forever helps nobody');
    });

    test('a held order can be given up on', () async {
      store.addToCart(store.menuItem('food-01')!);
      net.offline = true;
      await expectLater(store.submitOrder(), throwsA(isA<OrderHeldOffline>()));

      await store.discardPendingOrder(store.pendingOrders.single.key);
      expect(store.hasPendingOrders, isFalse);
    });
  });

  group('what the diner and the staff see', () {
    testWidgets('the bar appears only once something is waiting, in both '
        'languages', (tester) async {
      for (final language in AppLanguage.values) {
        SharedPreferences.setMockInitialValues({});
        final net = _FlakyBackend();
        final s = AppStore(backend: net);
        addTearDown(s.dispose);
        await s.load();
        s.setLanguage(language);
        s.openTable(s.tableByNumber('05')!.id);

        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(420, 900);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
          value: s, child: const RestaurantApp()));
        await tester.pumpAndSettle();

        expect(find.byType(PendingOrdersBar), findsOneWidget);
        expect(find.text(s.text.ordersWaiting(1)), findsNothing,
            reason: 'nothing is waiting yet');

        s.addToCart(s.menuItem('food-01')!);
        net.offline = true;
        await expectLater(s.submitOrder(), throwsA(isA<OrderHeldOffline>()));
        await tester.pumpAndSettle();

        expect(find.text(s.text.ordersWaiting(1)), findsOneWidget,
            reason: 'staff must know an order has not gone (${language.name})');
        expect(tester.takeException(), isNull, reason: language.name);
      }
    });

    testWidgets('tapping Send now clears the queue', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final net = _FlakyBackend();
      final s = AppStore(backend: net);
      addTearDown(s.dispose);
      await s.load();
      s.openTable(s.tableByNumber('05')!.id);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(420, 900);
      addTearDown(tester.view.reset);

      s.addToCart(s.menuItem('food-01')!);
      net.offline = true;
      await expectLater(s.submitOrder(), throwsA(isA<OrderHeldOffline>()));

      await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: s, child: const RestaurantApp()));
      await tester.pumpAndSettle();

      net.offline = false;
      await tester.tap(find.text(s.text.sendNow));
      await tester.pumpAndSettle();

      expect(s.hasPendingOrders, isFalse);
      expect(find.text(s.text.ordersSent(1)), findsWidgets);
    });
  });
}

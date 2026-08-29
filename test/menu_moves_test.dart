import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/demo_data.dart';
import 'package:restaurant_qr_ordering/models/cart_line.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/models/order.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What happens when the menu changes while a cart is still open.
///
/// A cart is a snapshot taken when a dish was tapped, and the menu carries on
/// without it — the kitchen runs out of pork while the customer is still
/// reading the drinks, or the owner deletes a dish that a phone downstairs is
/// still holding. Postgres has always refused these at `place_order()`; these
/// tests are why the on-device backend refuses them too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppStore store;
  late int seededOrders;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore();
    addTearDown(store.dispose);
    await store.load();
    await store.signInWithPassword(
        DemoData.adminUsername, DemoData.adminPassword);
    store.openTable(store.tableByNumber('05')!.id);
    // The demo seeds a day of trading, so "nothing reached the kitchen" has
    // to be measured against what was already there.
    seededOrders = store.orders.length;
  });

  group('a dish that sells out while it sits in the cart', () {
    test('is refused at submit, naming the dish', () async {
      final item = store.menuItem('food-01')!;
      store.addToCart(item);
      await store.setItemAvailability(item.id, false);

      await expectLater(
        store.submitOrder(),
        throwsA(isStateError.having(
            (e) => e.message, 'message', contains(item.name))),
      );
      expect(store.orders, hasLength(seededOrders),
          reason: 'nothing reached the kitchen');
    });

    test('leaves the cart alone so the customer can take it out', () async {
      final item = store.menuItem('food-01')!;
      store.addToCart(item);
      await store.setItemAvailability(item.id, false);
      await expectLater(store.submitOrder(), throwsStateError);

      expect(store.cart, hasLength(1));
      store.removeCartLine(store.cart.first.id);
      store.addToCart(store.menuItem('food-02')!);

      final order = await store.submitOrder();
      expect(order.items.single.foodId, 'food-02');
    });

    test('is called out in the cart before the customer submits', () async {
      final item = store.menuItem('food-01')!;
      store.addToCart(item);
      expect(store.cartLineUnavailable(store.cart.single), isFalse);

      await store.setItemAvailability(item.id, false);
      expect(store.cartLineUnavailable(store.cart.single), isTrue);
    });

    test('does not hold up the rest of a mixed cart once removed', () async {
      final soldOut = store.menuItem('food-01')!;
      store.addToCart(soldOut);
      store.addToCart(store.menuItem('food-02')!, quantity: 2);
      await store.setItemAvailability(soldOut.id, false);

      await expectLater(store.submitOrder(), throwsStateError);
      store.removeCartLine(
        store.cart.firstWhere((l) => l.foodId == soldOut.id).id,
      );

      final order = await store.submitOrder();
      expect(order.itemCount, 2);
    });
  });

  test('a dish deleted from the menu cannot be ordered from a stale cart',
      () async {
    final item = store.menuItem('food-01')!;
    store.addToCart(item);
    await store.deleteMenuItem(item.id);

    expect(store.cartLineUnavailable(store.cart.single), isTrue);
    await expectLater(store.submitOrder(), throwsStateError);
    expect(store.orders, hasLength(seededOrders));
  });

  test('the cashier cannot ring up a sold-out dish either', () async {
    final item = store.menuItem('food-01')!;
    await store.setItemAvailability(item.id, false);

    await expectLater(
      store.placeStaffOrder(
        type: OrderType.takeaway,
        lines: [
          CartLine(
            id: 'line-1',
            foodId: item.id,
            name: item.name,
            price: item.price,
            quantity: 1,
          ),
        ],
      ),
      throwsStateError,
    );
  });

  group('quantities that would bill nobody', () {
    test('a cart line of zero is refused', () {
      expect(
        () => store.addToCart(store.menuItem('food-01')!, quantity: 0),
        throwsStateError,
      );
      expect(store.cart, isEmpty);
    });

    test('a negative quantity cannot take money off the bill', () {
      expect(
        () => store.addToCart(store.menuItem('food-01')!, quantity: -3),
        throwsStateError,
      );
      expect(store.cartSubtotal, 0);
    });

    test('an order never carries a line worth less than one dish', () async {
      // Straight at the backend, past the cart guard — the same door a
      // patched client would come through.
      final item = store.menuItem('food-01')!;
      final order = await store.placeStaffOrder(
        type: OrderType.takeaway,
        lines: [
          CartLine(
            id: 'line-1',
            foodId: item.id,
            name: item.name,
            price: item.effectivePrice,
            quantity: 0,
          ),
        ],
      );

      expect(order.itemCount, 1);
      expect(order.total, item.effectivePrice);
    });
  });

  /// The warning is longer in Khmer than in English, and it sits in the same
  /// row as an icon — exactly the shape that overflows.
  for (final language in AppLanguage.values) {
    testWidgets('the sold-out warning fits the cart line in ${language.name}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final shown = AppStore();
      addTearDown(shown.dispose);
      await shown.load();

      // Sign-in yields to a timer that only fires while the tester pumps, so
      // the pump has to happen with the future still in flight.
      final signingIn = shown.signInWithPassword(
          DemoData.adminUsername, DemoData.adminPassword);
      await tester.pumpAndSettle();
      expect(await signingIn, isTrue);

      shown.setLanguage(language);
      shown.openTable(shown.tableByNumber('05')!.id);
      final item = shown.menuItem('food-01')!;
      shown.addToCart(item, quantity: 2);

      // The kitchen runs out after it was added, then the owner puts the
      // tablet back on the customer view.
      final flip = shown.setItemAvailability(item.id, false);
      await tester.pumpAndSettle();
      await flip;
      final out = shown.signOut();
      await tester.pumpAndSettle();
      await out;

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(420, 900);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStore>.value(
          value: shown,
          child: const RestaurantApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(shown.text.viewOrder));
      await tester.pumpAndSettle();
      expect(find.text(shown.text.yourOrder), findsOneWidget);

      expect(find.text(shown.text.soldOutRemoveToOrder), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'cart line overflowed');
    });
  }

  group('a note nobody can print', () {
    test('a very long note is cut, not refused', () async {
      final item = store.menuItem('food-01')!;
      store.addToCart(item, note: 'x' * 5000);

      final note = store.cart.single.note!;
      expect(note.length, kMaxNoteLength,
          reason: 'a kitchen ticket has to keep its shape');

      // Cut, not rejected: the diner still gets their food.
      final order = await store.submitOrder();
      expect(order.items.single.note!.length, kMaxNoteLength);
    });

    test('a note that fits is left exactly alone', () {
      store.addToCart(store.menuItem('food-01')!, note: 'No onion, please');
      expect(store.cart.single.note, 'No onion, please');
    });

    test('surrounding whitespace never counts toward the limit', () {
      store.addToCart(store.menuItem('food-01')!, note: '   no ice   ');
      expect(store.cart.single.note, 'no ice');
    });

    test('the whole-order note is bounded the same way', () async {
      store.addToCart(store.menuItem('food-01')!);
      store.setCartNote('y' * 5000);
      final order = await store.submitOrder();
      expect(order.customerNote!.length, kMaxNoteLength);
    });

    test('a line note edited after the fact is bounded too', () {
      store.addToCart(store.menuItem('food-01')!);
      store.setCartLineNote(store.cart.single.id, 'z' * 5000);
      expect(store.cart.single.note!.length, kMaxNoteLength);
    });
  });
}

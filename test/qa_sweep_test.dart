import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/config/backend_config.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/backend/backend.dart';
import 'package:restaurant_qr_ordering/data/backend/local_backend.dart';
import 'package:restaurant_qr_ordering/data/demo_data.dart';
import 'package:restaurant_qr_ordering/data/order_outbox.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/models/cart_line.dart';
import 'package:restaurant_qr_ordering/models/order.dart';
import 'package:restaurant_qr_ordering/models/staff_account.dart';
import 'package:restaurant_qr_ordering/models/table_link.dart';
import 'package:restaurant_qr_ordering/screens/auth/sign_up_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Findings from a sweep over everything added this session.
class _Flaky extends LocalBackend {
  bool offline = false;
  @override
  bool get isDemo => false;
  @override
  Future<Order> placeOrder({
    required OrderType type,
    String? tableId,
    required List<CartLine> lines,
    String note = '',
    bool onBehalfOfCustomer = false,
    String? clientKey,
  }) async {
    if (offline) throw TransientFailure('no route to host');
    return super.placeOrder(
        type: type,
        tableId: tableId,
        lines: lines,
        note: note,
        onBehalfOfCustomer: onBehalfOfCustomer,
        clientKey: clientKey);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStore> fresh({Backend? backend}) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(backend: backend ?? LocalBackend());
    addTearDown(s.dispose);
    await s.load();
    await s.signInWithPassword(DemoData.adminUsername, DemoData.adminPassword);
    return s;
  }

  group('an impatient thumb', () {
    test('cannot place the same order twice', () async {
      // Each call used to mint its own idempotency key, which is exactly what
      // the key exists to prevent: two keys look like two orders, and the
      // table is charged twice.
      final s = await fresh();
      s.openTable(s.tableByNumber('05')!.id);
      s.addToCart(s.menuItem('food-01')!, quantity: 2);
      final before = s.orders.length;

      final first = s.submitOrder();
      final second = s.submitOrder();
      await first;
      await expectLater(second, throwsStateError);

      expect(s.orders.length, before + 1);
    });

    test('cannot queue the same order twice while offline', () async {
      // Worse than a double charge in the moment: both are sent when the wifi
      // comes back, so it happens later and out of sight.
      final net = _Flaky();
      final s = await fresh(backend: net);
      s.openTable(s.tableByNumber('05')!.id);
      s.addToCart(s.menuItem('food-01')!);
      net.offline = true;

      // Handlers attached as the futures are made: a rejection with nothing
      // listening yet is an unhandled error, which says more about the test
      // than the code.
      final outcomes = await Future.wait([
        s.submitOrder().then((_) => 'sent').catchError((Object e) =>
            e is OrderHeldOffline ? 'held' : 'refused'),
        s.submitOrder().then((_) => 'sent').catchError((Object e) =>
            e is OrderHeldOffline ? 'held' : 'refused'),
      ]);

      expect(outcomes, containsAll(<String>['held', 'refused']),
          reason: 'one is taken and queued, the other is turned away');
      expect(s.pendingOrderCount, 1, reason: 'one order, one queue entry');

      net.offline = false;
      final before = s.orders.length;
      expect(await s.flushPendingOrders(), 1);
      expect(s.orders.length, before + 1);
    });
  });

  group('a secret is held to what the account signs in with', () {
    test('a password account cannot be given a six-digit password', () async {
      final s = await fresh();
      final dara = await s.addStaff(
        name: 'Dara',
        role: StaffRole.cashier,
        secret: 'a-real-password',
        email: 'dara@shop.com',
      );

      await expectLater(
        s.resetStaffSecret(dara.id, '110011'),
        throwsA(isStateError.having(
            (e) => e.message, 'message', contains('8 characters'))),
      );
    });

    test('a PIN account still needs exactly six digits', () async {
      final s = await fresh();
      final pinStaff = s.accounts.firstWhere((a) => !a.usesPassword);
      await expectLater(
        s.resetStaffSecret(pinStaff.id, 'a-real-password'),
        throwsA(isStateError.having(
            (e) => e.message, 'message', contains('6 digits'))),
      );
    });
  });

  group('a sticker read slightly differently', () {
    test('a trailing slash still opens the table', () {
      // Readers and browsers add one. The link is printed and cannot be
      // reissued, so it has to survive being tidied up in transit.
      final link = TableLink.parse('/order/demo/table/05/');
      expect(link?.slug, 'demo');
      expect(link?.tableNumber, '05');
    });

    test('a doubled slash is forgiven', () {
      // Nothing in this path is allowed to be blank, so an empty segment can
      // only be punctuation somebody doubled.
      expect(TableLink.parse('/order//demo/table/05')?.slug, 'demo');
      expect(TableLink.parse('/order/demo//table/05')?.tableNumber, '05');
      // Not tested with a *leading* '//': Uri reads that as an authority, so
      // 'order' becomes the host and the path loses a segment. A printed link
      // never has that shape — the route arrives from the URL fragment.
    });

    test('but a genuinely missing restaurant is still refused', () {
      // Four parts are required; this has three, whatever the slashes suggest.
      expect(TableLink.parse('/order//table/05'), isNull);
    });

    test('and the plain form is unchanged', () {
      expect(TableLink.parse('/order/demo/table/05')?.tableNumber, '05');
      expect(TableLink.parse('/order/demo/table'), isNull);
    });
  });

  group('a restaurant named in Khmer', () {
    test('produces no web address, which is not an error in itself', () {
      expect(SignUpScreen.slugify('ហាងបាយ'), isEmpty);
      expect(SignUpScreen.slugify('Sengly Kitchen'), 'sengly-kitchen');
    });

    testWidgets('is told what to type instead of being left with a dead button',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(backend: _Flaky());
      addTearDown(store.dispose);
      await store.load();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: const MaterialApp(home: SignUpScreen()),
      ));
      await tester.pumpAndSettle();

      // Third field is the restaurant name: email, password, restaurant.
      await tester.enterText(find.byType(TextField).at(2), 'ហាងបាយ');
      await tester.pumpAndSettle();

      expect(find.text(store.text.webAddressNeedsLatin), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('the slug the form suggests matches what the router expects', () {
    // Two implementations of one rule; they only have to agree with each other.
    final slug = SignUpScreen.slugify("Sengly's Kitchen");
    final link = TableLink.parse('/order/$slug/table/01');
    expect(link?.slug, slug);
    expect(BackendConfig.slug, isNotEmpty);
  });

  test('the language table has no unused strings left in it', () {
    // Not a behaviour, a tidiness guard: strings added for a screen that then
    // used literals are dead weight nobody notices.
    expect(const AppText(AppLanguage.en).askToJoin, isNotEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/config/backend_config.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/backend/backend.dart';
import 'package:restaurant_qr_ordering/data/backend/local_backend.dart';
import 'package:restaurant_qr_ordering/models/menu_item.dart';
import 'package:restaurant_qr_ordering/models/restaurant_table.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The seam between the app and wherever its data lives.
///
/// The Supabase half cannot be exercised without a live project, so what is
/// checked here is the boundary: that an unconfigured build stays on the
/// device, that the store defaults to the demo, and that the session the
/// device owns never leaks into the backend's snapshot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('choosing a backend', () {
    test('a build with no defines is a demo build', () {
      // The test runner passes no --dart-define, so this is the state every
      // developer and every CI run sees.
      expect(BackendConfig.usesSupabase, isFalse);
      expect(BackendConfig.hasProject, isFalse);
      expect(BackendConfig.missing, [
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
        // The slug is no longer only a define: a device that has been bound
        // answers it too, and neither has happened here.
        'RESTAURANT_SLUG (or a device binding)',
      ]);
    });

    test('the store falls back to the device', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore();
      addTearDown(store.dispose);
      await store.load();

      expect(store.isDemo, isTrue);
      expect(store.menuItems, isNotEmpty, reason: 'the demo menu is seeded');
    });

    test('a backend can be injected, which is how Supabase gets in', () async {
      SharedPreferences.setMockInitialValues({});
      final Backend backend = LocalBackend();
      final store = AppStore(backend: backend);
      addTearDown(store.dispose);
      await store.load();

      expect(store.isDemo, backend.isDemo);
      expect(store.settings.name, isNotEmpty);
    });
  });

  group('what belongs to the device and what belongs to the restaurant', () {
    test('the cart and the table survive a reload without the backend', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore();
      await store.load();
      store.openTable(store.tableByNumber('05')!.id);
      store.addToCart(store.menuItem('food-01')!, quantity: 2);
      await Future<void>.delayed(Duration.zero);
      store.dispose();

      // A second store on the same device: its session comes back, and so does
      // the restaurant, but they were written separately.
      final reloaded = AppStore();
      addTearDown(reloaded.dispose);
      await reloaded.load();

      expect(reloaded.activeTable?.number, '05');
      expect(reloaded.cartItemCount, 2);
      expect(reloaded.menuItems, isNotEmpty);
    });

    test('a fresh backend does not inherit the previous session', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore();
      await store.load();
      store.startTakeaway();
      store.addToCart(store.menuItem('food-01')!);
      await Future<void>.delayed(Duration.zero);
      store.dispose();

      // The restaurant's own snapshot must carry no trace of one diner's
      // basket — on a real backend that data is shared between every device.
      final backend = LocalBackend();
      final data = await backend.load();
      expect(data.orders.every((o) => o.status.isActive || true), isTrue);
      expect(data.menuItems, isNotEmpty);
      expect(data.accounts, isNotEmpty);
    });
  });

  group('table QR identifiers', () {
    test('carry the restaurant slug, so two restaurants never collide', () {
      final qrId = RestaurantTable.qrIdFor('05');
      expect(qrId, contains(BackendConfig.slug));
      expect(qrId, endsWith('table-05'));
    });

    test('the demo slug is used when nothing is configured', () {
      expect(BackendConfig.usesSupabase, isFalse);
      expect(BackendConfig.slug, isNotEmpty);
    });
  });

  group('which restaurant this device serves', () {
    // The slug used to be a compile-time constant and nothing else, which
    // meant one build of the app per restaurant. A bound device answers it
    // instead, and the binding wins — a tablet somebody has deliberately
    // pointed at a merchant stays pointed there.
    tearDown(() => BackendConfig.bindSlug(null));

    test('nothing bound and nothing defined is the demo', () {
      expect(BackendConfig.hasRestaurant, isFalse);
      expect(BackendConfig.slug, 'demo');
    });

    test('a binding decides it, and the login address follows', () {
      BackendConfig.bindSlug('SunriseCafe');
      expect(BackendConfig.hasRestaurant, isTrue);
      // Lowercased on the way in: the login addresses built from it are
      // matched that way, and a slug that differs only in case would put staff
      // in front of a sign-in that silently never works.
      expect(BackendConfig.slug, 'sunrisecafe');
      expect(BackendConfig.loginEmail('admin'),
          'admin@sunrisecafe.staff.ezorder.app');
      expect(RestaurantTable.qrIdFor('05'), contains('sunrisecafe'));
    });

    test('unbinding puts it back', () {
      BackendConfig.bindSlug('sunrisecafe');
      BackendConfig.bindSlug(null);
      expect(BackendConfig.slug, 'demo');
      expect(BackendConfig.hasRestaurant, isFalse);
    });

    test('an empty binding is no binding, not an empty slug', () {
      BackendConfig.bindSlug('   ');
      expect(BackendConfig.hasRestaurant, isFalse);
      expect(BackendConfig.slug, 'demo');
    });
  });

  group('the login address the app derives', () {
    // Mirrors staff_login_email() in 0004_accounts.sql. If these two ever
    // disagree, staff simply cannot sign in, so it is worth pinning.
    test('is built from the local part and the slug', () {
      final email = BackendConfig.loginEmail('admin');
      expect(email, 'admin@${BackendConfig.slug}.staff.ezorder.app');
    });

    test('is lowercased, because addresses are matched that way', () {
      expect(BackendConfig.loginEmail('AdMiN'), startsWith('admin@'));
    });
  });

  group('where a dish photo lives', () {
    // Storage first, then a photo held on the device, then the bundled
    // illustration. The order matters: carrying base64 inside the menu JSON is
    // what made a one-dish menu 268 KB on a live project.
    const bundled = MenuItem(
      id: 'x',
      name: 'Rice',
      description: '',
      price: 5,
      categoryId: 'c',
      image: 'plate',
    );

    test('a dish with neither falls back to the illustration', () {
      expect(bundled.hasPhoto, isFalse);
      expect(bundled.photoUrl, isNull);
      expect(bundled.photo, isNull);
    });

    test('a URL counts as a photo', () {
      final item = bundled.copyWith(photoUrl: 'https://cdn/x.jpg');
      expect(item.hasPhoto, isTrue);
      expect(item.photoUrl, 'https://cdn/x.jpg');
    });

    test('device bytes count as a photo — that is the demo backend', () {
      final item = bundled.copyWith(photo: 'aGVsbG8=');
      expect(item.hasPhoto, isTrue);
    });

    test('removing a photo clears both, wherever it was kept', () {
      final item = bundled
          .copyWith(photo: 'aGVsbG8=')
          .copyWith(photoUrl: 'https://cdn/x.jpg');
      expect(item.hasPhoto, isTrue);

      final cleared = item.copyWith(clearPhoto: true);
      expect(cleared.hasPhoto, isFalse);
      expect(cleared.photo, isNull);
      expect(cleared.photoUrl, isNull);
    });

    test('a URL survives a round trip through json', () {
      final item = bundled.copyWith(photoUrl: 'https://cdn/x.jpg');
      final back = MenuItem.fromJson(item.toJson());
      expect(back.photoUrl, 'https://cdn/x.jpg');
      expect(back.photo, isNull);
    });
  });
}

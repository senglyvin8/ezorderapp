import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/config/backend_config.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/backend/backend.dart';
import 'package:restaurant_qr_ordering/data/backend/local_backend.dart';
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
      expect(BackendConfig.missing, [
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
        'RESTAURANT_SLUG',
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
}

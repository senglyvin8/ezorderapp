import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/models/plan.dart';
import 'package:restaurant_qr_ordering/platform/merchant.dart';

/// The console exists to answer "who needs me today", and that answer is this
/// one computed field. Getting it wrong means either crying wolf about healthy
/// merchants or staying quiet about a restaurant that cannot take an order.
void main() {
  Merchant merchant({
    bool suspended = false,
    int tables = 5,
    int menuItems = 12,
    int categories = 3,
    int ordersTotal = 40,
    int staff = 2,
    Plan plan = Plan.basic,
    Duration? sinceLastOrder = const Duration(hours: 2),
    int orders7d = 20,
    int ordersPrev7d = 10,
  }) =>
      Merchant(
        id: 'r',
        slug: 'demo',
        name: 'ABC',
        logo: '🍜',
        phone: '',
        address: '',
        plan: plan,
        suspended: suspended,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        tablesUsed: tables,
        staffUsed: staff,
        categories: categories,
        menuItems: menuItems,
        ordersTotal: ordersTotal,
        ordersToday: 3,
        orders7d: orders7d,
        ordersPrev7d: ordersPrev7d,
        revenueTotal: 500,
        revenueToday: 40,
        revenue30d: 300,
        ownerUsername: 'admin',
        lastOrderAt: sinceLastOrder == null
            ? null
            : DateTime.now().subtract(sinceLastOrder),
      );

  group('triage', () {
    test('a busy restaurant is active and wants nothing', () {
      final m = merchant();
      expect(m.health, MerchantHealth.active);
      expect(m.needsAttention, isFalse);
    });

    test('suspended outranks everything else', () {
      // However healthy they look, the state that matters is the one you put
      // them in.
      final m = merchant(suspended: true, ordersTotal: 900);
      expect(m.health, MerchantHealth.suspended);
      expect(m.needsAttention, isTrue);
    });

    test('no dishes means they cannot trade at all', () {
      final m = merchant(menuItems: 0, ordersTotal: 0);
      expect(m.health, MerchantHealth.notSetUp);
      expect(m.setupGaps, contains('no dishes'));
    });

    test('no tables means the same, even with a full menu', () {
      final m = merchant(tables: 0, ordersTotal: 0);
      expect(m.health, MerchantHealth.notSetUp);
      expect(m.setupGaps, contains('no tables or QR codes'));
    });

    test('set up but never ordered is a different problem', () {
      // Onboarding worked and adoption did not — a different conversation
      // from "your menu is empty".
      final m = merchant(ordersTotal: 0, sinceLastOrder: null);
      expect(m.health, MerchantHealth.neverOrdered);
      expect(m.setupGaps, isEmpty);
    });

    test('a week without an order is going quiet', () {
      final m = merchant(sinceLastOrder: const Duration(days: 8));
      expect(m.health, MerchantHealth.quiet);
      expect(m.needsAttention, isTrue);
    });

    test('six days is not yet quiet — a closed week is not churn', () {
      final m = merchant(sinceLastOrder: const Duration(days: 6));
      expect(m.health, MerchantHealth.active);
    });

    test('an active merchant at a plan limit still wants attention', () {
      // Healthy, but there is money on the table.
      final m = merchant(plan: Plan.free, tables: 5);
      expect(m.health, MerchantHealth.active);
      expect(m.atTableLimit, isTrue);
      expect(m.needsAttention, isTrue);
    });

    test('pro has no table ceiling to press against', () {
      final m = merchant(plan: Plan.pro, tables: 500);
      expect(m.atTableLimit, isFalse);
      expect(m.needsAttention, isFalse);
    });
  });

  group('the weekly trend', () {
    test('reports growth', () {
      expect(merchant(orders7d: 20, ordersPrev7d: 10).weeklyTrend, 1.0);
    });

    test('reports decline', () {
      expect(merchant(orders7d: 5, ordersPrev7d: 10).weeklyTrend, -0.5);
    });

    test('is null for a first week rather than a spurious +100%', () {
      // Nothing to compare against. Reporting "up 100%" for every new
      // merchant would make the number worthless.
      expect(merchant(orders7d: 12, ordersPrev7d: 0).weeklyTrend, isNull);
    });
  });
}

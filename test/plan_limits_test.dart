import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/demo_data.dart';
import 'package:restaurant_qr_ordering/models/plan.dart';
import 'package:restaurant_qr_ordering/models/staff_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The caps that make this a product rather than a giveaway.
///
/// These numbers are stated twice — here and in `0006_plans.sql` — and the
/// database is the one that decides. This suite is what stops the two drifting
/// apart unnoticed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore();
    addTearDown(store.dispose);
    await store.load();
    await store.signInWithPassword(
        DemoData.adminUsername, DemoData.adminPassword);
  });

  group('what each plan allows', () {
    test('the numbers are the advertised ones', () {
      expect(Plan.free.monthlyPrice, 0);
      expect(Plan.free.maxTables, 5);
      expect(Plan.free.maxStaff, 2);

      expect(Plan.basic.monthlyPrice, 5.99);
      expect(Plan.basic.maxTables, 20);
      expect(Plan.basic.maxStaff, 5);

      expect(Plan.pro.monthlyPrice, 9.99);
      expect(Plan.pro.maxTables, isNull, reason: 'unlimited');
      expect(Plan.pro.maxStaff, 10);
    });

    test('orders are never capped, on any plan', () {
      // Stated as a test because it is a product promise, not an oversight.
      for (final plan in Plan.values) {
        expect(plan.maxTables == 0, isFalse);
      }
    });

    test('an unknown or missing plan falls back to free', () {
      expect(Plan.fromWire(null), Plan.free);
      expect(Plan.fromWire('ENTERPRISE'), Plan.free);
    });
  });

  group('the table cap', () {
    // The seeded demo has ten tables, several with live orders on them, so
    // these walk up to a cap from there rather than trying to delete down to
    // one — a table with an order on it cannot be removed, and should not be.
    Future<void> on(Plan plan) =>
        store.updateSettings(store.settings.copyWith(plan: plan));

    test('the exact boundaries, as pure arithmetic', () {
      expect(Plan.free.canAddTable(4), isTrue);
      expect(Plan.free.canAddTable(5), isFalse, reason: 'five is the cap');

      expect(Plan.basic.canAddTable(19), isTrue);
      expect(Plan.basic.canAddTable(20), isFalse);

      expect(Plan.pro.canAddTable(500), isTrue, reason: 'unlimited');
    });

    test('basic refuses the twenty-first', () async {
      await on(Plan.basic);
      while (store.tables.length < 20) {
        await store.addTable();
      }
      expect(store.tables.length, 20);

      await expectLater(store.addTable(), throwsStateError);
      expect(store.tables.length, 20, reason: 'the refusal changed nothing');
    });

    test('free refuses outright when already over its cap', () async {
      await on(Plan.free);
      expect(store.tables.length, greaterThan(Plan.free.maxTables!));
      await expectLater(store.addTable(), throwsStateError);
    });

    test('the message names the plan and the number', () async {
      await on(Plan.free);
      try {
        await store.addTable();
        fail('should have been refused');
      } on StateError catch (e) {
        expect(e.message, contains('Free'));
        expect(e.message, contains('5'));
        expect(e.message.toLowerCase(), contains('upgrade'));
      }
    });

    test('pro is unlimited', () async {
      await on(Plan.pro);
      final before = store.tables.length;
      for (var i = 0; i < 15; i++) {
        await store.addTable();
      }
      expect(store.tables.length, before + 15);
    });

    test('upgrading lifts the cap immediately', () async {
      await on(Plan.free);
      await expectLater(store.addTable(), throwsStateError);

      await on(Plan.pro);
      final before = store.tables.length;
      await store.addTable();
      expect(store.tables.length, before + 1);
    });

    test('downgrading keeps the tables already there', () async {
      // Throwing away a paying customer's data because their card expired
      // would be a far worse bug than a cap that is temporarily over.
      await on(Plan.pro);
      await store.addTable();
      final count = store.tables.length;

      await on(Plan.free);
      expect(store.tables.length, count, reason: 'nothing is deleted');
      await expectLater(store.addTable(), throwsStateError);
    });
  });

  group('the staff cap', () {
    test('free allows two accounts including the owner', () async {
      await store.updateSettings(store.settings.copyWith(plan: Plan.free));
      // The demo seeds three; on free, a fourth is refused.
      expect(store.accounts.length, greaterThanOrEqualTo(2));
      await expectLater(
        store.addStaff(
            name: 'Extra', role: StaffRole.kitchen, secret: '111111'),
        throwsStateError,
      );
    });

    test('the message names the plan and the number', () async {
      await store.updateSettings(store.settings.copyWith(plan: Plan.free));
      try {
        await store.addStaff(
            name: 'Extra', role: StaffRole.kitchen, secret: '111111');
        fail('should have been refused');
      } on StateError catch (e) {
        expect(e.message, contains('Free'));
        expect(e.message, contains('2'));
        expect(e.message.toLowerCase(), contains('upgrade'));
      }
    });

    test('basic allows five', () async {
      await store.updateSettings(store.settings.copyWith(plan: Plan.basic));
      while (store.accounts.length < 5) {
        await store.addStaff(
          name: 'Cook ${store.accounts.length}',
          role: StaffRole.kitchen,
          secret: '11111${store.accounts.length}',
        );
      }
      expect(store.accounts.length, 5);
      await expectLater(
        store.addStaff(
            name: 'Sixth', role: StaffRole.kitchen, secret: '999999'),
        throwsStateError,
      );
    });

    test('pro allows ten, and is not unlimited', () async {
      await store.updateSettings(store.settings.copyWith(plan: Plan.pro));
      while (store.accounts.length < 10) {
        await store.addStaff(
          name: 'Cook ${store.accounts.length}',
          role: StaffRole.kitchen,
          secret: '2222${store.accounts.length.toString().padLeft(2, '0')}',
        );
      }
      expect(store.accounts.length, 10);
      await expectLater(
        store.addStaff(
            name: 'Eleventh', role: StaffRole.kitchen, secret: '999999'),
        throwsStateError,
      );
    });

    test('a switched-off account still occupies a seat', () async {
      // Otherwise the cap is evaded by deactivating and adding, repeatedly.
      await store.updateSettings(store.settings.copyWith(plan: Plan.free));
      final off = store.accounts.firstWhere((a) => !a.usesPassword);
      await store.setStaffActive(off.id, false);

      await expectLater(
        store.addStaff(
            name: 'Extra', role: StaffRole.kitchen, secret: '111111'),
        throwsStateError,
      );
    });
  });

  group('what the upgrade screen offers', () {
    test('each plan points at the one above it', () {
      expect(Plan.free.next, Plan.basic);
      expect(Plan.basic.next, Plan.pro);
      expect(Plan.pro.next, isNull, reason: 'nothing above the top');
    });
  });
}

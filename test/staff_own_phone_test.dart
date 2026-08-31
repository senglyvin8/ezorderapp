import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/demo_data.dart';
import 'package:restaurant_qr_ordering/models/staff_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Staff who carry their own phone, and staff who share the counter tablet.
///
/// A PIN means nothing on its own: the app must already know the restaurant
/// before it can offer a list of names to tap, which is why a personal phone
/// otherwise has to be told the merchant ID first. An address does not have
/// that problem — it identifies the person, and their staff row identifies
/// where they work, exactly as it always has for owners.
///
/// So the owner chooses per person, and the choice is really about the device.
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

  group('a cashier with their own phone', () {
    test('is created with an address and a password', () async {
      final made = await store.addStaff(
        name: 'Dara',
        role: StaffRole.cashier,
        secret: 'a-real-password',
        email: 'dara@theshop.com',
      );

      expect(made.email, 'dara@theshop.com');
      expect(made.usesPassword, isTrue);
    });

    test('signs in the way an owner does', () async {
      await store.addStaff(
        name: 'Dara',
        role: StaffRole.cashier,
        secret: 'a-real-password',
        email: 'dara@theshop.com',
      );
      await store.signOut();

      expect(await store.signInWithPassword(
          'dara@theshop.com', 'a-real-password'), isTrue);
      expect(store.currentUser?.name, 'Dara');
      expect(store.canTakePayment, isTrue);
      expect(store.canManageRestaurant, isFalse,
          reason: 'a cashier is still a cashier');
    });

    test('never appears on the PIN pad', () async {
      // Listing them would offer a PIN pad against an account with no PIN.
      await store.addStaff(
        name: 'Dara',
        role: StaffRole.cashier,
        secret: 'a-real-password',
        email: 'dara@theshop.com',
      );
      expect(store.pinAccounts.map((a) => a.name), isNot(contains('Dara')));
    });

    test('needs a real password, not a PIN', () async {
      await expectLater(
        store.addStaff(
          name: 'Dara',
          role: StaffRole.cashier,
          secret: '110011',
          email: 'dara@theshop.com',
        ),
        throwsA(isStateError.having(
            (e) => e.message, 'message', contains('8 characters'))),
      );
    });

    test('cannot take an address somebody already uses', () async {
      await expectLater(
        store.addStaff(
          name: 'Impostor',
          role: StaffRole.cashier,
          secret: 'a-real-password',
          email: DemoData.adminEmail,
        ),
        throwsStateError,
      );
    });
  });

  group('a cook on the shared tablet', () {
    test('is created with a PIN and no address', () async {
      final made = await store.addStaff(
        name: 'Sophal Two',
        role: StaffRole.kitchen,
        secret: '445566',
      );

      expect(made.email, isEmpty);
      expect(made.usesPassword, isFalse);
    });

    test('appears on the PIN pad, to be tapped', () async {
      await store.addStaff(
        name: 'Sophal Two',
        role: StaffRole.kitchen,
        secret: '445566',
      );
      expect(store.pinAccounts.map((a) => a.name), contains('Sophal Two'));
    });

    test('still needs exactly six digits', () async {
      await expectLater(
        store.addStaff(
          name: 'Sophal Two',
          role: StaffRole.kitchen,
          secret: '1234',
        ),
        throwsA(isStateError.having(
            (e) => e.message, 'message', contains('6 digits'))),
      );
    });

    test('a malformed address is refused rather than ignored', () async {
      // Silently dropping it would make a PIN account somebody thinks has an
      // address, and they would spend an evening trying to sign in with it.
      await expectLater(
        store.addStaff(
          name: 'Sophal Two',
          role: StaffRole.kitchen,
          secret: 'a-real-password',
          email: 'not-an-address',
        ),
        throwsA(isStateError.having(
            (e) => e.message, 'message', contains('email address'))),
      );
    });
  });

  test('an owner still needs an address whatever else changes', () async {
    await expectLater(
      store.addStaff(
        name: 'Second Owner',
        role: StaffRole.admin,
        secret: 'a-real-password',
      ),
      throwsStateError,
    );
  });
}

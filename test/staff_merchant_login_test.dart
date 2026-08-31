import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/data/merchant_binding.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/models/merchant_code.dart';
import 'package:restaurant_qr_ordering/screens/auth/merchant_bind_screen.dart';

/// A member of staff setting up their own phone.
///
/// A cashier has a PIN and no password, and no business knowing the owner's —
/// so signing in as the owner cannot be how they point a phone at the right
/// restaurant. They type the merchant ID the owner read down the phone to them.
///
/// The ID identifies a restaurant and grants nothing. What it buys is a list of
/// names and a PIN pad, both of which still have to be satisfied.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const found = MerchantBinding(
    slug: 'riverside',
    name: 'Riverside Grill',
    logo: '🍜',
  );

  Future<(List<String>, List<MerchantBinding>)> pump(
    WidgetTester tester, {
    MerchantBinding? result = found,
    AppLanguage language = AppLanguage.en,
  }) async {
    final looked = <String>[];
    final bound = <MerchantBinding>[];

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 950);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: MerchantBindScreen(
        text: AppText(language),
        signIn: (_, __) async => null,
        byCode: (code) async {
          looked.add(code);
          return result;
        },
        onBound: bound.add,
      ),
    ));
    await tester.pumpAndSettle();
    return (looked, bound);
  }

  group('the staff door', () {
    testWidgets('is offered, and the owner door is what opens', (tester) async {
      const t = AppText(AppLanguage.en);
      await pump(tester);

      // An owner setting a device up for the first time is the common case.
      expect(find.text(t.emailAddress), findsOneWidget);
      expect(find.text(t.imStaffWithAnId), findsOneWidget);
      expect(find.text(t.merchantId), findsNothing);
    });

    testWidgets('swaps to a merchant ID field', (tester) async {
      const t = AppText(AppLanguage.en);
      await pump(tester);

      await tester.tap(find.text(t.imStaffWithAnId));
      await tester.pumpAndSettle();

      expect(find.text(t.merchantId), findsOneWidget);
      expect(find.text(t.emailAddress), findsNothing);
      expect(find.text(t.imTheOwner), findsOneWidget);
    });

    testWidgets('finds the restaurant and binds the phone to it',
        (tester) async {
      const t = AppText(AppLanguage.en);
      final (looked, bound) = await pump(tester);

      await tester.tap(find.text(t.imStaffWithAnId));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'ez-4k7q2m');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.findRestaurant));
      await tester.pumpAndSettle();

      expect(looked, ['ez-4k7q2m']);
      expect(bound.single.slug, 'riverside');
    });

    testWidgets('an unknown ID says so and binds nothing', (tester) async {
      const t = AppText(AppLanguage.en);
      final (_, bound) = await pump(tester, result: null);

      await tester.tap(find.text(t.imStaffWithAnId));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'EZ-000000');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.findRestaurant));
      await tester.pumpAndSettle();

      expect(find.text(t.noSuchMerchant), findsOneWidget);
      expect(bound, isEmpty);
    });

    testWidgets('a build with nothing to look up does not offer the door',
        (tester) async {
      // The demo has one restaurant and no service behind it.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 950);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: MerchantBindScreen(
          text: const AppText(AppLanguage.en),
          signIn: (_, __) async => null,
          onBound: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(const AppText(AppLanguage.en).imStaffWithAnId),
          findsNothing);
    });
  });

  group('the ID itself', () {
    test('is forgiving about how it was written down', () {
      // Read aloud down a phone, then typed by somebody in a hurry.
      for (final typed in ['EZ-4K7Q2M', 'ez4k7q2m', ' ez-4k7q2m ', '4K7Q2M']) {
        expect(MerchantCode.normalize(typed), 'EZ-4K7Q2M', reason: typed);
      }
    });

    test('reads O as zero and I as one, which is why the alphabet omits them',
        () {
      expect(MerchantCode.normalize('EZ-4K7Q2O'), 'EZ-4K7Q20');
      expect(MerchantCode.normalize('EZ-4K7Q2I'), 'EZ-4K7Q21');
    });

    test('refuses what cannot be a code', () {
      for (final bad in ['', 'EZ-', 'EZ-4K7Q2', 'EZ-4K7Q2MM', 'EZ-4K7Q2U']) {
        expect(MerchantCode.isValid(bad), isFalse, reason: bad);
      }
    });
  });

  group('layout', () {
    for (final language in AppLanguage.values) {
      testWidgets('the staff door fits in ${language.name}', (tester) async {
        final t = AppText(language);
        await pump(tester, language: language);
        await tester.tap(find.text(t.imStaffWithAnId));
        await tester.pumpAndSettle();

        expect(find.text(t.staffSetUpBlurb), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

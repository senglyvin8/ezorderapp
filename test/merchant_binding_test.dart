import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/config/app_config.dart';
import 'package:restaurant_qr_ordering/data/merchant_binding.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/screens/auth/merchant_bind_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pointing a device at a restaurant.
///
/// This is what replaced one build of the app per restaurant, so the things
/// worth pinning are the ones that would leave somebody holding a tablet that
/// cannot be set up: that the owner's credentials are the only key, that the
/// answer survives a restart, and that a wrong password does not look like a
/// broken service.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const binding = MerchantBinding(
    slug: 'sunrise',
    name: 'Sunrise Cafe',
    logo: '☕',
  );

  group('what the device remembers', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('nothing, until an owner signs in on it', () async {
      expect(await MerchantBinding.read(), isNull);
    });

    test('the restaurant it was bound to, across a restart', () async {
      await binding.save();

      final read = await MerchantBinding.read();
      expect(read?.slug, 'sunrise');
      expect(read?.name, 'Sunrise Cafe');
      expect(read?.logo, '☕');
    });

    test('and forgets it when the tablet moves house', () async {
      await binding.save();
      await MerchantBinding.clear();
      expect(await MerchantBinding.read(), isNull);
    });

    test('a snapshot it cannot make sense of is discarded, not fatal', () async {
      SharedPreferences.setMockInitialValues(
          {'rqo_merchant_binding_v1': 'not json at all'});
      expect(await MerchantBinding.read(), isNull);
      // And discarded for good, so the next launch does not try again.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('rqo_merchant_binding_v1'), isNull);
    });

    test('a binding with no slug is no binding — it could open nothing',
        () async {
      SharedPreferences.setMockInitialValues(
          {'rqo_merchant_binding_v1': '{"slug":"","name":"X"}'});
      expect(await MerchantBinding.read(), isNull);
    });
  });

  group('the setup screen', () {
    const t = AppText(Brand.defaultLanguage);

    Future<void> pump(
      WidgetTester tester, {
      required MerchantSignIn signIn,
      required void Function(MerchantBinding) onBound,
      VoidCallback? onGuest,
    }) async {
      // A phone rather than the 800x600 default: the guest offer sits below
      // the fold on a short viewport, and a list does not build what it
      // cannot show.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(420, 940);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: MerchantBindScreen(
          text: t,
          signIn: signIn,
          onBound: onBound,
          onGuest: onGuest,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the owner signs in, and the device follows them',
        (tester) async {
      MerchantBinding? bound;
      await pump(
        tester,
        signIn: (email, password) async =>
            email == 'owner@sunrise.com' && password == 'password12'
                ? binding
                : null,
        onBound: (b) => bound = b,
      );

      await tester.enterText(
          find.widgetWithText(TextField, t.emailAddress), 'owner@sunrise.com');
      await tester.enterText(
          find.widgetWithText(TextField, t.password), 'password12');
      await tester.tap(find.widgetWithText(FilledButton, t.signIn));
      await tester.pumpAndSettle();

      // Nothing to confirm: the credentials proved who they are and their
      // staff row said where they work, so there is no wrong restaurant to
      // land on.
      expect(bound?.slug, 'sunrise');
    });

    testWidgets('wrong credentials keep them on the form', (tester) async {
      MerchantBinding? bound;
      await pump(
        tester,
        signIn: (_, __) async => null,
        onBound: (b) => bound = b,
      );

      await tester.enterText(
          find.widgetWithText(TextField, t.emailAddress), 'owner@sunrise.com');
      await tester.enterText(
          find.widgetWithText(TextField, t.password), 'wrong');
      await tester.tap(find.widgetWithText(FilledButton, t.signIn));
      await tester.pumpAndSettle();

      expect(bound, isNull);
      expect(find.text(t.wrongPassword), findsOneWidget);
    });

    testWidgets('a service that cannot be reached is not a wrong password',
        (tester) async {
      await pump(
        tester,
        signIn: (_, __) async => throw StateError('Could not reach the service.'),
        onBound: (_) {},
      );

      await tester.enterText(
          find.widgetWithText(TextField, t.emailAddress), 'owner@sunrise.com');
      await tester.enterText(
          find.widgetWithText(TextField, t.password), 'password12');
      await tester.tap(find.widgetWithText(FilledButton, t.signIn));
      await tester.pumpAndSettle();

      // The distinction matters: one of these is worth retrying and the other
      // means they typed something wrong.
      expect(find.text('Could not reach the service.'), findsOneWidget);
      expect(find.text(t.wrongPassword), findsNothing);
    });

    testWidgets('a visitor with no account is offered the demo',
        (tester) async {
      var guest = false;
      await pump(
        tester,
        signIn: (_, __) async => null,
        onBound: (_) {},
        onGuest: () => guest = true,
      );

      await tester.tap(find.text(t.tryAsGuest));
      await tester.pumpAndSettle();
      expect(guest, isTrue);
    });

    testWidgets('and is not offered it where there is nothing to demo',
        (tester) async {
      await pump(tester, signIn: (_, __) async => null, onBound: (_) {});
      expect(find.text(t.tryAsGuest), findsNothing);
    });
  });
}

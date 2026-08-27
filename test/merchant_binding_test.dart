import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/config/app_config.dart';
import 'package:restaurant_qr_ordering/data/merchant_binding.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/screens/auth/merchant_bind_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pointing a device at a merchant.
///
/// This is what replaced one build of the app per restaurant, so the things
/// worth pinning are the ones that would leave somebody holding a tablet that
/// cannot be set up: what the scanner accepts, what survives a restart, and
/// what happens when the code is wrong.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const code = 'EZ-4K7Q2M';
  const binding = MerchantBinding(
    code: code,
    slug: 'sunrise',
    name: 'Sunrise Cafe',
    logo: '☕',
  );

  group('what the scanner accepts', () {
    test('the join payload the owner is showing', () {
      expect(MerchantBinding.codeFromScan(binding.joinPayload), code);
      expect(binding.joinPayload, 'ezorder://join?m=EZ-4K7Q2M');
    });

    test('a link, whether the code is in the path or the query', () {
      for (final link in [
        'https://ezorder.app/join/EZ-4K7Q2M',
        'https://ezorder.app/#/join/EZ-4K7Q2M',
        'https://ezorder.app/setup?m=ez-4k7q2m',
      ]) {
        expect(MerchantBinding.codeFromScan(link), code, reason: link);
      }
    });

    test('a code typed by hand, however it was typed', () {
      expect(MerchantBinding.codeFromScan(' ez 4k7q2m '), code);
      expect(MerchantBinding.codeFromScan('4K7Q2M'), code);
    });

    test('and nothing else', () {
      // A table QR is the most likely wrong thing to point the camera at, and
      // binding a device to a table number would be a memorable bug.
      expect(MerchantBinding.codeFromScan('restaurant-demo-table-05'), isNull);
      expect(MerchantBinding.codeFromScan('https://example.com'), isNull);
      expect(MerchantBinding.codeFromScan(''), isNull);
    });
  });

  group('what the device remembers', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('nothing, until somebody sets it up', () async {
      expect(await MerchantBinding.read(), isNull);
    });

    test('the merchant it was bound to, across a restart', () async {
      await binding.save();

      final read = await MerchantBinding.read();
      expect(read?.code, code);
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
          {'rqo_merchant_binding_v1': '{"code":"$code","slug":"","name":"X"}'});
      expect(await MerchantBinding.read(), isNull);
    });
  });

  group('the setup screen', () {
    const t = AppText(Brand.defaultLanguage);

    Future<void> pump(
      WidgetTester tester, {
      required MerchantResolver resolve,
      required void Function(MerchantBinding) onBound,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: MerchantBindScreen(
          text: t,
          resolve: resolve,
          onBound: onBound,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a good code has to be confirmed before it binds',
        (tester) async {
      MerchantBinding? bound;
      await pump(
        tester,
        resolve: (c) async => c == code ? binding : null,
        onBound: (b) => bound = b,
      );

      await tester.enterText(find.byType(TextField), 'ez4k7q2m');
      await tester.tap(find.text(t.continueLabel));
      await tester.pumpAndSettle();

      // Resolved, and showing whose restaurant it is. Binding to the wrong one
      // gives a menu that is nearly right, which is far more confusing than
      // one that is obviously wrong — so somebody has to say yes.
      expect(find.text('Sunrise Cafe'), findsOneWidget);
      expect(find.text(code), findsOneWidget);
      expect(bound, isNull, reason: 'not yet — nobody has confirmed');

      await tester.tap(find.text(t.yesThatIsUs));
      await tester.pumpAndSettle();
      expect(bound?.slug, 'sunrise');
    });

    testWidgets('a code that matches nothing says so', (tester) async {
      await pump(tester, resolve: (_) async => null, onBound: (_) {});

      await tester.enterText(find.byType(TextField), 'EZ-000000');
      await tester.tap(find.text(t.continueLabel));
      await tester.pumpAndSettle();

      expect(find.text(t.noMerchantWithThatId), findsOneWidget);
      expect(find.text(t.yesThatIsUs), findsNothing);
    });

    testWidgets('a code that is not a code is caught before the round trip',
        (tester) async {
      var asked = false;
      await pump(
        tester,
        resolve: (_) async {
          asked = true;
          return null;
        },
        onBound: (_) {},
      );

      await tester.enterText(find.byType(TextField), 'nonsense');
      await tester.tap(find.text(t.continueLabel));
      await tester.pumpAndSettle();

      expect(find.text(t.merchantIdMalformed), findsOneWidget);
      expect(asked, isFalse, reason: 'no point asking about a malformed code');
    });

    testWidgets('a service that cannot be reached is not a missing merchant',
        (tester) async {
      await pump(
        tester,
        resolve: (_) async => throw StateError('Could not reach the service.'),
        onBound: (_) {},
      );

      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.text(t.continueLabel));
      await tester.pumpAndSettle();

      // The distinction matters: one of these is worth retrying and the other
      // means the code is wrong.
      expect(find.text('Could not reach the service.'), findsOneWidget);
      expect(find.text(t.noMerchantWithThatId), findsNothing);
    });
  });
}

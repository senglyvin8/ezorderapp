import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/backend/local_backend.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/screens/auth/sign_in_screen.dart';
import 'package:restaurant_qr_ordering/screens/auth/sign_up_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A backend that can send a code, standing in for Supabase.
///
/// The real one needs a project and a mail server. This records what was asked
/// and accepts one particular code, so the screens can be walked end to end.
class _SignUpBackend extends LocalBackend {
  final List<String> codesSentTo = [];
  final Set<String> takenSlugs = {'demo'};
  String? claimedName;
  String? claimedSlug;
  bool isDemoOverride = false;

  static const theCode = '123456';

  @override
  bool get isDemo => isDemoOverride;

  @override
  Future<void> sendSignUpCode(String email) async => codesSentTo.add(email);

  @override
  Future<bool> verifySignUpCode(String email, String code) async =>
      code.trim() == theCode;

  @override
  Future<bool> slugAvailable(String slug) async =>
      slug.length >= 3 && !takenSlugs.contains(slug);

  @override
  Future<void> claimRestaurant({
    required String restaurantName,
    required String slug,
    String ownerName = '',
  }) async {
    if (takenSlugs.contains(slug)) {
      throw StateError('The address "$slug" is taken. Try another.');
    }
    claimedName = restaurantName;
    claimedSlug = slug;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppStore, _SignUpBackend)> pump(WidgetTester tester,
      {AppLanguage language = AppLanguage.en}) async {
    SharedPreferences.setMockInitialValues({});
    final backend = _SignUpBackend();
    final store = AppStore(backend: backend);
    addTearDown(store.dispose);
    await store.load();
    store.setLanguage(language);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 950);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const RestaurantApp(),
    ));
    await tester.pumpAndSettle();
    return (store, backend);
  }

  group('setting up a restaurant', () {
    testWidgets('the offer is on the first screen', (tester) async {
      final (store, _) = await pump(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text(store.text.createRestaurant), findsOneWidget);
    });

    testWidgets('address, then code, then restaurant — one at a time',
        (tester) async {
      final (store, backend) = await pump(tester);
      final t = store.text;

      await tester.tap(find.text(t.createRestaurant));
      await tester.pumpAndSettle();
      expect(find.byType(SignUpScreen), findsOneWidget);

      // 1. the address
      await tester.enterText(find.byType(TextField).first, 'me@myshop.com');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sendTheCode));
      await tester.pumpAndSettle();
      expect(backend.codesSentTo, ['me@myshop.com']);

      // 2. the code
      expect(find.text(t.codeSentTo('me@myshop.com')), findsOneWidget);
      await tester.enterText(
          find.byType(TextField).first, _SignUpBackend.theCode);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.done));
      await tester.pumpAndSettle();

      // 3. the restaurant
      expect(find.text(t.restaurantName), findsOneWidget);
    });

    testWidgets('the web address is suggested from the name', (tester) async {
      final (store, _) = await pump(tester);
      final t = store.text;
      await tester.tap(find.text(t.createRestaurant));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'me@myshop.com');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sendTheCode));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).first, _SignUpBackend.theCode);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.done));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, "Sengly's Kitchen");
      await tester.pumpAndSettle();

      final slugField = tester.widgetList<TextField>(find.byType(TextField))
          .elementAt(2);
      expect(slugField.controller!.text, 'senglys-kitchen');
      expect(find.text(t.addressFree), findsOneWidget);
    });

    testWidgets('a taken address is called out before they commit',
        (tester) async {
      final (store, _) = await pump(tester);
      final t = store.text;
      await tester.tap(find.text(t.createRestaurant));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'me@myshop.com');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sendTheCode));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).first, _SignUpBackend.theCode);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.done));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Demo');
      await tester.pumpAndSettle();

      expect(find.text(t.addressTaken), findsOneWidget);
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, t.openMyRestaurant));
      expect(button.onPressed, isNull, reason: 'must not be committable');
    });

    testWidgets('a wrong code does not get past step two', (tester) async {
      final (store, _) = await pump(tester);
      final t = store.text;
      await tester.tap(find.text(t.createRestaurant));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'me@myshop.com');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sendTheCode));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '000000');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.done));
      await tester.pumpAndSettle();

      expect(find.text(t.wrongCode), findsOneWidget);
      expect(find.text(t.restaurantName), findsNothing);
    });
  });

  group('the demo', () {
    testWidgets('does not offer to set up a restaurant', (tester) async {
      // One restaurant, already open. An offer that cannot work is worse than
      // no offer.
      SharedPreferences.setMockInitialValues({});
      final backend = _SignUpBackend()..isDemoOverride = true;
      final store = AppStore(backend: backend);
      addTearDown(store.dispose);
      await store.load();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 950);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: store, child: const RestaurantApp()));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text(store.text.createRestaurant), findsNothing);
    });

    test('refuses to send a code, since it has no email', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(backend: LocalBackend());
      addTearDown(store.dispose);
      await store.load();
      await expectLater(
        store.sendSignUpCode('me@myshop.com'),
        throwsA(isStateError.having(
            (e) => e.message, 'message', contains('no email'))),
      );
    });
  });

  group('layout', () {
    for (final language in AppLanguage.values) {
      testWidgets('sign-up fits in ${language.name}', (tester) async {
        final (store, _) = await pump(tester, language: language);
        await tester.tap(find.text(store.text.createRestaurant));
        await tester.pumpAndSettle();
        expect(find.text(store.text.signUpBlurb), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

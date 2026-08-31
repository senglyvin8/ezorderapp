import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/backend/backend.dart';
import 'package:restaurant_qr_ordering/data/backend/local_backend.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/screens/auth/sign_in_screen.dart';
import 'package:restaurant_qr_ordering/screens/auth/sign_up_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A backend that accepts applications, standing in for Supabase.
class _JoinBackend extends LocalBackend {
  final Set<String> takenSlugs = {'demo'};
  final Set<String> takenEmails = {'taken@shop.com'};
  Map<String, String>? submitted;
  SignUpRequest? myRequest;
  bool isDemoOverride = false;

  @override
  bool get isDemo => isDemoOverride;

  @override
  Future<bool> slugAvailable(String slug) async =>
      slug.length >= 3 && !takenSlugs.contains(slug);

  @override
  Future<void> requestSignUp({
    required String email,
    required String password,
    required String restaurantName,
    required String slug,
    String ownerName = '',
  }) async {
    if (takenEmails.contains(email.trim().toLowerCase())) {
      throw StateError('An account already uses $email. Sign in instead.');
    }
    submitted = {
      'email': email.trim(),
      'restaurant': restaurantName.trim(),
      'slug': slug.trim(),
      'owner': ownerName.trim(),
    };
  }

  @override
  Future<SignUpRequest?> mySignUpRequest() async => myRequest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppStore, _JoinBackend)> pump(WidgetTester tester,
      {AppLanguage language = AppLanguage.en}) async {
    SharedPreferences.setMockInitialValues({});
    final backend = _JoinBackend();
    final store = AppStore(backend: backend);
    addTearDown(store.dispose);
    await store.load();
    store.setLanguage(language);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const RestaurantApp(),
    ));
    await tester.pumpAndSettle();
    return (store, backend);
  }

  Future<void> openForm(WidgetTester tester, AppStore store) async {
    await tester.tap(find.text(store.text.createRestaurant));
    await tester.pumpAndSettle();
  }

  /// Fills every field. The slug fills itself from the restaurant name.
  Future<void> fill(WidgetTester tester,
      {String email = 'me@myshop.com',
      String password = 'a-real-password',
      String restaurant = "Sengly's Kitchen"}) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), password);
    await tester.enterText(fields.at(2), restaurant);
    await tester.pumpAndSettle();
  }

  group('asking to join', () {
    testWidgets('the offer is on the first screen', (tester) async {
      final (store, _) = await pump(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text(store.text.createRestaurant), findsOneWidget);
    });

    testWidgets('one form, and it ends in a request rather than a restaurant',
        (tester) async {
      final (store, backend) = await pump(tester);
      await openForm(tester, store);
      await fill(tester);

      await tester.tap(find.text(store.text.askToJoin));
      await tester.pumpAndSettle();

      expect(backend.submitted, {
        'email': 'me@myshop.com',
        'restaurant': "Sengly's Kitchen",
        'slug': 'senglys-kitchen',
        'owner': '',
      });
      expect(find.text(store.text.requestSentTitle), findsOneWidget);
    });

    testWidgets('the web address drops apostrophes rather than splitting on them',
        (tester) async {
      // It ends up printed on every table, so senglys-kitchen, never
      // sengly-s-kitchen.
      expect(SignUpScreen.slugify("Sengly's Kitchen"), 'senglys-kitchen');
      expect(SignUpScreen.slugify('Sengly’s Kitchen'), 'senglys-kitchen');
      expect(SignUpScreen.slugify('  Rice & Noodles!  '), 'rice-noodles');
    });

    testWidgets('a taken address cannot be submitted', (tester) async {
      final (store, _) = await pump(tester);
      await openForm(tester, store);
      await fill(tester, restaurant: 'Demo');

      expect(find.text(store.text.addressTaken), findsOneWidget);
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, store.text.askToJoin));
      expect(button.onPressed, isNull);
    });

    testWidgets('a short password cannot be submitted', (tester) async {
      final (store, _) = await pump(tester);
      await openForm(tester, store);
      await fill(tester, password: 'short');

      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, store.text.askToJoin));
      expect(button.onPressed, isNull);
      expect(find.text(store.text.passwordRule), findsWidgets);
    });

    testWidgets('an address that already has an account is refused, not '
        'overwritten', (tester) async {
      // Otherwise this form is a way to reset somebody's password by knowing
      // their email.
      final (store, backend) = await pump(tester);
      await openForm(tester, store);
      await fill(tester, email: 'taken@shop.com');

      await tester.tap(find.text(store.text.askToJoin));
      await tester.pumpAndSettle();

      expect(backend.submitted, isNull);
      expect(find.textContaining('Sign in instead'), findsOneWidget);
    });
  });

  group('waiting on an answer', () {
    testWidgets('a pending applicant is told so, not shown broken tabs',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = _JoinBackend()
        ..myRequest = const SignUpRequest(
          status: SignUpStatus.pending,
          restaurantName: "Sengly's Kitchen",
          slug: 'senglys-kitchen',
        );
      final store = AppStore(backend: backend);
      addTearDown(store.dispose);
      await store.load();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: store, child: const RestaurantApp()));
      await tester.pumpAndSettle();

      expect(find.text(store.text.awaitingApproval), findsOneWidget);
      expect(find.text("Sengly's Kitchen"), findsOneWidget);
    });

    testWidgets('a refusal shows the reason it was given', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = _JoinBackend()
        ..myRequest = const SignUpRequest(
          status: SignUpStatus.rejected,
          restaurantName: 'Spam Palace',
          slug: 'spam-palace',
          note: 'We could not find this restaurant.',
        );
      final store = AppStore(backend: backend);
      addTearDown(store.dispose);
      await store.load();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: store, child: const RestaurantApp()));
      await tester.pumpAndSettle();

      expect(find.text(store.text.requestRefused), findsOneWidget);
      expect(find.text('We could not find this restaurant.'), findsOneWidget);
    });
  });

  group('the demo', () {
    testWidgets('does not offer to set up a restaurant', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = _JoinBackend()..isDemoOverride = true;
      final store = AppStore(backend: backend);
      addTearDown(store.dispose);
      await store.load();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: store, child: const RestaurantApp()));
      await tester.pumpAndSettle();

      expect(find.text(store.text.createRestaurant), findsNothing);
    });

    test('refuses an application, having one restaurant already', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(backend: LocalBackend());
      addTearDown(store.dispose);
      await store.load();
      await expectLater(
        store.requestSignUp(
          email: 'me@myshop.com',
          password: 'a-real-password',
          restaurantName: 'Mine',
          slug: 'mine',
        ),
        throwsStateError,
      );
    });
  });

  group('layout', () {
    for (final language in AppLanguage.values) {
      testWidgets('the form fits in ${language.name}', (tester) async {
        final (store, _) = await pump(tester, language: language);
        await openForm(tester, store);
        expect(find.text(store.text.signUpBlurb), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

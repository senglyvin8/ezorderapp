import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/backend/local_backend.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/screens/auth/password_reset.dart';
import 'package:restaurant_qr_ordering/screens/auth/sign_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A backend with an inbox, standing in for Supabase.
///
/// The real one cannot run in a test — it needs a project, a mail server and a
/// link somebody clicks. This records what was asked for and lets the test
/// pretend the link was followed.
class _MailBackend extends LocalBackend {
  final _recovery = StreamController<void>.broadcast();
  final List<String> sentTo = [];
  String? newPassword;

  @override
  Future<void> sendPasswordReset(String email) async => sentTo.add(email);

  @override
  Future<void> setNewPassword(String password) async {
    if (password.trim().length < 8) {
      throw StateError('A password must be at least 8 characters');
    }
    newPassword = password;
  }

  @override
  Stream<void> get passwordRecovery => _recovery.stream;

  /// The owner opening the link in their email.
  void followTheLink() => _recovery.add(null);

  @override
  Future<void> dispose() async {
    await _recovery.close();
    await super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppStore, _MailBackend)> pump(WidgetTester tester,
      {AppLanguage language = AppLanguage.en}) async {
    SharedPreferences.setMockInitialValues({});
    final mail = _MailBackend();
    final store = AppStore(backend: mail);
    addTearDown(store.dispose);
    await store.load();
    store.setLanguage(language);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const RestaurantApp(),
    ));
    await tester.pumpAndSettle();
    return (store, mail);
  }

  group('an owner who cannot get in', () {
    testWidgets('finds the way back on the screen that turned them away',
        (tester) async {
      final (store, _) = await pump(tester);
      // The installed app opens on sign-in; the owner tab is behind the
      // owner/admin door.
      await tester.tap(find.text(store.text.adminSignIn));
      await tester.pumpAndSettle();

      expect(find.text(store.text.forgotPassword), findsOneWidget);
    });

    testWidgets('asks for a link and is told nothing about who has an account',
        (tester) async {
      final (store, mail) = await pump(tester);
      await tester.tap(find.text(store.text.adminSignIn));
      await tester.pumpAndSettle();
      await tester.tap(find.text(store.text.forgotPassword));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField).last, 'owner@theirshop.com');
      await tester.pumpAndSettle();
      await tester.tap(find.text(store.text.sendResetLink));
      await tester.pumpAndSettle();

      expect(mail.sentTo, ['owner@theirshop.com']);
      // Deliberately the same answer whether or not that address exists.
      expect(find.text(store.text.resetLinkSent), findsOneWidget);
    });

    testWidgets('cannot send to something that is not an address',
        (tester) async {
      final (store, mail) = await pump(tester);
      await tester.tap(find.text(store.text.adminSignIn));
      await tester.pumpAndSettle();
      await tester.tap(find.text(store.text.forgotPassword));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'not-an-address');
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, store.text.sendResetLink));
      expect(button.onPressed, isNull, reason: 'the button should be dead');
      expect(mail.sentTo, isEmpty);
    });
  });

  group('following the link', () {
    testWidgets('puts setting a new password in front of everything',
        (tester) async {
      final (_, mail) = await pump(tester);
      expect(find.byType(SignInScreen), findsOneWidget);

      mail.followTheLink();
      await tester.pumpAndSettle();

      // Ahead of the staff gate: dropping somebody onto a sign-in screen they
      // have just said they cannot use is the one place with no way out.
      expect(find.byType(NewPasswordScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets('a new password is held to the same rule as any other',
        (tester) async {
      final (store, mail) = await pump(tester);
      mail.followTheLink();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'short');
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, store.text.save));
      expect(button.onPressed, isNull);
      expect(mail.newPassword, isNull);
    });

    testWidgets('saving it returns the owner to the app', (tester) async {
      final (store, mail) = await pump(tester);
      mail.followTheLink();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'a-real-password');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, store.text.save));
      await tester.pumpAndSettle();

      expect(mail.newPassword, 'a-real-password');
      expect(find.byType(NewPasswordScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the demo', () {
    test('says plainly that it has no email behind it', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(backend: LocalBackend());
      addTearDown(store.dispose);
      await store.load();

      await expectLater(
        store.sendPasswordReset('owner@theirshop.com'),
        throwsA(isStateError.having(
            (e) => e.message, 'message', contains('no email'))),
      );
    });
  });

  group('layout', () {
    for (final language in AppLanguage.values) {
      testWidgets('the reset sheet fits in ${language.name}', (tester) async {
        final (store, _) = await pump(tester, language: language);
        await tester.tap(find.text(store.text.adminSignIn));
        await tester.pumpAndSettle();
        await tester.tap(find.text(store.text.forgotPassword));
        await tester.pumpAndSettle();

        expect(find.text(store.text.resetPasswordTitle), findsOneWidget);
        expect(find.text(store.text.staffAskYourOwner), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

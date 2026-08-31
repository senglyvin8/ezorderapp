import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/config/backend_config.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/demo_data.dart';
import 'package:restaurant_qr_ordering/screens/auth/sign_in_screen.dart';
import 'package:restaurant_qr_ordering/screens/customer/qr_entry_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who the app greets when it opens.
///
/// An installed app is a staff device — a diner never installs anything, they
/// point a camera at a table. So the app asks who you are. The web build is the
/// opposite: it is what the QR codes open, and meeting a diner with a password
/// box would break the one thing the product is for.
///
/// These run as a non-web build, which is what `flutter test` is, so they
/// exercise the installed-app side. The web side is guarded by `kIsWeb` and by
/// the deep-link tests, which reach the menu without signing in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStore> pump(WidgetTester tester, {String route = '/'}) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = route;
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    addTearDown(store.dispose);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const RestaurantApp(),
    ));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('the installed app opens on sign-in, not the menu',
      (tester) async {
    await pump(tester);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(QrEntryScreen), findsNothing);
  });

  testWidgets('a scanned table link still goes straight to the menu',
      (tester) async {
    // The whole product depends on this: a sticker must never lead to a login.
    final store =
        await pump(tester, route: '/order/${BackendConfig.slug}/table/05');

    expect(find.byType(SignInScreen), findsNothing,
        reason: 'a diner was asked to sign in');
    expect(store.activeTable?.number, '05');
    expect(store.isSignedIn, isFalse);
  });

  testWidgets('staff can step through to the customer view', (tester) async {
    final store = await pump(tester);
    expect(find.byType(SignInScreen), findsOneWidget);

    await tester.tap(find.text(store.text.browseAsCustomer));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsNothing);
    expect(find.byType(QrEntryScreen), findsOneWidget);
  });

  testWidgets('signing in lands on the workspace with nothing underneath',
      (tester) async {
    final store = await pump(tester);

    final pending = store.signInWithPassword(
        DemoData.adminUsername, DemoData.adminPassword);
    await tester.pumpAndSettle();
    expect(await pending, isTrue);
    store.setMode(AppMode.staff);
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a customer session already in progress is not interrupted',
      (tester) async {
    // Someone mid-order who backgrounds the app should come back to their
    // cart, not to a PIN pad. Seeded straight into storage: letting the store
    // write it would need a pump the fake clock never gets.
    SharedPreferences.setMockInitialValues({
      'rqo_session_v5': jsonEncode({
        'mode': 'customer',
        'orderType': 'TAKEAWAY',
        'language': 'en',
        'activeTableId': null,
        'cart': <dynamic>[],
        'cartNote': '',
        'sessionOrderIds': <dynamic>[],
      }),
    });
    final store = AppStore();
    await store.load();
    addTearDown(store.dispose);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const RestaurantApp(),
    ));
    await tester.pumpAndSettle();

    expect(store.hasCustomerSession, isTrue);
    expect(find.byType(SignInScreen), findsNothing);
  });
}

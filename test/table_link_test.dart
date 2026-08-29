import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/config/backend_config.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/models/restaurant_table.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What happens when a diner points a camera at a printed sticker.
///
/// The link on that sticker is the one thing in the app that cannot be fixed
/// with a new build: it is printed, laminated and stuck to a table. If the
/// route it encodes stops resolving, every table in the restaurant has to be
/// reprinted. So the shape of the link and the parsing of it are pinned here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStore> pumpApp(WidgetTester tester) async {
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

  Future<void> scan(WidgetTester tester, String route) async {
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.pushNamed(route));
    await tester.pumpAndSettle();
  }

  group('the route a printed sticker encodes', () {
    testWidgets('opens the table it names', (tester) async {
      final store = await pumpApp(tester);
      expect(store.activeTable, isNull, reason: 'nothing scanned yet');

      await scan(tester, '/order/${BackendConfig.slug}/table/05');

      expect(store.activeTable?.number, '05');
      expect(store.hasCustomerSession, isTrue);
    });

    testWidgets('accepts the older /restaurant/ form', (tester) async {
      final store = await pumpApp(tester);
      await scan(tester, '/restaurant/${BackendConfig.slug}/table/03');
      expect(store.activeTable?.number, '03');
    });

    testWidgets('pads a single-digit table the way the sticker may carry it',
        (tester) async {
      final store = await pumpApp(tester);
      await scan(tester, '/order/${BackendConfig.slug}/table/5');
      expect(store.activeTable?.number, '05');
    });

    testWidgets('a table that does not exist says so rather than guessing',
        (tester) async {
      final store = await pumpApp(tester);
      await scan(tester, '/order/${BackendConfig.slug}/table/99');
      expect(store.activeTable, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unrelated path lands on the app, not an error',
        (tester) async {
      await pumpApp(tester);
      await scan(tester, '/anything/else');
      expect(tester.takeException(), isNull);
    });
  });

  group('the link the QR code carries', () {
    test('puts the route in the fragment, where Flutter web reads it', () {
      // What tableLink() builds once PUBLIC_URL is set, spelled out so a
      // change to either half has to be deliberate.
      const host = 'https://ez-order.example.app';
      final link = '$host/#/order/${BackendConfig.slug}/table/05';

      final fragment = Uri.parse(link).fragment;
      expect(fragment, '/order/${BackendConfig.slug}/table/05');

      // And that fragment is exactly what the router is handed.
      final segments = Uri.parse(fragment).pathSegments;
      expect(segments, ['order', BackendConfig.slug, 'table', '05']);
    });

    test('with PUBLIC_URL compiled in, the link is absolute and scannable', () {
      // PUBLIC_URL is a compile-time constant, so this only has something to
      // check on a build that set one. It is the assertion that matters most
      // before a sticker is printed, so it runs in the release build's own
      // test pass:
      //   flutter test --dart-define=PUBLIC_URL=https://ez-order.vercel.app
      if (!BackendConfig.hasPublicUrl) return;

      final link = BackendConfig.tableLink('05');
      expect(link, startsWith('https://'),
          reason: 'a camera cannot act on a relative path');
      expect(Uri.parse(link).fragment, '/order/${BackendConfig.slug}/table/05');
    });

    test('a table builds the same path the router expects', () {
      // The sticker is printed from deepLinkPath and read by the router, so
      // the two have to agree without anybody remembering to keep them in step.
      const table = RestaurantTable(
        id: 'table-05',
        number: '05',
        name: 'Table 05',
        qrId: 'restaurant-demo-table-05',
      );

      final segments = Uri.parse(table.deepLinkPath).pathSegments;
      expect(segments, ['order', BackendConfig.slug, 'table', '05']);
    });
  });
}

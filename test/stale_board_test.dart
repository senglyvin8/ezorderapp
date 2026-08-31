import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_qr_ordering/app.dart';
import 'package:restaurant_qr_ordering/data/app_store.dart';
import 'package:restaurant_qr_ordering/data/backend/local_backend.dart';
import 'package:restaurant_qr_ordering/data/demo_data.dart';
import 'package:restaurant_qr_ordering/widgets/refresh_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Getting an order onto a board that has stopped listening.
///
/// Everything after the first load arrives over a websocket, and a websocket on
/// a phone in a kitchen does not stay up: it sleeps in a pocket, moves between
/// access points, and comes back without saying it went. The board then shows
/// an old shift while looking perfectly healthy, which is worse than showing
/// nothing — nobody doubts a board that looks fine.
class _RealBackend extends LocalBackend {
  int refreshes = 0;

  // Pretending to be a real backend is the point: the demo has nothing to
  // re-read, so the affordances hide themselves on it.
  @override
  bool get isDemo => false;

  @override
  Future<void> refresh() async => refreshes++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppStore, _RealBackend)> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final backend = _RealBackend();
    final store = AppStore(backend: backend);
    addTearDown(store.dispose);
    await store.load();

    final signingIn = store.signInWithPassword(
        DemoData.adminUsername, DemoData.adminPassword);
    await tester.pumpAndSettle();
    expect(await signingIn, isTrue);
    store.setMode(AppMode.staff);

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const RestaurantApp(),
    ));
    await tester.pumpAndSettle();
    return (store, backend);
  }

  testWidgets('coming back to the app re-reads the restaurant',
      (tester) async {
    final (_, backend) = await pump(tester);
    final before = backend.refreshes;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(backend.refreshes, greaterThan(before),
        reason: 'a phone that has been asleep has lost its socket');
  });

  testWidgets('and there is a button for when it still looks wrong',
      (tester) async {
    final (store, backend) = await pump(tester);
    // The owner's workspace opens on the dashboard. The button lives on the
    // boards, which is where orders are.
    await tester.tap(find.text(store.text.kitchen).last);
    await tester.pumpAndSettle();
    expect(find.byType(RefreshButton), findsWidgets);

    final before = backend.refreshes;
    await tester.tap(find.byType(RefreshButton).first);
    await tester.pumpAndSettle();
    expect(backend.refreshes, before + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the demo offers neither, having nothing to re-read',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(backend: LocalBackend());
    addTearDown(store.dispose);
    await store.load();
    final signingIn = store.signInWithPassword(
        DemoData.adminUsername, DemoData.adminPassword);
    await tester.pumpAndSettle();
    expect(await signingIn, isTrue);
    store.setMode(AppMode.staff);

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store, child: const RestaurantApp()));
    await tester.pumpAndSettle();

    // The widget is in the tree and draws nothing.
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });
}

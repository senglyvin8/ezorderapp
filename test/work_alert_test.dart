import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/widgets/work_alert.dart';

/// Two behaviours matter and both are easy to get backwards: it must go off
/// when work arrives, and it must stay quiet about work that was already there
/// when the screen opened. A board that alarms about four tickets that have sat
/// there all morning gets muted, and then the real one is missed.
void main() {
  Future<void> pump(WidgetTester tester, int count) async {
    await tester.pumpWidget(MaterialApp(
      home: WorkAlert(
        count: count,
        message: '$count waiting',
        child: const Scaffold(body: Center(child: Text('board'))),
      ),
    ));
  }

  testWidgets('says nothing about the tickets already on the board',
      (tester) async {
    await pump(tester, 4);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('4 waiting'), findsNothing,
        reason: 'opening on four waiting tickets is not an event');
  });

  testWidgets('announces a ticket that arrives', (tester) async {
    await pump(tester, 2);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2 waiting'), findsNothing);

    await pump(tester, 3);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('3 waiting'), findsOneWidget);
  });

  testWidgets('stays quiet when a ticket is taken off the board',
      (tester) async {
    await pump(tester, 3);
    await tester.pump(const Duration(milliseconds: 300));

    // A cook starting on something drops the queue. That is progress, not an
    // event to shout about.
    await pump(tester, 2);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2 waiting'), findsNothing);
  });

  testWidgets('can be dismissed by tapping it', (tester) async {
    await pump(tester, 0);
    await pump(tester, 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 waiting'), findsOneWidget);

    await tester.tap(find.text('1 waiting'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 waiting'), findsNothing);
  });

  testWidgets('clears itself so it cannot sit over the board all service',
      (tester) async {
    await pump(tester, 0);
    await pump(tester, 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 waiting'), findsOneWidget);

    await tester.pump(const Duration(seconds: 9));
    expect(find.text('1 waiting'), findsNothing);
  });

  testWidgets('never hides the board underneath it', (tester) async {
    await pump(tester, 0);
    await pump(tester, 1);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('board'), findsOneWidget,
        reason: 'the banner overlays, it does not replace');
  });
}

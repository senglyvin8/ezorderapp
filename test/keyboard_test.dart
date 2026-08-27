import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/widgets/app_chrome.dart';

/// A bottom sheet lifts itself by the keyboard's height. If it then asks for a
/// fraction of the *whole* screen it is taller than the room it has left, and
/// the overflow goes off the top — taking the field being typed into with it.
///
/// That is the bug this guards: on the web customer menu, tapping into
/// "Special request" made the text box disappear.
void main() {
  Future<double> measure(
    WidgetTester tester, {
    required double screenHeight,
    required double keyboard,
    double fraction = 0.9,
  }) async {
    late double result;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(400, screenHeight),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Builder(builder: (context) {
          result = sheetMaxHeight(context, fraction: fraction);
          return const SizedBox();
        }),
      ),
    ));
    return result;
  }

  group('a sheet sized around the keyboard', () {
    testWidgets('takes its share of the whole screen when nothing is covered',
        (tester) async {
      expect(await measure(tester, screenHeight: 800, keyboard: 0), 720);
    });

    testWidgets('leaves room for the keyboard rather than overflowing upward',
        (tester) async {
      // 336 = (800 - 427) * 0.9. The old code returned 720, which is taller
      // than the 373 points actually left, so 347 points of sheet — including
      // the text field — sat above the top of the screen.
      final height = await measure(tester, screenHeight: 800, keyboard: 427);
      expect(height, closeTo(335.7, 0.5));
      expect(height, lessThan(800 - 427),
          reason: 'must fit in the space the keyboard leaves');
    });

    testWidgets('never collapses to nothing on a short screen', (tester) async {
      // A small phone in landscape with a tall keyboard: the arithmetic says
      // almost zero, but a sheet you cannot see is worse than one that
      // scrolls.
      final height = await measure(tester, screenHeight: 360, keyboard: 320);
      expect(height, greaterThanOrEqualTo(220));
    });

    testWidgets('honours the fraction each sheet asks for', (tester) async {
      expect(
        await measure(tester, screenHeight: 1000, keyboard: 0, fraction: 0.8),
        800,
      );
    });
  });
}

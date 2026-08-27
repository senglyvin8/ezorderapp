import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/widgets/app_chrome.dart';

/// [PageWidth] wraps almost every screen body *and* the sticky bars at the
/// bottom of the cart and the menu. If it ever stops shrink-wrapping its
/// height, a bar built with it expands to the full screen and the body above
/// it collapses to nothing — visible as a blank page, with no exception to
/// point at it. These two tests pin both halves of that behaviour.
void main() {
  testWidgets('shrink-wraps its height inside a bottom bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: const [Text('BODY')]),
          bottomNavigationBar: PageWidth(
            maxWidth: 640,
            child: FilledButton(onPressed: () {}, child: const Text('SUBMIT')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.getSize(find.byType(PageWidth));
    final body = tester.getSize(find.byType(ListView));

    expect(bar.height, lessThan(120),
        reason: 'the bottom bar must hug its button');
    expect(body.height, greaterThan(300),
        reason: 'the body must keep the rest of the screen');
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('still lets a scrolling child fill the page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageWidth(
            maxWidth: 640,
            child: ListView(
              children: List.generate(30, (i) => Text('row $i')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(ListView)).height, greaterThan(400));
    expect(find.text('row 0'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kantumruy Pro is the app's only typeface, so it has to carry both scripts
/// and render real weight variation from its single variable file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('KantumruyPro')
      ..addFont(rootBundle.load('assets/fonts/KantumruyPro.ttf'));
    await loader.load();
  });

  Future<double> widthOf(
    WidgetTester tester,
    String text,
    FontWeight weight,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'KantumruyPro',
              fontSize: 24,
              fontWeight: weight,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.byType(Text)).width;
  }

  testWidgets('renders distinct weights', (tester) async {
    final regular = await widthOf(tester, 'Chicken Fried Rice', FontWeight.w400);
    final bold = await widthOf(tester, 'Chicken Fried Rice', FontWeight.w700);
    debugPrint('LATIN w400=$regular w700=$bold');
    expect(bold, greaterThan(regular));
  });

  testWidgets('covers Latin and Khmer', (tester) async {
    final latin = await widthOf(tester, 'Chicken Fried Rice', FontWeight.w400);
    final khmer = await widthOf(tester, 'បាយឆាសាច់មាន់', FontWeight.w400);
    final digits = await widthOf(tester, '0123456789', FontWeight.w400);
    debugPrint('latin=$latin khmer=$khmer digits=$digits');

    // A missing glyph collapses to a uniform fallback box; real Khmer
    // shaping produces a width unrelated to a simple character count.
    expect(latin, greaterThan(0));
    expect(khmer, greaterThan(0));
    expect(digits, greaterThan(0));
    expect(khmer, isNot(closeTo(24.0 * 13, 1))); // not .notdef squares
  });
}

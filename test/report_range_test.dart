import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/models/date_range.dart';

/// Date arithmetic is where reports quietly lie, so the edges are pinned here:
/// the first moment of a day, the last, week boundaries, and a custom range's
/// closing day being included rather than cut off at midnight.
void main() {
  // A Wednesday, so "this week" has days on both sides of it.
  final now = DateTime(2026, 8, 26, 14, 30);

  DateTime at(int day, [int hour = 12]) => DateTime(2026, 8, day, hour);

  group('today', () {
    const range = ReportRange.today();

    test('includes the first moment of today', () {
      expect(range.contains(DateTime(2026, 8, 26), now: now), isTrue);
    });

    test('includes an order placed a minute ago', () {
      expect(range.contains(at(26, 14), now: now), isTrue);
    });

    test('excludes last night', () {
      expect(range.contains(DateTime(2026, 8, 25, 23, 59), now: now), isFalse);
    });

    test('rolls over at midnight rather than freezing', () {
      // The same order, read on the following day, is no longer "today" —
      // which is what a board left running overnight depends on.
      final tomorrow = DateTime(2026, 8, 27, 9);
      expect(range.contains(at(26), now: now), isTrue);
      expect(range.contains(at(26), now: tomorrow), isFalse);
    });
  });

  group('this week', () {
    const range = ReportRange(ReportPreset.week);

    test('starts on Monday', () {
      // 24 August 2026 is the Monday of this week.
      expect(DateTime(2026, 8, 24).weekday, DateTime.monday);
      expect(range.contains(DateTime(2026, 8, 24), now: now), isTrue);
    });

    test('excludes the Sunday before', () {
      expect(range.contains(at(23), now: now), isFalse);
    });

    test('includes today', () {
      expect(range.contains(at(26), now: now), isTrue);
    });
  });

  group('this month', () {
    const range = ReportRange(ReportPreset.month);

    test('starts on the first', () {
      expect(range.contains(DateTime(2026, 8, 1), now: now), isTrue);
    });

    test('excludes the end of last month', () {
      expect(range.contains(DateTime(2026, 7, 31, 23, 59), now: now), isFalse);
    });
  });

  group('all', () {
    test('takes everything, however old', () {
      const range = ReportRange(ReportPreset.all);
      expect(range.contains(DateTime(2019, 1, 1), now: now), isTrue);
      expect(range.contains(at(26), now: now), isTrue);
    });
  });

  group('a custom range', () {
    final range = ReportRange(
      ReportPreset.custom,
      from: DateTime(2026, 8, 10),
      to: DateTime(2026, 8, 14),
    );

    test('includes the whole opening day', () {
      expect(range.contains(DateTime(2026, 8, 10), now: now), isTrue);
    });

    test('includes the whole closing day, not just its first moment', () {
      // The mistake worth guarding: a range "to the 14th" that stops at
      // midnight on the 14th silently drops that entire day's takings.
      expect(range.contains(DateTime(2026, 8, 14, 23, 59), now: now), isTrue);
    });

    test('excludes the day before and the day after', () {
      expect(range.contains(at(9), now: now), isFalse);
      expect(range.contains(at(15), now: now), isFalse);
    });

    test('is not treated as complete until both ends are given', () {
      const half = ReportRange(ReportPreset.custom);
      expect(half.isComplete, isFalse);
      expect(range.isComplete, isTrue);
      expect(const ReportRange.today().isComplete, isTrue);
    });
  });

  group('surviving a reload', () {
    test('a preset round trips', () {
      const range = ReportRange(ReportPreset.month);
      expect(ReportRange.fromJson(range.toJson()).preset, ReportPreset.month);
    });

    test('a custom range keeps both ends', () {
      final range = ReportRange(
        ReportPreset.custom,
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 14),
      );
      final back = ReportRange.fromJson(range.toJson());
      expect(back.preset, ReportPreset.custom);
      expect(back.from, DateTime(2026, 8, 10));
      expect(back.to, DateTime(2026, 8, 14));
    });
  });
}

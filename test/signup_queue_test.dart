import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/platform/signup_queue.dart';

/// Reading an application off the wire.
///
/// The console decides whether a restaurant joins from what these rows say, so
/// a field silently arriving null and becoming an empty card is worse than an
/// error — an operator would approve something they could not actually read.
void main() {
  Map<String, dynamic> row({
    String? status = 'PENDING',
    String? note,
    String? reviewedAt,
    String? createdAt,
  }) =>
      {
        'id': 'req-1',
        'email': 'me@myshop.com',
        'restaurant_name': "Sengly's Kitchen",
        'slug': 'senglys-kitchen',
        'owner_name': 'Sengly',
        'status': status,
        'note': note,
        'created_at': createdAt ?? '2026-08-29T10:00:00Z',
        'reviewed_at': reviewedAt,
      };

  test('a waiting application reads back whole', () {
    final a = SignUpApplication.fromRow(row());
    expect(a.restaurantName, "Sengly's Kitchen");
    expect(a.slug, 'senglys-kitchen');
    expect(a.ownerName, 'Sengly');
    expect(a.email, 'me@myshop.com');
    expect(a.status, ApplicationStatus.pending);
    expect(a.status.isOpen, isTrue);
    expect(a.reviewedAt, isNull);
  });

  test('an answered one carries when and why', () {
    final a = SignUpApplication.fromRow(row(
      status: 'REJECTED',
      note: 'We could not find this restaurant.',
      reviewedAt: '2026-08-30T09:00:00Z',
    ));
    expect(a.status, ApplicationStatus.rejected);
    expect(a.status.isOpen, isFalse);
    expect(a.note, 'We could not find this restaurant.');
    expect(a.reviewedAt, isNotNull);
  });

  test('an unknown status is treated as still waiting', () {
    // Better to show an operator something to answer than to hide a row
    // because a later migration added a state this build has not heard of.
    expect(SignUpApplication.fromRow(row(status: 'SOMETHING_NEW')).status,
        ApplicationStatus.pending);
    expect(SignUpApplication.fromRow(row(status: null)).status,
        ApplicationStatus.pending);
  });

  test('missing text arrives empty rather than throwing', () {
    final a = SignUpApplication.fromRow({
      'id': 'req-2',
      'status': 'PENDING',
      'created_at': '2026-08-29T10:00:00Z',
    });
    expect(a.email, '');
    expect(a.ownerName, '');
    expect(a.note, '');
  });

  test('an unparseable date does not take the queue down with it', () {
    final a = SignUpApplication.fromRow(row(createdAt: 'not-a-date'));
    expect(a.askedAt, isNotNull);
    expect(a.waited.isNegative, isFalse);
  });

  test('how long somebody has been waiting', () {
    final a = SignUpApplication.fromRow(row(
      createdAt: DateTime.now()
          .subtract(const Duration(hours: 30))
          .toIso8601String(),
    ));
    expect(a.waited.inHours, greaterThanOrEqualTo(29));
  });
}

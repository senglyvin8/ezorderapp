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

  group('splitting the queue by what is still to do', () {
    // Waiting is a job; approved and turned down are a record. An operator
    // should be shown the job, not have to find it among the record.
    final queue = [
      SignUpApplication.fromRow(row(status: 'PENDING')),
      SignUpApplication.fromRow(row(status: 'APPROVED', reviewedAt: '2026-08-30T09:00:00Z')),
      SignUpApplication.fromRow(row(status: 'REJECTED', note: 'Not a real address', reviewedAt: '2026-08-30T09:00:00Z')),
      SignUpApplication.fromRow(row(status: 'PENDING')),
    ];

    test('only the waiting ones are a job', () {
      expect(queue.where((a) => a.status.isOpen).length, 2);
      expect(queue.where((a) => !a.status.isOpen).length, 2);
    });

    test('an answered one carries when, and a refusal carries why', () {
      final refused =
          queue.firstWhere((a) => a.status == ApplicationStatus.rejected);
      expect(refused.reviewedAt, isNotNull);
      expect(refused.note, 'Not a real address');

      final approved =
          queue.firstWhere((a) => a.status == ApplicationStatus.approved);
      expect(approved.reviewedAt, isNotNull);
      expect(approved.note, isEmpty, reason: 'nothing to explain about a yes');
    });

    test('every field the requester typed survives the trip', () {
      // The card is the whole basis for the decision: there is nowhere else to
      // look and no way to ask them a question.
      final a = queue.first;
      for (final value in [a.restaurantName, a.slug, a.ownerName, a.email]) {
        expect(value, isNotEmpty);
      }
      expect(a.askedAt, isNotNull);
    });
  });
}

/// How far an application to join has got.
enum ApplicationStatus {
  pending('PENDING', 'Waiting'),
  approved('APPROVED', 'Approved'),
  rejected('REJECTED', 'Rejected');

  const ApplicationStatus(this.wire, this.label);
  final String wire;
  final String label;

  static ApplicationStatus fromWire(String? value) =>
      ApplicationStatus.values.firstWhere((s) => s.wire == value,
          orElse: () => ApplicationStatus.pending);

  bool get isOpen => this == ApplicationStatus.pending;
}

/// A restaurant asking to join, as the operator sees it.
///
/// Everything needed to decide, on the card, without opening anything: who
/// they are, what they want the place called, and the address that will end up
/// on their printed QR codes. The last one is the only part that cannot be
/// changed afterwards, so it is the part worth reading before saying yes.
class SignUpApplication {
  const SignUpApplication({
    required this.id,
    required this.email,
    required this.restaurantName,
    required this.slug,
    required this.ownerName,
    required this.status,
    required this.askedAt,
    this.note = '',
    this.reviewedAt,
  });

  final String id;
  final String email;
  final String restaurantName;
  final String slug;
  final String ownerName;
  final ApplicationStatus status;
  final DateTime askedAt;

  /// The reason given for turning it down. The applicant sees this, so it is
  /// written for them rather than as a private note.
  final String note;

  final DateTime? reviewedAt;

  /// How long they have been waiting, for the queue to sort the longest wait
  /// to the top of an operator's attention.
  Duration get waited => DateTime.now().difference(askedAt);

  factory SignUpApplication.fromRow(Map<String, dynamic> r) =>
      SignUpApplication(
        id: r['id'] as String,
        email: r['email'] as String? ?? '',
        restaurantName: r['restaurant_name'] as String? ?? '',
        slug: r['slug'] as String? ?? '',
        ownerName: r['owner_name'] as String? ?? '',
        status: ApplicationStatus.fromWire(r['status'] as String?),
        note: r['note'] as String? ?? '',
        askedAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
            DateTime.now(),
        reviewedAt: r['reviewed_at'] == null
            ? null
            : DateTime.tryParse(r['reviewed_at'] as String),
      );
}

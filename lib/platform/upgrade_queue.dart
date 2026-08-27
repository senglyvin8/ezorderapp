import '../models/plan.dart';
import '../models/upgrade_request.dart';

/// A merchant's upgrade request, as the operator sees it.
///
/// Deliberately not the same class the restaurant app uses. That one is "my
/// request"; this one carries whose it is, which is the whole difference
/// between a status card and a queue.
class UpgradeTicket {
  const UpgradeTicket({
    required this.id,
    required this.restaurantId,
    required this.merchant,
    required this.slug,
    required this.logo,
    required this.merchantPhone,
    required this.fromPlan,
    required this.toPlan,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.contactName = '',
    this.contactPhone = '',
    this.note = '',
    this.handledAt,
  });

  final String id;
  final String restaurantId;
  final String merchant;
  final String slug;
  final String logo;

  /// The shop's own number, from the restaurant record. [contactPhone] is what
  /// the owner asked to be called on and wins when they differ.
  final String merchantPhone;

  final Plan fromPlan;
  final Plan toPlan;
  final UpgradeReason reason;
  final UpgradeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String contactName;
  final String contactPhone;
  final String note;
  final DateTime? handledAt;

  bool get isOpen => status.isOpen;

  /// The number to actually dial.
  String get phone =>
      contactPhone.trim().isNotEmpty ? contactPhone.trim() : merchantPhone;

  /// How long they have been waiting. The queue is ordered by this, not by how
  /// much they would pay.
  Duration age(DateTime now) => now.difference(createdAt);

  /// What the money changes by if you say yes. Negative on a downgrade, which
  /// is a request worth reading rather than granting on autopilot.
  double get monthlyDelta => toPlan.monthlyPrice - fromPlan.monthlyPrice;

  factory UpgradeTicket.fromRow(Map<String, dynamic> row) => UpgradeTicket(
        id: row['id'] as String,
        restaurantId: row['restaurant_id'] as String,
        merchant: row['merchant'] as String? ?? '',
        slug: row['slug'] as String? ?? '',
        logo: row['logo'] as String? ?? '🍽️',
        merchantPhone: row['merchant_phone'] as String? ?? '',
        fromPlan: Plan.fromWire(row['from_plan'] as String?),
        toPlan: Plan.fromWire(row['to_plan'] as String?),
        reason: UpgradeReason.fromWire(row['reason'] as String?),
        status: UpgradeStatus.fromWire(row['status'] as String?),
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
        contactName: row['contact_name'] as String? ?? '',
        contactPhone: row['contact_phone'] as String? ?? '',
        note: row['note'] as String? ?? '',
        handledAt: row['handled_at'] == null
            ? null
            : DateTime.parse(row['handled_at'] as String).toLocal(),
      );
}

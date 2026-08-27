import 'plan.dart';

/// What the merchant was doing when they asked for a bigger plan.
///
/// Worth recording separately from the plan they want: "hit the staff cap" and
/// "was reading the pricing screen" are different conversations, and the first
/// one is a merchant who is blocked right now.
enum UpgradeReason {
  staffCap('STAFF_CAP'),
  tableCap('TABLE_CAP'),
  manual('MANUAL');

  const UpgradeReason(this.wire);

  final String wire;

  static UpgradeReason fromWire(String? value) => UpgradeReason.values
      .firstWhere((r) => r.wire == value, orElse: () => UpgradeReason.manual);
}

/// Where a request has got to.
///
/// [pending] and [contacted] are both open — the merchant is still waiting on
/// you — which is why the app treats them the same and only the console tells
/// them apart.
enum UpgradeStatus {
  pending('NEW'),
  contacted('CONTACTED'),
  done('DONE'),
  declined('DECLINED');

  const UpgradeStatus(this.wire);

  final String wire;

  bool get isOpen => this == pending || this == contacted;

  static UpgradeStatus fromWire(String? value) => UpgradeStatus.values
      .firstWhere((s) => s.wire == value, orElse: () => UpgradeStatus.pending);
}

/// A merchant asking to be moved onto a bigger plan.
///
/// There is no payment processing, so this is the whole of "upgrading": the
/// merchant asks, you see it in the console, you change their plan and call
/// them. When billing exists this row becomes the audit trail rather than the
/// mechanism.
class UpgradeRequest {
  const UpgradeRequest({
    required this.id,
    required this.fromPlan,
    required this.toPlan,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.contactName = '',
    this.contactPhone = '',
    this.note = '',
    this.handledAt,
  });

  final String id;
  final Plan fromPlan;
  final Plan toPlan;
  final UpgradeReason reason;
  final UpgradeStatus status;
  final DateTime createdAt;

  /// Who to call. Seeded from the restaurant's own phone number, because the
  /// merchant should not have to type what you already know.
  final String contactName;
  final String contactPhone;
  final String note;
  final DateTime? handledAt;

  bool get isOpen => status.isOpen;

  UpgradeRequest copyWith({
    Plan? toPlan,
    UpgradeReason? reason,
    UpgradeStatus? status,
    String? contactName,
    String? contactPhone,
    String? note,
    DateTime? handledAt,
  }) =>
      UpgradeRequest(
        id: id,
        fromPlan: fromPlan,
        toPlan: toPlan ?? this.toPlan,
        reason: reason ?? this.reason,
        status: status ?? this.status,
        createdAt: createdAt,
        contactName: contactName ?? this.contactName,
        contactPhone: contactPhone ?? this.contactPhone,
        note: note ?? this.note,
        handledAt: handledAt ?? this.handledAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromPlan': fromPlan.wire,
        'toPlan': toPlan.wire,
        'reason': reason.wire,
        'status': status.wire,
        'createdAt': createdAt.toIso8601String(),
        'contactName': contactName,
        'contactPhone': contactPhone,
        'note': note,
        if (handledAt != null) 'handledAt': handledAt!.toIso8601String(),
      };

  factory UpgradeRequest.fromJson(Map<String, dynamic> json) => UpgradeRequest(
        id: json['id'] as String,
        fromPlan: Plan.fromWire(json['fromPlan'] as String?),
        toPlan: Plan.fromWire(json['toPlan'] as String?),
        reason: UpgradeReason.fromWire(json['reason'] as String?),
        status: UpgradeStatus.fromWire(json['status'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
        contactName: json['contactName'] as String? ?? '',
        contactPhone: json['contactPhone'] as String? ?? '',
        note: json['note'] as String? ?? '',
        handledAt: json['handledAt'] == null
            ? null
            : DateTime.parse(json['handledAt'] as String),
      );

  /// A row from `upgrade_requests`, which is snake_case and stores plans as
  /// their wire names.
  factory UpgradeRequest.fromRow(Map<String, dynamic> row) => UpgradeRequest(
        id: row['id'] as String,
        fromPlan: Plan.fromWire(row['from_plan'] as String?),
        toPlan: Plan.fromWire(row['to_plan'] as String?),
        reason: UpgradeReason.fromWire(row['reason'] as String?),
        status: UpgradeStatus.fromWire(row['status'] as String?),
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        contactName: row['contact_name'] as String? ?? '',
        contactPhone: row['contact_phone'] as String? ?? '',
        note: row['note'] as String? ?? '',
        handledAt: row['handled_at'] == null
            ? null
            : DateTime.parse(row['handled_at'] as String).toLocal(),
      );
}

/// How a merchant reaches you.
///
/// Held in the database on a live build (`platform_settings`) rather than
/// compiled in, so changing your Telegram handle does not need an app release.
/// The compile-time values in [Support] are the fallback and what the demo
/// shows.
class SupportContact {
  const SupportContact({
    required this.phone,
    required this.telegram,
    required this.hours,
  });

  final String phone;

  /// Full `https://t.me/...` link, not a bare handle — it goes straight into
  /// a launcher.
  final String telegram;
  final String hours;

  bool get hasPhone => phone.trim().isNotEmpty;
  bool get hasTelegram => telegram.trim().isNotEmpty;

  factory SupportContact.fromRow(Map<String, dynamic> row) => SupportContact(
        phone: row['support_phone'] as String? ?? '',
        telegram: row['support_telegram'] as String? ?? '',
        hours: row['support_hours'] as String? ?? '',
      );
}

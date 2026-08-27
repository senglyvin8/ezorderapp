import '../models/plan.dart';

/// One restaurant, as the platform operator sees it.
///
/// Counts and totals only — deliberately no orders, items or customer notes.
/// Running the service does not require reading what a particular diner ate,
/// and `platform_overview()` will not return it even if this class asked.
class Merchant {
  const Merchant({
    required this.id,
    required this.slug,
    required this.name,
    required this.plan,
    required this.suspended,
    required this.createdAt,
    required this.tablesUsed,
    required this.staffUsed,
    required this.ordersTotal,
    required this.ordersToday,
    required this.revenueTotal,
    required this.revenueToday,
    this.lastOrderAt,
  });

  final String id;
  final String slug;
  final String name;
  final Plan plan;
  final bool suspended;
  final DateTime createdAt;

  final int tablesUsed;
  final int staffUsed;
  final int ordersTotal;
  final int ordersToday;
  final double revenueTotal;
  final double revenueToday;

  /// Null for a merchant that has never taken an order — which is the signal
  /// worth noticing: somebody signed up and never got started.
  final DateTime? lastOrderAt;

  bool get hasEverOrdered => ordersTotal > 0;

  /// True when they are pressed against a cap and would benefit from moving
  /// up. The reason to look at this list at all.
  bool get atTableLimit =>
      plan.maxTables != null && tablesUsed >= plan.maxTables!;
  bool get atStaffLimit =>
      plan.maxStaff != null && staffUsed >= plan.maxStaff!;
  bool get atAnyLimit => atTableLimit || atStaffLimit;

  static double _toDouble(Object? v) => switch (v) {
        num n => n.toDouble(),
        String s => double.tryParse(s) ?? 0,
        _ => 0,
      };

  factory Merchant.fromRow(Map<String, dynamic> r) => Merchant(
        id: r['id'] as String,
        slug: r['slug'] as String,
        name: r['name'] as String,
        plan: Plan.fromWire(r['plan'] as String?),
        suspended: r['suspended'] as bool? ?? false,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        tablesUsed: (r['tables_used'] as num?)?.toInt() ?? 0,
        staffUsed: (r['staff_used'] as num?)?.toInt() ?? 0,
        ordersTotal: (r['orders_total'] as num?)?.toInt() ?? 0,
        ordersToday: (r['orders_today'] as num?)?.toInt() ?? 0,
        revenueTotal: _toDouble(r['revenue_total']),
        revenueToday: _toDouble(r['revenue_today']),
        lastOrderAt: r['last_order_at'] == null
            ? null
            : DateTime.parse(r['last_order_at'] as String).toLocal(),
      );
}

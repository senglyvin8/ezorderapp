import '../models/plan.dart';

/// How a merchant is doing, in one word.
///
/// The point of the console is triage — which of these needs you today — so
/// the state is computed once here rather than being re-derived by eye from a
/// row of numbers.
enum MerchantHealth {
  /// Frozen by you. Nothing else about them matters until that changes.
  suspended,

  /// Cannot take an order at all: no menu, or no tables. They signed up and
  /// stopped, and probably do not know why nothing works.
  notSetUp,

  /// Set up properly and still never took an order. Onboarding worked;
  /// adoption did not.
  neverOrdered,

  /// Took orders once and has gone quiet. This is what churn looks like a
  /// fortnight before it happens.
  quiet,

  /// Taking orders.
  active,
}

class Merchant {
  const Merchant({
    required this.id,
    required this.slug,
    required this.name,
    required this.logo,
    required this.phone,
    required this.address,
    required this.plan,
    required this.suspended,
    required this.createdAt,
    required this.tablesUsed,
    required this.staffUsed,
    required this.categories,
    required this.menuItems,
    required this.ordersTotal,
    required this.ordersToday,
    required this.orders7d,
    required this.ordersPrev7d,
    required this.revenueTotal,
    required this.revenueToday,
    required this.revenue30d,
    required this.ownerUsername,
    this.lastOrderAt,
  });

  final String id;
  final String slug;
  final String name;
  final String logo;
  final String phone;
  final String address;
  final Plan plan;
  final bool suspended;
  final DateTime createdAt;

  final int tablesUsed;
  final int staffUsed;
  final int categories;
  final int menuItems;

  final int ordersTotal;
  final int ordersToday;
  final int orders7d;
  final int ordersPrev7d;

  final double revenueTotal;
  final double revenueToday;
  final double revenue30d;

  final String ownerUsername;
  final DateTime? lastOrderAt;

  // ------------------------------------------------------------------ state

  /// A restaurant needs somewhere to sit and something to sell before a QR
  /// code does anything at all.
  bool get isSetUp => menuItems > 0 && tablesUsed > 0;

  bool get hasEverOrdered => ordersTotal > 0;

  int get daysSinceLastOrder => lastOrderAt == null
      ? -1
      : DateTime.now().difference(lastOrderAt!).inDays;

  int get daysSinceSignUp => DateTime.now().difference(createdAt).inDays;

  MerchantHealth get health {
    if (suspended) return MerchantHealth.suspended;
    if (!isSetUp) return MerchantHealth.notSetUp;
    if (!hasEverOrdered) return MerchantHealth.neverOrdered;
    if (daysSinceLastOrder >= 7) return MerchantHealth.quiet;
    return MerchantHealth.active;
  }

  /// True when somebody should look at this one. Drives the default filter —
  /// a list of forty healthy restaurants is not worth reading.
  bool get needsAttention =>
      health != MerchantHealth.active || atAnyLimit;

  /// What is missing, for a merchant that cannot yet trade. Phrased as the
  /// thing to tell them, not as a field name.
  List<String> get setupGaps => [
        if (categories == 0) 'no menu categories',
        if (menuItems == 0) 'no dishes',
        if (tablesUsed == 0) 'no tables or QR codes',
      ];

  // ------------------------------------------------------------- commercial

  bool get atTableLimit =>
      plan.maxTables != null && tablesUsed >= plan.maxTables!;
  bool get atStaffLimit =>
      plan.maxStaff != null && staffUsed >= plan.maxStaff!;
  bool get atAnyLimit => atTableLimit || atStaffLimit;

  /// Change in orders week on week, as a fraction. Null when there is nothing
  /// to compare against — a first week has no trend, and pretending otherwise
  /// gives every new merchant a spurious +100%.
  double? get weeklyTrend {
    if (ordersPrev7d == 0) return null;
    return (orders7d - ordersPrev7d) / ordersPrev7d;
  }

  static double _toDouble(Object? v) => switch (v) {
        num n => n.toDouble(),
        String s => double.tryParse(s) ?? 0,
        _ => 0,
      };

  static int _toInt(Object? v) => (v as num?)?.toInt() ?? 0;

  factory Merchant.fromRow(Map<String, dynamic> r) => Merchant(
        id: r['id'] as String,
        slug: r['slug'] as String,
        name: r['name'] as String,
        logo: (r['logo'] as String?)?.trim().isNotEmpty == true
            ? r['logo'] as String
            : '🍽️',
        phone: r['phone'] as String? ?? '',
        address: r['address'] as String? ?? '',
        plan: Plan.fromWire(r['plan'] as String?),
        suspended: r['suspended'] as bool? ?? false,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        tablesUsed: _toInt(r['tables_used']),
        staffUsed: _toInt(r['staff_used']),
        categories: _toInt(r['categories']),
        menuItems: _toInt(r['menu_items']),
        ordersTotal: _toInt(r['orders_total']),
        ordersToday: _toInt(r['orders_today']),
        orders7d: _toInt(r['orders_7d']),
        ordersPrev7d: _toInt(r['orders_prev_7d']),
        revenueTotal: _toDouble(r['revenue_total']),
        revenueToday: _toDouble(r['revenue_today']),
        revenue30d: _toDouble(r['revenue_30d']),
        ownerUsername: r['owner_username'] as String? ?? '',
        lastOrderAt: r['last_order_at'] == null
            ? null
            : DateTime.parse(r['last_order_at'] as String).toLocal(),
      );
}

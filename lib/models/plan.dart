/// What a restaurant is paying for, and what that entitles them to.
///
/// The numbers here are duplicated in `supabase/migrations/0006_plans.sql`,
/// and the database is the one that decides. This copy exists so the app can
/// grey out a button and show usage before anyone taps anything — never so it
/// can be the thing that says no.
///
/// `null` means unlimited. It is deliberately not a large number: a limit of
/// 999 is a limit somebody eventually hits and cannot explain.
enum Plan {
  free('FREE', 'Free', 0, maxTables: 5, maxStaff: 2),
  basic('BASIC', 'Basic', 5.99, maxTables: 20, maxStaff: 5),
  pro('PRO', 'Pro', 9.99, maxTables: null, maxStaff: 10);

  const Plan(
    this.wire,
    this.label,
    this.monthlyPrice, {
    required this.maxTables,
    required this.maxStaff,
  });

  /// Value stored in the database.
  final String wire;
  final String label;

  /// US dollars per month. Free is 0, not null — it is a price, just a low one.
  final double monthlyPrice;

  /// Null means unlimited.
  final int? maxTables;
  final int? maxStaff;

  static Plan fromWire(String? value) => Plan.values
      .firstWhere((p) => p.wire == value, orElse: () => Plan.free);

  /// Orders are unlimited on every plan. Charging a restaurant per order would
  /// punish them for a good night, which is the opposite of what this is for.
  bool get hasUnlimitedTables => maxTables == null;
  bool get hasUnlimitedStaff => maxStaff == null;

  bool canAddTable(int current) => maxTables == null || current < maxTables!;
  bool canAddStaff(int current) => maxStaff == null || current < maxStaff!;

  /// The next plan up, or null at the top.
  Plan? get next => switch (this) {
        Plan.free => Plan.basic,
        Plan.basic => Plan.pro,
        Plan.pro => null,
      };
}

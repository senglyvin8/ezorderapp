/// A window of time the report is about.
///
/// Stored as a preset plus an optional pair of dates rather than as two
/// timestamps, because "this week" has to keep meaning *this* week when the
/// screen is still open past midnight, and a pair of fixed instants would
/// quietly become last week.
enum ReportPreset {
  today('TODAY'),
  week('WEEK'),
  month('MONTH'),
  all('ALL'),
  custom('CUSTOM');

  const ReportPreset(this.wire);
  final String wire;

  static ReportPreset fromWire(String value) =>
      ReportPreset.values.firstWhere((p) => p.wire == value,
          orElse: () => ReportPreset.today);
}

class ReportRange {
  const ReportRange(this.preset, {this.from, this.to});

  const ReportRange.today() : this(ReportPreset.today);

  final ReportPreset preset;

  /// Only meaningful for [ReportPreset.custom]. Both are whole days: [from] is
  /// included from its first moment, [to] up to its last.
  final DateTime? from;
  final DateTime? to;

  /// Resolved against [now] every time it is read, so a board left open
  /// overnight rolls into the new day rather than freezing on the old one.
  bool contains(DateTime when, {DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    return switch (preset) {
      ReportPreset.today => !when.isBefore(today),
      // Monday to now. weekday is 1 for Monday, so this lands on the Monday of
      // the current week whatever day it is read.
      ReportPreset.week =>
        !when.isBefore(today.subtract(Duration(days: today.weekday - 1))),
      ReportPreset.month =>
        !when.isBefore(DateTime(today.year, today.month)),
      ReportPreset.all => true,
      ReportPreset.custom => _withinCustom(when),
    };
  }

  bool _withinCustom(DateTime when) {
    final start = from == null ? null : _startOfDay(from!);
    // The last moment of the closing day, not its first — a report "to the
    // 14th" that stopped at midnight on the 14th would omit the whole day.
    final end = to == null ? null : _startOfDay(to!).add(const Duration(days: 1));
    if (start != null && when.isBefore(start)) return false;
    if (end != null && !when.isBefore(end)) return false;
    return true;
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  ReportRange copyWith({ReportPreset? preset, DateTime? from, DateTime? to}) =>
      ReportRange(preset ?? this.preset,
          from: from ?? this.from, to: to ?? this.to);

  /// True when a custom range has been given both ends. A half-finished
  /// custom range should not be treated as "everything".
  bool get isComplete =>
      preset != ReportPreset.custom || (from != null && to != null);

  Map<String, dynamic> toJson() => {
        'preset': preset.wire,
        if (from != null) 'from': from!.toIso8601String(),
        if (to != null) 'to': to!.toIso8601String(),
      };

  factory ReportRange.fromJson(Map<String, dynamic> json) => ReportRange(
        ReportPreset.fromWire(json['preset'] as String? ?? 'TODAY'),
        from: json['from'] == null
            ? null
            : DateTime.parse(json['from'] as String),
        to: json['to'] == null ? null : DateTime.parse(json['to'] as String),
      );
}

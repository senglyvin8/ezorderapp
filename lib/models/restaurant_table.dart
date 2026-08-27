import '../config/app_config.dart';

/// A physical table. Rule 2 — every table carries a unique QR identifier.
class RestaurantTable {
  const RestaurantTable({
    required this.id,
    required this.number,
    required this.name,
    required this.qrId,
  });

  final String id;

  /// Zero padded table number, e.g. `05`.
  final String number;

  /// Display name, e.g. `Table 05`.
  final String name;

  /// Unique QR identifier, e.g. `restaurant-demo-table-05`, where `demo` is
  /// [Brand.slug].
  final String qrId;

  /// The path the QR code encodes, e.g. `/order/demo/table/05`.
  String get deepLinkPath => '/order/${Brand.slug}/table/$number';

  /// The QR identifier a table with [number] should carry. One place, so
  /// changing [Brand.slug] moves the seed tables, tables added later and the
  /// scanner together.
  static String qrIdFor(String number) =>
      'restaurant-${Brand.slug}-table-$number';

  RestaurantTable copyWith({String? number, String? name, String? qrId}) =>
      RestaurantTable(
        id: id,
        number: number ?? this.number,
        name: name ?? this.name,
        qrId: qrId ?? this.qrId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'name': name,
        'qrId': qrId,
      };

  factory RestaurantTable.fromJson(Map<String, dynamic> json) =>
      RestaurantTable(
        id: json['id'] as String,
        number: json['number'] as String,
        name: json['name'] as String,
        qrId: json['qrId'] as String,
      );
}

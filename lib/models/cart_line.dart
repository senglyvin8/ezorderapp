import '../l10n/app_text.dart';

/// A line in the customer's in-progress cart, before the order is submitted.
class CartLine {
  const CartLine({
    required this.id,
    required this.foodId,
    required this.name,
    required this.price,
    required this.quantity,
    this.nameKm = '',
    this.note,
  });

  final String id;
  final String foodId;
  final String name;
  final String nameKm;
  final double price;
  final int quantity;
  final String? note;

  double get lineTotal => price * quantity;

  String displayName(AppLanguage lang) =>
      lang == AppLanguage.km && nameKm.trim().isNotEmpty ? nameKm : name;

  CartLine copyWith({int? quantity, String? note, bool clearNote = false}) =>
      CartLine(
        id: id,
        foodId: foodId,
        name: name,
        nameKm: nameKm,
        price: price,
        quantity: quantity ?? this.quantity,
        note: clearNote ? null : (note ?? this.note),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'foodId': foodId,
        'name': name,
        if (nameKm.isNotEmpty) 'nameKm': nameKm,
        'price': price,
        'quantity': quantity,
        if (note != null) 'note': note,
      };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        id: json['id'] as String,
        foodId: json['foodId'] as String,
        name: json['name'] as String,
        nameKm: json['nameKm'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        quantity: (json['quantity'] as num).toInt(),
        note: json['note'] as String?,
      );
}

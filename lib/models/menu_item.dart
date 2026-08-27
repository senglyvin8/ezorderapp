import '../l10n/app_text.dart';

/// A single dish on the menu.
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.image,
    this.nameKm = '',
    this.descriptionKm = '',
    this.photo,
    this.discountPercent = 0,
    this.available = true,
    this.popular = false,
    this.signature = false,
  });

  final String id;
  final String name;
  final String description;

  /// Khmer name and description. Blank falls back to the English text.
  final String nameKm;
  final String descriptionKm;

  /// Full price, before any discount.
  final double price;
  final String categoryId;

  /// Key of a bundled illustration in `assets/food/`, without the extension.
  final String image;

  /// Base64 of a photo the admin uploaded. Wins over [image] when set.
  final String? photo;

  /// Percentage off the full price, 0 means no discount.
  final int discountPercent;

  /// Rule 9 — an unavailable item cannot be ordered.
  final bool available;

  /// Drives the virtual "Popular" category on the customer menu.
  final bool popular;

  /// House special — shown with a star.
  final bool signature;

  bool get hasDiscount => discountPercent > 0;

  /// What the customer actually pays, rounded to the cent.
  double get effectivePrice => hasDiscount
      ? double.parse((price * (100 - discountPercent) / 100).toStringAsFixed(2))
      : price;

  String displayName(AppLanguage lang) =>
      lang == AppLanguage.km && nameKm.trim().isNotEmpty ? nameKm : name;

  String displayDescription(AppLanguage lang) =>
      lang == AppLanguage.km && descriptionKm.trim().isNotEmpty
          ? descriptionKm
          : description;

  MenuItem copyWith({
    String? name,
    String? nameKm,
    String? description,
    String? descriptionKm,
    double? price,
    String? categoryId,
    String? image,
    String? photo,
    bool clearPhoto = false,
    int? discountPercent,
    bool? available,
    bool? popular,
    bool? signature,
  }) =>
      MenuItem(
        id: id,
        name: name ?? this.name,
        nameKm: nameKm ?? this.nameKm,
        description: description ?? this.description,
        descriptionKm: descriptionKm ?? this.descriptionKm,
        price: price ?? this.price,
        categoryId: categoryId ?? this.categoryId,
        image: image ?? this.image,
        photo: clearPhoto ? null : (photo ?? this.photo),
        discountPercent: discountPercent ?? this.discountPercent,
        available: available ?? this.available,
        popular: popular ?? this.popular,
        signature: signature ?? this.signature,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (nameKm.isNotEmpty) 'nameKm': nameKm,
        'description': description,
        if (descriptionKm.isNotEmpty) 'descriptionKm': descriptionKm,
        'price': price,
        'categoryId': categoryId,
        'image': image,
        if (photo != null) 'photo': photo,
        if (discountPercent > 0) 'discountPercent': discountPercent,
        'available': available,
        'popular': popular,
        if (signature) 'signature': signature,
      };

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        name: json['name'] as String,
        nameKm: json['nameKm'] as String? ?? '',
        description: json['description'] as String? ?? '',
        descriptionKm: json['descriptionKm'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        categoryId: json['categoryId'] as String,
        image: json['image'] as String? ?? 'placeholder',
        photo: json['photo'] as String?,
        discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 0,
        available: json['available'] as bool? ?? true,
        popular: json['popular'] as bool? ?? false,
        signature: json['signature'] as bool? ?? false,
      );
}

import '../l10n/app_text.dart';

/// Restaurant-level configuration edited on the Admin > Settings screen.
class RestaurantSettings {
  const RestaurantSettings({
    required this.name,
    required this.logo,
    this.nameKm = '',
    required this.phone,
    required this.address,
    required this.currencySymbol,
    required this.currencyCode,
    required this.paymentMethods,
  });

  final String name;

  /// Khmer name. Blank falls back to [name].
  final String nameKm;

  /// A short emoji or initials shown as the restaurant mark.
  final String logo;
  final String phone;
  final String address;
  final String currencySymbol;
  final String currencyCode;

  /// Rule 10 — payment methods are configurable per restaurant.
  final List<String> paymentMethods;

  String displayName(AppLanguage lang) =>
      lang == AppLanguage.km && nameKm.trim().isNotEmpty ? nameKm : name;

  RestaurantSettings copyWith({
    String? name,
    String? nameKm,
    String? logo,
    String? phone,
    String? address,
    String? currencySymbol,
    String? currencyCode,
    List<String>? paymentMethods,
  }) =>
      RestaurantSettings(
        name: name ?? this.name,
        nameKm: nameKm ?? this.nameKm,
        logo: logo ?? this.logo,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        currencyCode: currencyCode ?? this.currencyCode,
        paymentMethods: paymentMethods ?? this.paymentMethods,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (nameKm.isNotEmpty) 'nameKm': nameKm,
        'logo': logo,
        'phone': phone,
        'address': address,
        'currencySymbol': currencySymbol,
        'currencyCode': currencyCode,
        'paymentMethods': paymentMethods,
      };

  factory RestaurantSettings.fromJson(Map<String, dynamic> json) =>
      RestaurantSettings(
        name: json['name'] as String,
        nameKm: json['nameKm'] as String? ?? '',
        logo: json['logo'] as String? ?? '🍽️',
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String? ?? '',
        currencySymbol: json['currencySymbol'] as String? ?? r'$',
        currencyCode: json['currencyCode'] as String? ?? 'USD',
        paymentMethods: (json['paymentMethods'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
      );
}

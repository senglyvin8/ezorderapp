import '../l10n/app_text.dart';

/// A menu category such as "Rice" or "Drinks".
///
/// "Popular" is not stored here — it is a virtual category derived from the
/// [MenuItem.popular] flag so the admin cannot delete it by accident.
class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.nameKm = '',
  });

  final String id;
  final String name;

  /// Khmer name. Blank falls back to [name].
  final String nameKm;
  final int sortOrder;

  String displayName(AppLanguage lang) =>
      lang == AppLanguage.km && nameKm.trim().isNotEmpty ? nameKm : name;

  MenuCategory copyWith({String? name, String? nameKm, int? sortOrder}) =>
      MenuCategory(
        id: id,
        name: name ?? this.name,
        nameKm: nameKm ?? this.nameKm,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (nameKm.isNotEmpty) 'nameKm': nameKm,
        'sortOrder': sortOrder,
      };

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        nameKm: json['nameKm'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num).toInt(),
      );
}

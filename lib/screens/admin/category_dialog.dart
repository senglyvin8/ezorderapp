import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/menu_category.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bilingual_field.dart';

/// Creates or renames a category. Returns the category id on success so the
/// dish editor can select a freshly created category straight away.
Future<String?> showCategoryDialog(
  BuildContext context,
  AppStore store, {
  MenuCategory? category,
}) async {
  final t = store.text;
  final name = TextEditingController(text: category?.name ?? '');
  final nameKm = TextEditingController(text: category?.nameKm ?? '');

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: Text(
        category == null ? t.addCategory : t.renameCategory,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 360,
        child: Form(
          child: BilingualField(
            t: t,
            label: t.name,
            english: name,
            khmer: nameKm,
            textCapitalization: TextCapitalization.words,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child:
              Text(t.cancel, style: const TextStyle(color: AppColors.inkSoft)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.save),
        ),
      ],
    ),
  );

  final value = name.text.trim();
  final valueKm = nameKm.text.trim();
  name.dispose();
  nameKm.dispose();

  if (saved != true || value.isEmpty) return null;
  if (category == null) {
    return store.addCategory(value, nameKm: valueKm).id;
  }
  store.renameCategory(category.id, value, nameKm: valueKm);
  return category.id;
}

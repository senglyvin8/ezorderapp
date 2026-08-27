import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/food_image.dart';
import 'category_dialog.dart';
import 'menu_item_editor.dart';

/// Categories and dishes. Toggling a dish to Sold Out immediately blocks it on
/// the customer menu (Rule 9).
class AdminMenuScreen extends StatelessWidget {
  const AdminMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final categories = store.sortedCategories;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: t.menu,
        subtitle: store.untranslatedItemCount == 0
            ? t.allTranslated
            : t.khmerMissing(store.untranslatedItemCount),
        actions: [
          TextButton.icon(
            onPressed: () => showCategoryDialog(context, store),
            icon: const Icon(Icons.create_new_folder_rounded, size: 19),
            label: Text(t.category),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-menu-fab',
        onPressed: () => showMenuItemEditor(context),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(t.addDish),
      ),
      body: categories.isEmpty
          ? EmptyState(
              icon: Icons.restaurant_menu_rounded,
              title: t.noCategories,
              message: t.noCategoriesBody,
              action: FilledButton(
                onPressed: () => showCategoryDialog(context, store),
                child: Text(t.addCategory),
              ),
            )
          : PageWidth(
              maxWidth: 820,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  for (final category in categories) ...[
                    _CategoryBlock(
                      category: category,
                      items: store.itemsInCategory(category.id),
                      store: store,
                      onRename: () => showCategoryDialog(context, store,
                          category: category),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({
    required this.category,
    required this.items,
    required this.store,
    required this.onRename,
  });

  final MenuCategory category;
  final List<MenuItem> items;
  final AppStore store;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          '${category.displayName(store.language)}  ·  ${items.length}',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: t.renameCategory,
                visualDensity: VisualDensity.compact,
                onPressed: onRename,
                icon: const Icon(Icons.edit_rounded, size: 18),
                color: AppColors.inkSoft,
              ),
              IconButton(
                tooltip: t.deleteCategory,
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  final count = store.itemCountInCategory(category.id);
                  final confirmed = await confirmDialog(
                    context,
                    title: t.deleteCategoryTitle(category.name),
                    message: count == 0
                        ? t.deleteCategoryEmpty
                        : t.deleteCategoryBody(count),
                    confirmLabel: t.delete,
                    cancelLabel: t.cancel,
                    destructive: true,
                  );
                  if (confirmed) store.deleteCategory(category.id);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                color: AppColors.danger,
              ),
              IconButton(
                tooltip: t.addDishTo(category.displayName(store.language)),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    showMenuItemEditor(context, categoryId: category.id),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
                color: AppColors.brandDark,
              ),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(22),
                  child: Text(
                    t.noDishesInCategory,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const Divider(),
                      _MenuItemRow(item: items[i], store: store),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({required this.item, required this.store});

  final MenuItem item;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Opacity(
                opacity: item.available ? 1 : 0.45,
                child: FoodImage.forItem(item),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.displayName(store.language),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (item.signature) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star_rounded,
                          size: 17, color: AppColors.statusCooking),
                    ],
                    if (item.popular) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.local_fire_department_rounded,
                          size: 15, color: AppColors.brand),
                    ],
                    if (item.nameKm.trim().isEmpty) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tint(AppColors.note),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          t.needsKhmer,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.note,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      store.money(item.effectivePrice),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandDark,
                      ),
                    ),
                    if (item.hasDiscount) ...[
                      Text(
                        store.money(item.price),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.inkFaint,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        t.off(item.discountPercent),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    Text(
                      item.available ? t.available : t.soldOut,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: item.available
                            ? AppColors.statusReady
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: item.available,
            onChanged: (value) => store.setItemAvailability(item.id, value),
          ),
          IconButton(
            tooltip: t.edit,
            onPressed: () => showMenuItemEditor(context, item: item),
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.inkSoft,
          ),
        ],
      ),
    );
  }
}

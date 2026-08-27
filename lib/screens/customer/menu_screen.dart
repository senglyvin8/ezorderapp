import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/menu_item.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/cart_summary_bar.dart';
import '../../widgets/food_image.dart';
import '../../widgets/table_picker.dart';
import 'food_detail_sheet.dart';

/// Mobile-first menu: restaurant header, category strip, dish cards.
class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    required this.onOpenCart,
    required this.onLeaveTable,
  });

  final VoidCallback onOpenCart;
  final VoidCallback onLeaveTable;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _categoryId = kPopularCategoryId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final table = store.activeTable;
    final categories = store.customerCategories;

    if (!categories.any((c) => c.id == _categoryId)) {
      _categoryId = categories.first.id;
    }
    final items = store.itemsInCategory(_categoryId);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        automaticallyImplyLeading: false,
        title: store.restaurantDisplayName,
        subtitle: store.orderType == OrderType.takeaway
            ? t.takeaway
            : (table == null ? null : t.table(table.number)),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(11),
              ),
              child:
                  Text(store.settings.logo, style: const TextStyle(fontSize: 19)),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: t.changeTable,
            onPressed: () async {
              final confirmed = await confirmDialog(
                context,
                title: t.leaveTableTitle,
                message: t.leaveTableBody,
                confirmLabel: t.leaveTable,
                cancelLabel: t.cancel,
              );
              if (!context.mounted) return;
              if (confirmed) {
                store.leaveTable();
                widget.onLeaveTable();
              }
            },
            icon: const Icon(Icons.table_restaurant_rounded),
          ),
          _CartButton(count: store.cartItemCount, onPressed: widget.onOpenCart),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58 + 46),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Offered here rather than only in the cart, so someone who
                // has just scanned can choose to take it away straight away.
                _OrderTypeStrip(store: store),
                SizedBox(
                  height: 58,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return _CategoryChip(
                        label: store.categoryDisplayName(category.id),
                        selected: category.id == _categoryId,
                        onTap: () =>
                            setState(() => _categoryId = category.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.ramen_dining_rounded,
              title: t.emptyCategory,
              message: t.emptyCategoryBody,
            )
          : PageWidth(
              maxWidth: 640,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _FoodCard(item: items[index], store: store),
              ),
            ),
      // The running total sits above the tab bar so it is always in reach.
      bottomNavigationBar: CartSummaryBar(onTap: widget.onOpenCart),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: context.watch<AppStore>().text.cart,
          onPressed: onPressed,
          icon: const Icon(Icons.shopping_bag_rounded),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.card, width: 1.5),
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brand : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: -0.1,
              color: selected ? Colors.white : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

/// Star badge for a house special.
class SignatureBadge extends StatelessWidget {
  const SignatureBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppStore>().text;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: tint(AppColors.statusCooking),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded,
              size: 14, color: AppColors.statusCooking),
          const SizedBox(width: 3),
          Text(
            t.signature,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.statusCooking,
            ),
          ),
        ],
      ),
    );
  }

  final bool compact;
}

/// Strike-through original price beside the discounted one.
class PriceRow extends StatelessWidget {
  const PriceRow({
    super.key,
    required this.item,
    required this.store,
    this.size = 16.5,
  });

  final MenuItem item;
  final AppStore store;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dim = !item.available;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          store.money(item.effectivePrice),
          style: AppType.price.copyWith(
            fontSize: size,
            color: dim
                ? AppColors.inkFaint
                : (item.hasDiscount ? AppColors.danger : AppColors.ink),
          ),
        ),
        if (item.hasDiscount) ...[
          const SizedBox(width: 7),
          Text(
            store.money(item.price),
            style: TextStyle(
              fontSize: size - 3,
              fontWeight: FontWeight.w600,
              color: AppColors.inkFaint,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.item, required this.store});

  final MenuItem item;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final lang = store.language;
    final soldOut = !item.available;

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: soldOut ? null : () => showFoodDetailSheet(context, item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Opacity(
                    opacity: soldOut ? 0.4 : 1,
                    child: FoodImage.forItem(item),
                  ),
                ),
              ),
              if (item.hasDiscount && !soldOut)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomRight: Radius.circular(9),
                      ),
                    ),
                    child: Text(
                      t.off(item.discountPercent),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (soldOut)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        t.soldOut,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.signature)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: SignatureBadge(compact: true),
                  ),
                Text(
                  item.displayName(lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle.copyWith(
                    color: soldOut ? AppColors.inkFaint : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.displayDescription(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: PriceRow(item: item, store: store)),
                    if (soldOut)
                      Text(
                        t.unavailable,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkFaint,
                        ),
                      )
                    else
                      FilledButton(
                        onPressed: () => store.addToCart(item),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.small),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'KantumruyPro',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                        child: Text(t.add),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dine in or take away, right under the restaurant name. A diner who scanned
/// a table starts on Dine in; anyone can flip to Takeaway in one tap, and back
/// again by naming a table.
class _OrderTypeStrip extends StatelessWidget {
  const _OrderTypeStrip({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    return Container(
      height: 46,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _Segment(
                icon: Icons.restaurant_rounded,
                label: store.activeTable == null
                    ? t.dineIn
                    : '${t.dineIn} · ${store.activeTable!.number}',
                selected: store.orderType == OrderType.dineIn,
                onTap: () => switchToDineIn(context, store),
              ),
            ),
            Expanded(
              child: _Segment(
                icon: Icons.shopping_bag_rounded,
                label: t.takeaway,
                selected: store.orderType == OrderType.takeaway,
                onTap: () => store.setOrderType(OrderType.takeaway),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.inkSoft;
    return Material(
      color: selected ? AppColors.brand : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

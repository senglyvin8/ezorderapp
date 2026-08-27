import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/cart_line.dart';
import '../../models/menu_item.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/food_image.dart';
import '../../widgets/qty_stepper.dart';
import '../../widgets/table_picker.dart';

/// Taking an order at the counter, on a customer's behalf.
///
/// The basket lives in this screen's state rather than in [AppStore.cart]:
/// that cart belongs to whichever customer session the device is also
/// showing, and a cashier keying in a phone order must not disturb it.
class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final List<CartLine> _lines = [];
  final TextEditingController _note = TextEditingController();

  // Takeaway by default: it is the one destination that needs nothing else
  // typed in, so the screen always opens in a state that can be submitted.
  OrderType _type = OrderType.takeaway;
  String? _tableId;
  String _categoryId = kPopularCategoryId;
  int _seq = 0;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int get _itemCount => _lines.fold(0, (sum, l) => sum + l.quantity);
  double get _total => _lines.fold(0, (sum, l) => sum + l.lineTotal);

  int _quantityOf(String foodId) => _lines
      .where((l) => l.foodId == foodId)
      .fold(0, (sum, l) => sum + l.quantity);

  void _add(MenuItem item) {
    if (!item.available) return;
    setState(() {
      final index = _lines.indexWhere(
        (l) => l.foodId == item.id && l.price == item.effectivePrice,
      );
      if (index >= 0) {
        _lines[index] =
            _lines[index].copyWith(quantity: _lines[index].quantity + 1);
      } else {
        _lines.add(CartLine(
          // Local ids only — the store mints the real ones on submit.
          id: 'staff-line-${_seq++}',
          foodId: item.id,
          name: item.name,
          nameKm: item.nameKm,
          price: item.effectivePrice,
          quantity: 1,
        ));
      }
    });
  }

  void _setQuantity(String lineId, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _lines.removeWhere((l) => l.id == lineId);
      } else {
        final index = _lines.indexWhere((l) => l.id == lineId);
        if (index >= 0) {
          _lines[index] = _lines[index].copyWith(quantity: quantity);
        }
      }
    });
  }

  Future<void> _pickTable(AppStore store) async {
    final tableId =
        await showTablePicker(context, store: store, selectedId: _tableId);
    if (tableId == null) return;
    setState(() {
      _tableId = tableId;
      _type = OrderType.dineIn;
    });
  }

  /// Dine-in is only selectable once a table is named, so the button asks for
  /// one on the way in rather than failing at submit time.
  Future<void> _setType(AppStore store, OrderType type) async {
    if (type == OrderType.takeaway) {
      setState(() {
        _type = OrderType.takeaway;
        _tableId = null;
      });
      return;
    }
    if (_tableId == null) {
      await _pickTable(store);
      return;
    }
    setState(() => _type = OrderType.dineIn);
  }

  Future<void> _submit(AppStore store) async {
    final t = store.text;
    try {
      final order = store.placeStaffOrder(
        type: _type,
        tableId: _tableId,
        lines: _lines,
        note: _note.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, t.orderPlaced(order.orderNumber));
    } on StateError catch (error) {
      if (!mounted) return;
      showToast(context, error.message, error: true);
    }
  }

  Future<void> _openBasket(AppStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      // StatefulBuilder so the sheet redraws as quantities change; the lines
      // themselves stay owned by this screen.
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => _BasketSheet(
          store: store,
          lines: _lines,
          note: _note,
          total: _total,
          onQuantity: (id, qty) {
            _setQuantity(id, qty);
            setSheetState(() {});
            if (_lines.isEmpty) Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final table = _tableId == null
        ? null
        : store.tables.where((e) => e.id == _tableId).firstOrNull;

    final categories = store.customerCategories;
    if (!categories.any((c) => c.id == _categoryId)) {
      _categoryId = categories.first.id;
    }
    final items = store.itemsInCategory(_categoryId);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: t.newOrder,
        subtitle: _type == OrderType.takeaway
            ? t.takeaway
            : (table == null ? t.noTableChosen : t.table(table.number)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Container(
            height: 58,
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _Chip(
                  label: store.categoryDisplayName(category.id),
                  selected: category.id == _categoryId,
                  onTap: () => setState(() => _categoryId = category.id),
                  fillHeight: true,
                );
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _Destination(
            store: store,
            type: _type,
            tableLabel: table == null ? null : t.table(table.number),
            onDineIn: () => _setType(store, OrderType.dineIn),
            onTakeaway: () => _setType(store, OrderType.takeaway),
            onChangeTable: () => _pickTable(store),
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.restaurant_menu_rounded,
                    title: t.emptyCategory,
                    message: t.emptyCategoryBody,
                  )
                : PageWidth(
                    maxWidth: 720,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _DishRow(
                          item: item,
                          store: store,
                          quantity: _quantityOf(item.id),
                          onAdd: () => _add(item),
                        );
                      },
                    ),
                  ),
          ),
          _SubmitBar(
            store: store,
            itemCount: _itemCount,
            total: _total,
            onReview: _lines.isEmpty ? null : () => _openBasket(store),
            onSubmit: _lines.isEmpty ? null : () => _submit(store),
          ),
        ],
      ),
    );
  }
}

/// Dine in or takeaway, plus which table — the two things the kitchen needs
/// that the dishes themselves do not say.
class _Destination extends StatelessWidget {
  const _Destination({
    required this.store,
    required this.type,
    required this.tableLabel,
    required this.onDineIn,
    required this.onTakeaway,
    required this.onChangeTable,
  });

  final AppStore store;
  final OrderType type;
  final String? tableLabel;
  final VoidCallback onDineIn;
  final VoidCallback onTakeaway;
  final VoidCallback onChangeTable;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final dineIn = type == OrderType.dineIn;

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: PageWidth(
        maxWidth: 720,
        child: Row(
          children: [
            Expanded(
              child: _Chip(
                icon: Icons.restaurant_rounded,
                label: dineIn && tableLabel != null ? tableLabel! : t.dineIn,
                selected: dineIn,
                onTap: onDineIn,
                expand: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Chip(
                icon: Icons.shopping_bag_rounded,
                label: t.takeaway,
                selected: !dineIn,
                onTap: onTakeaway,
                expand: true,
              ),
            ),
            if (dineIn) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: t.chooseTable,
                onPressed: onChangeTable,
                icon: const Icon(Icons.table_restaurant_rounded),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.inkSoft,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(44, 44),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.item,
    required this.store,
    required this.quantity,
    required this.onAdd,
  });

  final MenuItem item;
  final AppStore store;
  final int quantity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final available = item.available;

    return Opacity(
      opacity: available ? 1 : 0.5,
      child: AppCard(
        padding: const EdgeInsets.all(10),
        onTap: available ? onAdd : null,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: SizedBox(
                width: 54,
                height: 54,
                child: FoodImage.forItem(item),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.itemDisplayName(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.cardTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    available
                        ? store.money(item.effectivePrice)
                        : t.unavailable,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: available
                          ? AppColors.brandDark
                          : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
            if (quantity > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '×$quantity',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandDark,
                  ),
                ),
              ),
            IconButton(
              onPressed: available ? onAdd : null,
              icon: const Icon(Icons.add_circle_rounded),
              color: AppColors.brand,
              iconSize: 30,
              tooltip: t.add,
            ),
          ],
        ),
      ),
    );
  }
}

/// The basket, opened from the bottom bar: quantities, removals and the note
/// that rides along to the kitchen.
class _BasketSheet extends StatelessWidget {
  const _BasketSheet({
    required this.store,
    required this.lines,
    required this.note,
    required this.total,
    required this.onQuantity,
  });

  final AppStore store;
  final List<CartLine> lines;
  final TextEditingController note;
  final double total;
  final void Function(String lineId, int quantity) onQuantity;

  @override
  Widget build(BuildContext context) {
    final t = store.text;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: PageWidth(
              maxWidth: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t.orderSummary}  ·  '
                          '${t.itemsCount(lines.fold(0, (s, l) => s + l.quantity))}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.displayName(store.language),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.cardTitle,
                                ),
                                Text(
                                  store.money(line.lineTotal),
                                  style: AppType.label,
                                ),
                              ],
                            ),
                          ),
                          QtyStepper(
                            quantity: line.quantity,
                            min: 0,
                            size: 34,
                            onChanged: (value) => onQuantity(line.id, value),
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  const SizedBox(height: 10),
                  TextField(
                    controller: note,
                    maxLines: 2,
                    decoration: appInput(
                      label: t.orderNote,
                      hint: t.orderNoteHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(t.total, style: AppType.cardTitle),
                      const Spacer(),
                      Text(
                        store.money(total),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.done),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.store,
    required this.itemCount,
    required this.total,
    required this.onReview,
    required this.onSubmit,
  });

  final AppStore store;
  final int itemCount;
  final double total;
  final VoidCallback? onReview;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = store.text;

    // Stacked rather than side by side: at 1.3x text the button alone is as
    // wide as a phone, so a row leaves the running total nowhere to go.
    return Material(
      color: AppColors.card,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: PageWidth(
            maxWidth: 720,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: onReview,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            itemCount == 0
                                ? t.nothingAddedYet
                                : t.itemsCount(itemCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.label,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          store.money(total),
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.send_rounded, size: 19),
                  label: Text(
                    t.sendToKitchen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.expand = false,
    this.fillHeight = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool expand;

  /// Set inside the fixed-height category strip, where the chip has to take
  /// the height it is given instead of padding itself past it.
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandDark : AppColors.inkSoft;
    return Material(
      color: selected ? AppColors.brandTint : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
              horizontal: 14, vertical: fillHeight ? 0 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
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

import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// Asks which table an order is for, and returns its id — or null if the
/// picker was dismissed.
///
/// Used in two places that both need a table before they can say "dine in":
/// the customer switching out of Takeaway, and the cashier keying in an order
/// at the counter.
Future<String?> showTablePicker(
  BuildContext context, {
  required AppStore store,
  String? selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _TablePickerSheet(store: store, selectedId: selectedId),
  );
}

/// Moves the customer to dine-in, asking which table first if they have not
/// scanned one.
///
/// Choosing Dine in used to throw them back to the QR screen and empty the
/// cart, which lost the order of anyone who tapped it by mistake from the
/// Takeaway tab. Now the only thing missing — the table number — is the only
/// thing asked for, and the basket is left alone.
Future<void> switchToDineIn(BuildContext context, AppStore store) async {
  if (store.activeTable != null) {
    store.setOrderType(OrderType.dineIn);
    return;
  }
  final tableId = await showTablePicker(context, store: store);
  if (tableId == null) return;
  store.chooseTable(tableId);
}

class _TablePickerSheet extends StatelessWidget {
  const _TablePickerSheet({required this.store, this.selectedId});

  final AppStore store;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final tables = store.tables;
    // The app caps scaling at 1.3x, so this is the worst case to size for.
    final textScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3).toDouble();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.chooseTable,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(t.pickTableToDineIn, style: AppType.label),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: tables.isEmpty
                  ? EmptyState(
                      icon: Icons.table_bar_rounded,
                      title: t.noTables,
                      message: t.noTablesBody,
                    )
                  : PageWidth(
                      maxWidth: 560,
                      child: GridView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        itemCount: tables.length,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          // A fixed height rather than a ratio, because the
                          // tile always holds two lines of text — but it has
                          // to grow with the reader's text size or those two
                          // lines no longer fit.
                          mainAxisExtent: 86 * textScale,
                        ),
                        itemBuilder: (context, index) {
                          final table = tables[index];
                          final occupied = store.isTableOccupied(table.id);
                          final selected = table.id == selectedId;
                          return _TableTile(
                            label: t.table(table.number),
                            detail: occupied ? t.occupied : t.available,
                            occupied: occupied,
                            selected: selected,
                            onTap: () =>
                                Navigator.of(context).pop(table.id),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An occupied table is still selectable — a second party joining a big table,
/// or a guest adding to an order already open, is normal. It is only marked.
class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.label,
    required this.detail,
    required this.occupied,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool occupied;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandTint : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.table_restaurant_rounded,
                size: 20,
                color: selected ? AppColors.brand : AppColors.inkSoft,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: occupied
                          ? AppColors.statusCooking
                          : AppColors.statusReady,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

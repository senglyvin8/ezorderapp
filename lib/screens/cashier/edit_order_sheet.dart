import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/qty_stepper.dart';

/// Lets the cashier take a dish off an order, or change how many of it the
/// customer is having, on the customer's behalf.
///
/// Every change goes straight through [AppStore], so the kitchen ticket and
/// the customer's tracker move with it — there is no local draft to save.
Future<void> showEditOrderSheet(BuildContext context, {required String orderId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _EditOrderSheet(orderId: orderId),
  );
}

class _EditOrderSheet extends StatelessWidget {
  const _EditOrderSheet({required this.orderId});

  final String orderId;

  void _setQuantity(
    BuildContext context,
    AppStore store,
    OrderItem item,
    int quantity,
  ) {
    final t = store.text;
    try {
      store.setOrderItemQuantity(orderId, item.id, quantity);
    } on StateError catch (error) {
      // The usual reason to land here is the kitchen tapping Start Cooking
      // while this sheet is open, or this being the last dish on the order.
      showToast(context, error.message, error: true);
      return;
    }
    showToast(
      context,
      quantity <= 0
          ? t.dishRemoved(item.displayName(store.language))
          : t.orderUpdated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final order = store.order(orderId);

    // The order can vanish or move on underneath this sheet, so it is read
    // fresh on every build rather than captured when the sheet opened.
    final editable = order != null && order.status.isCancellable;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: sheetMaxHeight(context, fraction: 0.85),
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
                          order == null
                              ? t.editItems
                              : t.orderNo(order.orderNumber),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          editable ? t.editItemsBody : t.cannotEditNow,
                          style: AppType.label,
                        ),
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
            if (order == null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(t.orderNotFound, style: AppType.body),
              )
            else
              Flexible(
                child: PageWidth(
                  maxWidth: 520,
                  child: ListView(
                    // Hug the order: a two-line order should not open a sheet
                    // the height of the screen. The Flexible above still caps
                    // a long one and lets it scroll.
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ItemRow(
                            item: item,
                            store: store,
                            editable: editable,
                            onQuantity: (value) =>
                                _setQuantity(context, store, item, value),
                            onRemove: () =>
                                _setQuantity(context, store, item, 0),
                          ),
                        ),
                      const Divider(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(t.total, style: AppType.cardTitle),
                          const Spacer(),
                          Text(
                            store.money(order.total),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Text(t.done),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.store,
    required this.editable,
    required this.onQuantity,
    required this.onRemove,
  });

  final OrderItem item;
  final AppStore store;
  final bool editable;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = store.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName(store.language),
                    style: AppType.cardTitle,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${store.money(item.price)}  ·  '
                    '${store.money(item.lineTotal)}',
                    style: AppType.label,
                  ),
                  if ((item.note ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.edit_note_rounded,
                              size: 16, color: AppColors.statusCooking),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.note!.trim(),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.statusCooking,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // The stepper stops at 1: dropping the last one is a removal, and
            // Remove says so plainly rather than hiding behind a minus tap.
            QtyStepper(
              quantity: item.quantity,
              size: 34,
              onChanged: editable ? onQuantity : (_) {},
            ),
          ],
        ),
        if (editable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(t.removeDish),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }
}

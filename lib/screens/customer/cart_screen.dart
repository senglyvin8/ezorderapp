import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/cart_line.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/qty_stepper.dart';
import '../../widgets/table_picker.dart';
import 'order_confirmation_screen.dart';

/// The basket. Quantities, notes and removals are all still editable here —
/// after Submit Order the customer can only watch (Rule 8).
class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.onBrowseMenu,
    required this.onTrackOrder,
  });

  final VoidCallback onBrowseMenu;
  final VoidCallback onTrackOrder;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Built in initState, not as a lazy field: a `late` initialiser that reads
  // from the context fires during dispose() if the screen was never shown,
  // and looking up an ancestor there throws.
  late final TextEditingController _orderNote;

  @override
  void initState() {
    super.initState();
    _orderNote = TextEditingController(text: context.read<AppStore>().cartNote);
  }

  @override
  void dispose() {
    _orderNote.dispose();
    super.dispose();
  }

  Future<void> _editLineNote(AppStore store, CartLine line) async {
    final t = store.text;
    final controller = TextEditingController(text: line.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text(line.displayName(store.language),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: appInput(hint: t.noteHintShort),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel,
                style: const TextStyle(color: AppColors.inkSoft)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.saveNote),
          ),
        ],
      ),
    );
    if (saved == true) {
      store.setCartLineNote(line.id, controller.text);
    }
    controller.dispose();
  }

  Future<void> _submit(AppStore store) async {
    store.setCartNote(_orderNote.text);
    try {
      final order = await store.submitOrder();
      if (!mounted) return;
      _orderNote.clear();
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => OrderConfirmationScreen(orderId: order.id),
        ),
      );
      if (!mounted) return;
      if (result == 'track') {
        widget.onTrackOrder();
      } else {
        widget.onBrowseMenu();
      }
    } on StateError catch (error) {
      if (!mounted) return;
      showToast(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final table = store.activeTable;
    final lines = store.cart;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        automaticallyImplyLeading: false,
        title: t.yourOrder,
        subtitle: store.orderType == OrderType.takeaway
            ? t.takeaway
            : (table == null ? null : t.table(table.number)),
        actions: [
          if (lines.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirmed = await confirmDialog(
                  context,
                  title: t.clearCartTitle,
                  message: t.clearCartBody,
                  confirmLabel: t.clear,
                  cancelLabel: t.cancel,
                  destructive: true,
                );
                if (confirmed) {
                  store.clearCart();
                  _orderNote.clear();
                }
              },
              child: Text(t.clear),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: lines.isEmpty
          ? EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: t.cartEmpty,
              message: t.cartEmptyBody,
              action: FilledButton(
                onPressed: widget.onBrowseMenu,
                child: Text(t.browseMenu),
              ),
            )
          : PageWidth(
              maxWidth: 640,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  SectionLabel(t.orderTypeQuestion),
                  const _OrderTypePicker(),
                  const SizedBox(height: 20),
                  SectionLabel(
                    '${t.orderSummary}  ·  ${t.itemsCount(store.cartItemCount)}',
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                    child: Text(
                      t.reviewBeforeSubmit,
                      style: const TextStyle(
                          fontSize: 14.5, color: AppColors.inkSoft),
                    ),
                  ),
                  for (final line in lines) ...[
                    _CartLineCard(
                      line: line,
                      store: store,
                      onEditNote: () => _editLineNote(store, line),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 6),
                  SectionLabel(t.orderNote),
                  TextField(
                    controller: _orderNote,
                    maxLines: 2,
                    onChanged: store.setCartNote,
                    decoration: appInput(hint: t.orderNoteHint),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      children: [
                        _TotalRow(
                          label: t.items,
                          value: '${store.cartItemCount}',
                        ),
                        const SizedBox(height: 10),
                        _TotalRow(
                          label: t.subtotal,
                          value: store.money(store.cartSubtotal),
                        ),
                        const SizedBox(height: 10),
                        const Divider(),
                        const SizedBox(height: 10),
                        _TotalRow(
                          label: t.total,
                          value: store.money(store.cartTotal),
                          emphasised: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: lines.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: PageWidth(
                  maxWidth: 640,
                  child: FilledButton(
                    onPressed: () => _submit(store),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    child: Text(
                      '${t.submitOrder}  ·  ${store.money(store.cartTotal)}',
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.store,
    required this.onEditNote,
  });

  final CartLine line;
  final AppStore store;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.displayName(store.language),
                        style: AppType.cardTitle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${line.quantity} × ${store.money(line.price)}',
                        style: AppType.label,
                      ),
                    ],
                  ),
                ),
                Text(
                  store.money(line.lineTotal),
                  style: AppType.price,
                ),
              ],
            ),
          ),
          if ((line.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(right: 5),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: tint(AppColors.note),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.edit_note_rounded,
                      size: 16, color: AppColors.note),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      line.note!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.note,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              QtyStepper(
                quantity: line.quantity,
                size: 32,
                onChanged: (value) =>
                    store.setCartLineQuantity(line.id, value),
              ),
              const Spacer(),
              IconButton(
                tooltip: store.text.editNote,
                onPressed: onEditNote,
                icon: const Icon(Icons.edit_note_rounded),
                color: AppColors.inkSoft,
              ),
              IconButton(
                tooltip: store.text.remove,
                onPressed: () => store.removeCartLine(line.id),
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasised ? 17 : 15,
            fontWeight: emphasised ? FontWeight.w800 : FontWeight.w600,
            color: emphasised ? AppColors.ink : AppColors.inkSoft,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasised ? 20 : 15,
            fontWeight: FontWeight.w800,
            color: emphasised ? AppColors.brandDark : AppColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Dine in or take away, chosen before the order is sent. Dine-in needs a
/// table, so choosing it without one asks which table it is.
class _OrderTypePicker extends StatelessWidget {
  const _OrderTypePicker();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    return Row(
      children: [
        Expanded(
          child: _TypeCard(
            icon: Icons.restaurant_rounded,
            label: t.dineIn,
            detail: store.activeTable == null
                ? t.scanTableQr
                : t.table(store.activeTable!.number),
            selected: store.orderType == OrderType.dineIn,
            onTap: () => switchToDineIn(context, store),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TypeCard(
            icon: Icons.shopping_bag_rounded,
            label: t.takeaway,
            detail: t.takeawayBlurb,
            selected: store.orderType == OrderType.takeaway,
            onTap: () => store.setOrderType(OrderType.takeaway),
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandTint : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 19,
                      color: selected ? AppColors.brandDark : AppColors.inkSoft),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle_rounded,
                        size: 18, color: AppColors.brand),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: selected ? AppColors.brandDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.label.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

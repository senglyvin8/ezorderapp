import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/status_label.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/card_grid.dart';
import '../../widgets/order_ticket.dart';
import '../../widgets/report_panel.dart';
import '../../widgets/work_alert.dart';
import 'edit_order_sheet.dart';
import 'invoice_screen.dart';
import 'new_order_screen.dart';
import 'payment_dialog.dart';

/// Cashier station.
///
/// Three tabs, because the till is also the front desk: **Live** is every
/// order in the restaurant right now — including the ones the kitchen has not
/// touched yet, which are the only ones that can still be cancelled — **To
/// pay** is Rule 7's queue (READY -> PAID -> COMPLETED), **Closed** is the
/// day's history, and **Report** is the same takings report the owner sees —
/// a cashier closing up asks exactly the same question, and sending them to
/// find an admin for it would be silly.
class CashierRoot extends StatefulWidget {
  const CashierRoot({super.key});

  @override
  State<CashierRoot> createState() => _CashierRootState();
}

class _CashierRootState extends State<CashierRoot> {
  /// Payment method picked per order, before it is confirmed.
  final Map<String, String> _selectedMethod = {};

  Future<void> _cancel(AppStore store, Order order) async {
    final t = store.text;
    final confirmed = await confirmDialog(
      context,
      title: t.cancelOrderTitle(order.orderNumber),
      message: t.cancelOrderBody,
      confirmLabel: t.cancelOrder,
      cancelLabel: t.keepOrder,
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    try {
      store.cancelOrder(order.id);
    } on StateError catch (error) {
      if (!mounted) return;
      // The usual reason to land here is that the kitchen tapped Start
      // Cooking while the confirmation dialog was open.
      showToast(context, error.message, error: true);
      return;
    }
    if (!mounted) return;
    showToast(context, t.orderCancelled(order.orderNumber));
  }

  Future<void> _newOrder() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NewOrderScreen()),
      );

  Future<void> _collect(AppStore store, Order order) async {
    final methods = store.settings.paymentMethods;
    final method = _selectedMethod[order.id] ??
        (methods.isNotEmpty ? methods.first : 'Cash');

    final confirmed = await showPaymentDialog(
      context,
      order: order,
      method: method,
      total: store.money(order.total),
    );
    if (!mounted || !confirmed) return;

    try {
      store.collectPayment(order.id, method);
    } on StateError catch (error) {
      if (!mounted) return;
      showToast(context, error.message, error: true);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceScreen(orderId: order.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final live = store.liveOrders;
    final ready = store.ordersWithStatus(OrderStatus.ready);
    final settled = store.settledOrders;

    final takings = settled
        .where((o) =>
            o.status != OrderStatus.cancelled &&
            _isToday(o.paidAt ?? o.createdAt))
        .fold<double>(0, (sum, o) => sum + o.total);

    // The till's alert is about money waiting, not work arriving: an order
    // reaching READY is the moment somebody has to go and take payment.
    return WorkAlert(
      count: ready.length,
      message: t.readyToPayNow(ready.length),
      color: AppColors.statusReady,
      icon: Icons.point_of_sale_rounded,
      child: DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'cashier-new-order',
          onPressed: _newOrder,
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: Text(t.newOrder),
        ),
        appBar: appTopBar(
          automaticallyImplyLeading: false,
          title: t.roleCashier,
          subtitle: t.takenToday(store.money(takings)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: TabBar(
                // Four labels, and Khmer ones are long: scrolling beats
                // four columns of ellipsis.
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.brandDark,
                unselectedLabelColor: AppColors.inkSoft,
                indicatorColor: AppColors.brand,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: '${t.liveOrders} (${live.length})'),
                  Tab(text: '${t.toPay} (${ready.length})'),
                  Tab(text: t.closed),
                  Tab(text: t.report),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            if (live.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_rounded,
                title: t.nothingLive,
                message: t.nothingLiveBody,
              )
            else
              CardGrid(
                minTileWidth: 420,
                children: [
                  for (final order in live)
                    OrderTicket(
                      order: order,
                      store: store,
                      trailingInfo: order.placedBy == null
                          ? null
                          : t.placedBy(order.placedBy!),
                      // Only a queued order can still be changed or pulled
                      // back; once the kitchen starts, the card is watch-only.
                      secondaryAction: order.status.isCancellable
                          ? OutlinedButton.icon(
                              onPressed: () => _cancel(store, order),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: Text(
                                t.cancelOrder,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(
                                    color: AppColors.danger, width: 1.2),
                              ),
                            )
                          : null,
                      action: order.status.isCancellable
                          ? OutlinedButton.icon(
                              onPressed: () =>
                                  showEditOrderSheet(context, orderId: order.id),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: Text(
                                t.editItems,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            if (ready.isEmpty)
              EmptyState(
                icon: Icons.point_of_sale_rounded,
                title: t.noPayable,
                message: t.noPayableBody,
              )
            else
              CardGrid(
                minTileWidth: 420,
                children: [
                  for (final order in ready)
                    _PayableTicket(
                      order: order,
                      store: store,
                      selected: _selectedMethod[order.id] ??
                          (store.settings.paymentMethods.isNotEmpty
                              ? store.settings.paymentMethods.first
                              : 'Cash'),
                      onSelect: (method) => setState(
                          () => _selectedMethod[order.id] = method),
                      onCollect: () => _collect(store, order),
                    ),
                ],
              ),
            if (settled.isEmpty)
              EmptyState(
                icon: Icons.receipt_rounded,
                title: t.nothingSettled,
                message: t.nothingSettledBody,
              )
            else
              CardGrid(
                minTileWidth: 420,
                children: [
                  for (final order in settled)
                    OrderTicket(
                      order: order,
                      store: store,
                      trailingInfo: order.status == OrderStatus.cancelled
                          ? (order.cancelledBy == null
                              ? statusLabel(order.status, t)
                              : t.cancelledBy(order.cancelledBy!))
                          : t.paidWith(
                              order.paymentMethod ?? '—',
                              DateFormat('h:mm a')
                                  .format(order.paidAt ?? order.createdAt),
                            ),
                      action: order.status == OrderStatus.cancelled
                          ? null
                          : OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      InvoiceScreen(orderId: order.id),
                                ),
                              ),
                              icon: const Icon(Icons.receipt_long_rounded,
                                  size: 18),
                              label: Text(t.viewInvoice),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                    ),
                ],
              ),
            const ReportPanel(),
          ],
        ),
      ),
      ),
    );
  }

  static bool _isToday(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }
}

class _PayableTicket extends StatelessWidget {
  const _PayableTicket({
    required this.order,
    required this.store,
    required this.selected,
    required this.onSelect,
    required this.onCollect,
  });

  final Order order;
  final AppStore store;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final methods = store.settings.paymentMethods;
    final t = store.text;

    return OrderTicket(
      order: order,
      store: store,
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.paymentMethod,
            style: const TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final method in methods)
                _MethodChip(
                  label: method,
                  selected: method == selected,
                  onTap: () => onSelect(method),
                ),
            ],
          ),
        ],
      ),
      action: FilledButton.icon(
        onPressed: onCollect,
        icon: const Icon(Icons.payments_rounded),
        label: Text(t.collectPayment),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _icons = {
    'Cash': Icons.payments_rounded,
    'KHQR': Icons.qr_code_2_rounded,
    'Card': Icons.credit_card_rounded,
    'Other': Icons.more_horiz_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandTint : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icons[label] ?? Icons.payments_rounded,
                size: 17,
                color: selected ? AppColors.brandDark : AppColors.inkSoft,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.brandDark : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

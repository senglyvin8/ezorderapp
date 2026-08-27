import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/status_label.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/order_tracker.dart';
import '../../widgets/status_badge.dart';

/// Live status of the orders placed from this table.
///
/// Nothing here polls: the screen listens to the same [AppStore] the Kitchen
/// and Cashier write to, so it moves the instant staff tap a button.
class TrackOrderScreen extends StatelessWidget {
  const TrackOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final orders = store.myOrders;
    final table = store.activeTable;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        automaticallyImplyLeading: false,
        title: t.myOrder,
        subtitle: table == null ? null : t.table(table.number),
      ),
      body: orders.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_rounded,
              title: t.noOrdersYet,
              message: t.noOrdersYetBody,
            )
          : PageWidth(
              maxWidth: 620,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) =>
                    _TrackedOrderCard(order: orders[index], store: store),
              ),
            ),
    );
  }
}

class _TrackedOrderCard extends StatelessWidget {
  const _TrackedOrderCard({required this.order, required this.store});

  final Order order;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final lang = store.language;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.orderNo(order.orderNumber),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${orderPlaceLabel(order, t)}  ·  '
                      '${DateFormat('h:mm a').format(order.createdAt)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(order.status),
            ],
          ),
          const SizedBox(height: 18),
          OrderTracker(order.status),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity} × ${item.displayName(lang)}',
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    store.money(item.lineTotal),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.total,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              Text(
                store.money(order.total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandDark,
                ),
              ),
            ],
          ),
          if (order.paymentMethod != null) ...[
            const SizedBox(height: 12),
            InfoChip(
              t.paidBy(order.paymentMethod!),
              icon: Icons.check_circle_rounded,
              color: AppColors.statusPaid,
            ),
          ],
        ],
      ),
    );
  }
}

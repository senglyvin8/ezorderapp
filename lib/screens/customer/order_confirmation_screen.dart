import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/status_label.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/status_badge.dart';

/// Shown the moment an order reaches the kitchen.
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final lang = store.language;
    final order = store.order(orderId);

    if (order == null) {
      return Scaffold(
        appBar: appTopBar(title: t.orders),
        body: EmptyState(
          icon: Icons.receipt_long_rounded,
          title: t.orderNotFound,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: t.orderNo(order.orderNumber),
        subtitle: orderPlaceLabel(order, t),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: t.close,
            onPressed: () => Navigator.of(context).pop('menu'),
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: PageWidth(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: tint(AppColors.statusReady),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 40,
                  color: AppColors.statusReady,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              t.orderNo(order.orderNumber),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${orderPlaceLabel(order, t)}  ·  '
              '${DateFormat('d MMM yyyy — h:mm a').format(order.createdAt)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            Center(child: StatusBadge(order.status)),
            const SizedBox(height: 18),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.soup_kitchen_rounded,
                          color: AppColors.statusReady),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.sentToKitchen,
                          style: const TextStyle(
                              fontSize: 16.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 14),
                  for (final item in order.items) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.quantity} × ${item.displayName(lang)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if ((item.note ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      item.note!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.statusCooking,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            store.money(item.lineTotal),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if ((order.customerNote ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tint(AppColors.statusCooking),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        order.customerNote!,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.statusCooking,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.total,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        store.money(order.total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop('track'),
              icon: const Icon(Icons.timeline_rounded),
              label: Text(t.trackOrder),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop('menu'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(t.orderSomethingElse),
            ),
          ],
        ),
      ),
    );
  }
}

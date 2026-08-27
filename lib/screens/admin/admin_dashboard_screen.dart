import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/status_label.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/status_badge.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final summary = store.todaySummary;
    final recent = store.ordersNewestFirst.take(8).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        automaticallyImplyLeading: false,
        title: store.restaurantDisplayName,
        subtitle: DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
      ),
      body: PageWidth(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            SectionLabel(t.todaysSummary),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 620 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 4 ? 1.75 : 1.9,
                  children: [
                    _StatTile(
                      label: t.orders,
                      value: '${summary.orders}',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.statusNew,
                    ),
                    _StatTile(
                      label: t.revenue,
                      value: store.money(summary.revenue),
                      icon: Icons.payments_rounded,
                      color: AppColors.statusReady,
                    ),
                    _StatTile(
                      label: t.pending,
                      value: '${summary.pending}',
                      icon: Icons.hourglass_bottom_rounded,
                      color: AppColors.statusCooking,
                    ),
                    _StatTile(
                      label: t.completed,
                      value: '${summary.completed}',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.statusCompleted,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 26),
            SectionLabel(t.recentOrders),
            AppCard(
              padding: EdgeInsets.zero,
              child: recent.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        t.noOrdersToday,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.inkSoft),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < recent.length; i++) ...[
                          if (i > 0) const Divider(),
                          _RecentRow(order: recent[i], store: store),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tint(color),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label,
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppType.numeral),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.order, required this.store});

  final Order order;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.orderNo(order.orderNumber),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${orderPlaceLabel(order, t)}  ·  '
                  '${t.itemsCount(order.itemCount)}  ·  '
                  '${DateFormat('h:mm a').format(order.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                store.money(order.total),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              StatusBadge(order.status, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}

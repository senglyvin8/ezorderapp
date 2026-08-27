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

/// Read-only view of every order, filterable by status.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final all = store.ordersNewestFirst;
    final orders =
        _filter == null ? all : all.where((o) => o.status == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        automaticallyImplyLeading: false,
        title: t.orders,
        subtitle: t.totalCount(all.length),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              children: [
                _FilterChip(
                  label: '${t.all} (${all.length})',
                  selected: _filter == null,
                  color: AppColors.brand,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final status in OrderStatus.values) ...[
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '${statusLabel(status, t)} '
                        '(${all.where((o) => o.status == status).length})',
                    selected: _filter == status,
                    color: statusColor(status),
                    onTap: () => setState(() => _filter = status),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: orders.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_rounded,
              title: t.noOrdersHere,
              message: t.noOrdersHereBody,
            )
          : CardGrid(
              minTileWidth: 400,
              children: [
                for (final order in orders)
                  OrderTicket(
                    order: order,
                    store: store,
                    trailingInfo: order.paidAt == null
                        ? DateFormat('d MMM, h:mm a').format(order.createdAt)
                        : '${t.statusPaid} — ${order.paymentMethod ?? '—'}',
                  ),
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tint(color) : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: selected ? color : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

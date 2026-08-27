import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_store.dart';
import '../l10n/status_label.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';
import 'status_badge.dart';

/// The order card shared by the Kitchen, Cashier and Admin screens.
///
/// Everything a member of staff needs is on the face of the card: number,
/// table, items with quantities, notes, time and status.
class OrderTicket extends StatelessWidget {
  const OrderTicket({
    super.key,
    required this.order,
    required this.store,
    this.action,
    this.secondaryAction,
    this.onTap,
    this.large = false,
    this.showStatus = true,
    this.trailingInfo,
    this.extra,
  });

  final Order order;
  final AppStore store;
  final Widget? action;
  final Widget? secondaryAction;
  final VoidCallback? onTap;

  /// Kitchen uses the large variant: bigger type, bigger buttons.
  final bool large;
  final bool showStatus;
  final String? trailingInfo;

  /// Optional block rendered between the total and the action buttons —
  /// the cashier uses it for the payment-method picker.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(order.status);
    final t = store.text;
    final lang = store.language;
    final timeFormat = DateFormat('h:mm a');
    final nameSize = large ? 17.0 : 15.0;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      borderColor: AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, large ? 14 : 12, 16, large ? 14 : 12),
            decoration: BoxDecoration(
              color: tint(color),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card - 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.orderNo(order.orderNumber),
                        style: TextStyle(
                          fontSize: large ? 21 : 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (order.isTakeaway) ...[
                            // A takeaway order has no table, so the marker has
                            // to be the thing staff spot first.
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: large ? 9 : 7,
                                  vertical: large ? 4 : 3),
                              decoration: BoxDecoration(
                                color: AppColors.ink,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shopping_bag_rounded,
                                      size: large ? 14 : 12,
                                      color: Colors.white),
                                  const SizedBox(width: 5),
                                  Text(
                                    t.takeaway.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: large ? 12 : 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              order.isTakeaway
                                  ? timeFormat.format(order.createdAt)
                                  : '${orderPlaceLabel(order, t)}  ·  '
                                      '${timeFormat.format(order.createdAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: large ? 14 : 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (showStatus) StatusBadge(order.status, compact: !large),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, large ? 14 : 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in order.items) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '×${item.quantity}',
                            style: TextStyle(
                              fontSize: nameSize - 2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.displayName(lang),
                                style: TextStyle(
                                  fontSize: nameSize,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              if ((item.note ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.edit_note_rounded,
                                          size: 16,
                                          color: AppColors.statusCooking),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item.note!,
                                          style: TextStyle(
                                            fontSize: nameSize - 2,
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
                        Text(
                          store.money(item.lineTotal),
                          style: TextStyle(
                            fontSize: nameSize - 1,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sticky_note_2_rounded,
                            size: 17, color: AppColors.statusCooking),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.customerNote!,
                            style: TextStyle(
                              fontSize: nameSize - 2,
                              fontWeight: FontWeight.w600,
                              color: AppColors.statusCooking,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      t.total,
                      style: TextStyle(
                        fontSize: nameSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      store.money(order.total),
                      style: TextStyle(
                        fontSize: large ? 20 : 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (trailingInfo != null)
                      Flexible(
                        child: Text(
                          trailingInfo!,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                  ],
                ),
                if (extra != null) ...[
                  const SizedBox(height: 14),
                  extra!,
                ],
                if (action != null || secondaryAction != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (secondaryAction != null) ...[
                        Expanded(child: secondaryAction!),
                        if (action != null) const SizedBox(width: 10),
                      ],
                      if (action != null)
                        Expanded(flex: 2, child: action!),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

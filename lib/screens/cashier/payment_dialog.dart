import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/status_label.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';

/// Explicit confirmation before money changes hands.
Future<bool> showPaymentDialog(
  BuildContext context, {
  required Order order,
  required String method,
  required String total,
}) async {
  final t = context.read<AppStore>().text;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      title: Text(
        t.confirmPayment,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(label: t.orders, value: '#${order.orderNumber}'),
          const SizedBox(height: 10),
          _Row(label: t.tables, value: orderPlaceLabel(order, t)),
          const SizedBox(height: 10),
          _Row(label: t.paymentMethod, value: method),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.total,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  total,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.cancel,
              style: const TextStyle(color: AppColors.inkSoft)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.confirmPayment),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 16, color: AppColors.inkSoft)),
        Text(value,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

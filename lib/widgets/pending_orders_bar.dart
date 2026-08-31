import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// Says how many orders are still on this device, and sends them.
///
/// Invisible when there is nothing waiting, which is almost always. It appears
/// only after the restaurant has been unreachable, and it is deliberately hard
/// to miss: an order nobody knows about is worse than one nobody can send,
/// because the kitchen carries on as if the table never ordered.
///
/// Retrying is automatic on the next successful trip to the backend; the
/// button is here because somebody who has just fixed the wifi should not have
/// to wonder whether the app noticed.
class PendingOrdersBar extends StatefulWidget {
  const PendingOrdersBar({super.key});

  @override
  State<PendingOrdersBar> createState() => _PendingOrdersBarState();
}

class _PendingOrdersBarState extends State<PendingOrdersBar> {
  bool _sending = false;

  Future<void> _send(AppStore store) async {
    setState(() => _sending = true);
    final sent = await store.flushPendingOrders();
    if (!mounted) return;
    setState(() => _sending = false);
    showToast(
      context,
      sent > 0 ? store.text.ordersSent(sent) : store.text.stillOffline,
      error: sent == 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.hasPendingOrders) return const SizedBox.shrink();
    final t = store.text;

    return Material(
      color: tint(AppColors.statusCooking),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 18, color: AppColors.statusCooking),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t.ordersWaiting(store.pendingOrderCount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.statusCooking,
                  ),
                ),
              ),
              if (_sending)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(t.sending,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.statusCooking)),
                )
              else
                TextButton(
                  onPressed: () => _send(store),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.statusCooking,
                    minimumSize: const Size(0, 38),
                  ),
                  child: Text(t.sendNow),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

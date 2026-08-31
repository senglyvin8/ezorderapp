import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../data/reconnect.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// Says how many orders are still on this device, and sends them.
///
/// Invisible when there is nothing waiting, which is almost always. It appears
/// only after the restaurant has been unreachable, and it is deliberately hard
/// to miss: an order nobody knows about is worse than one nobody can send,
/// because the kitchen carries on as if the table never ordered.
///
/// Sending is automatic: when the device picks up a network again, and when
/// somebody comes back to the app. The button is here anyway, because a person
/// who has just walked over and fixed the router should not have to wonder
/// whether the app noticed.
class PendingOrdersBar extends StatefulWidget {
  const PendingOrdersBar({super.key, this.reconnects});

  /// Where "the network came back" comes from.
  ///
  /// Null in the app, which listens to the device. Tests pass their own so
  /// they can drop and restore a connection without a plugin channel.
  final Stream<void>? reconnects;

  @override
  State<PendingOrdersBar> createState() => _PendingOrdersBarState();
}

class _PendingOrdersBarState extends State<PendingOrdersBar>
    with WidgetsBindingObserver {
  bool _sending = false;
  StreamSubscription<void>? _reconnects;

  @override
  void initState() {
    super.initState();
    // Two ways an order gets sent without anybody asking. The device picking
    // up a network again is the obvious one. Coming back to the app is the
    // other, and it matters more than it looks: a phone that was asleep in a
    // pocket while the wifi returned reports no change on waking, so without
    // this the order would sit there until somebody noticed the bar.
    WidgetsBinding.instance.addObserver(this);
    _reconnects = (widget.reconnects ?? Reconnect.hints()).listen((_) {
      _sendQuietly();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_reconnects?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sendQuietly();
  }

  /// Sends what is waiting without saying anything.
  ///
  /// Nobody asked for this, so a toast would interrupt whatever they are
  /// doing — and the bar disappearing already says it worked. A failure says
  /// nothing either: it is still on screen, still queued, and the person
  /// holding the phone has not done anything to be told off about.
  Future<void> _sendQuietly() async {
    if (!mounted || _sending) return;
    final store = context.read<AppStore>();
    if (!store.hasPendingOrders) return;
    setState(() => _sending = true);
    await store.flushPendingOrders();
    if (mounted) setState(() => _sending = false);
  }

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

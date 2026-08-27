import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/app_text.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/card_grid.dart';
import '../../widgets/order_ticket.dart';
import '../../widgets/work_alert.dart';

/// Kitchen display, deliberately two tabs.
///
/// A ticket stays in **New** for its whole working life: tapping *Start
/// Cooking* flips it to In Progress in place and swaps the button to *Ready to
/// Serve*. Only that second tap moves it across to **Ready**. Rule 6 still
/// holds — NEW -> COOKING -> READY, and nothing skips a step.
class KitchenRoot extends StatelessWidget {
  const KitchenRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;

    final working = [
      ...store.ordersWithStatus(OrderStatus.newOrder),
      ...store.ordersWithStatus(OrderStatus.cooking),
    ];
    final ready = store.ordersWithStatus(OrderStatus.ready);
    final counts = store.kitchenCounts;
    // The strip and the tabs are fixed-height chrome, so they have to grow
    // with the reader's text size or the numbers clip.
    final scale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3).toDouble();
    final stripHeight = 74 * scale;
    final tabHeight = 56 * scale;
    final dishesWaiting =
        working.fold<int>(0, (sum, o) => sum + o.itemCount);

    // Counted from what is queued, not from every live order: a ticket
    // moving on to the stove must not read as a new one arriving.
    return WorkAlert(
      count: counts.waiting,
      message: t.newOrdersArrived(counts.waiting),
      color: AppColors.statusNew,
      icon: Icons.ramen_dining_rounded,
      child: DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: appTopBar(
          automaticallyImplyLeading: false,
          title: t.kitchen,
          subtitle: '${t.ordersInProgress(working.length)}  ·  '
              '${t.dishesCount(dishesWaiting)}',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56 + 74),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CountStrip(counts: counts, t: t, height: stripHeight),
                  SizedBox(
                    height: tabHeight,
                    child: TabBar(
                labelColor: AppColors.brandDark,
                unselectedLabelColor: AppColors.inkSoft,
                indicatorColor: AppColors.brand,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
                      tabs: [
                        Tab(text: '${t.tabNew} (${working.length})'),
                        Tab(text: '${t.tabReady} (${ready.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            if (working.isEmpty)
              EmptyState(
                icon: Icons.inbox_rounded,
                title: t.noNewOrders,
                message: t.noNewOrdersBody,
              )
            else
              CardGrid(
                minTileWidth: 400,
                children: [
                  for (final order in working)
                    OrderTicket(
                      order: order,
                      store: store,
                      large: true,
                      action: order.status == OrderStatus.newOrder
                          ? FilledButton.icon(
                              onPressed: () => store.startCooking(order.id),
                              icon: const Icon(
                                  Icons.local_fire_department_rounded),
                              label: Text(t.startCooking),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 60),
                                backgroundColor: AppColors.statusCooking,
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: () => store.markReady(order.id),
                              icon: const Icon(Icons.room_service_rounded),
                              label: Text(t.readyToServe),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 60),
                                backgroundColor: AppColors.statusReady,
                              ),
                            ),
                    ),
                ],
              ),
            if (ready.isEmpty)
              EmptyState(
                icon: Icons.done_all_rounded,
                title: t.nothingReady,
                message: t.nothingReadyBody,
              )
            else
              CardGrid(
                minTileWidth: 400,
                children: [
                  for (final order in ready)
                    OrderTicket(
                      order: order,
                      store: store,
                      large: true,
                      action: _HandedOverNote(label: t.handedToCashier),
                    ),
                ],
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _HandedOverNote extends StatelessWidget {
  const _HandedOverNote({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint(AppColors.statusReady),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.statusReady,
        ),
      ),
    );
  }
}

/// Running counts across the top of the kitchen board: the queue, the stove,
/// the pass, and the day's tally.
class _CountStrip extends StatelessWidget {
  const _CountStrip({
    required this.counts,
    required this.t,
    required this.height,
  });

  final ({
    int waiting,
    int cooking,
    int toServe,
    int cookedOrders,
    int cookedDishes
  }) counts;
  final AppText t;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          _Count(
            value: '${counts.waiting}',
            label: t.waiting,
            color: AppColors.statusNew,
          ),
          _Count(
            value: '${counts.cooking}',
            label: t.cooking,
            color: AppColors.statusCooking,
          ),
          _Count(
            value: '${counts.toServe}',
            label: t.toServe,
            color: AppColors.statusReady,
          ),
          _Count(
            value: '${counts.cookedOrders}',
            label: t.cookedToday,
            detail: t.dishesCount(counts.cookedDishes),
            color: AppColors.statusCompleted,
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.value,
    required this.label,
    required this.color,
    this.detail,
  });

  final String value;
  final String label;
  final String? detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: tint(color),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  height: 1.1,
                  color: color,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                detail == null ? label : '$label  ·  $detail',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

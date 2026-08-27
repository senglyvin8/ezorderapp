import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../l10n/app_text.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';

class _TrackerStep {
  const _TrackerStep(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

List<_TrackerStep> _stepsFor(AppText t) => [
      _TrackerStep(
          t.stepReceived, Icons.receipt_long_rounded, AppColors.statusNew),
      _TrackerStep(t.stepCooking, Icons.local_fire_department_rounded,
          AppColors.statusCooking),
      _TrackerStep(
          t.stepReady, Icons.room_service_rounded, AppColors.statusReady),
      _TrackerStep(t.stepWaitingPayment, Icons.payments_rounded,
          AppColors.statusCooking),
      _TrackerStep(t.stepPaid, Icons.verified_rounded, AppColors.statusPaid),
    ];

/// Vertical progress tracker the customer watches while they wait.
///
/// It reads straight off the shared order, so a tap in the Kitchen or Cashier
/// view moves this tracker with no refresh.
class OrderTracker extends StatelessWidget {
  const OrderTracker(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final position = status.trackerIndex;
    final t = context.watch<AppStore>().text;
    final steps = _stepsFor(t);

    // A cancelled order never travels the ladder, so showing five dead steps
    // would only invite the question "which one is it on?".
    if (status == OrderStatus.cancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint(AppColors.danger),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cancel_rounded,
                size: 20, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.orderWasCancelled,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(t.askCashier, style: AppType.label),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            step: steps[i],
            done: i < position,
            current: i == position,
            isLast: i == steps.length - 1,
          ),
        if (status == OrderStatus.completed)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 44),
            child: Text(
              t.orderCompletedThanks,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: statusColor(OrderStatus.completed),
              ),
            ),
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.done,
    required this.current,
    required this.isLast,
  });

  final _TrackerStep step;
  final bool done;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final active = done || current;
    final color = active ? step.color : AppColors.inkFaint;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: current ? color : (done ? tint(color) : AppColors.surface),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? color : AppColors.border,
                    width: current ? 0 : 1.4,
                  ),
                ),
                child: Icon(
                  done ? Icons.check_rounded : step.icon,
                  size: 18,
                  color: current
                      ? Colors.white
                      : (done ? color : AppColors.inkFaint),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: done ? tint(step.color) : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 7, bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                      color: active ? AppColors.ink : AppColors.inkFaint,
                    ),
                  ),
                  if (current)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        context.watch<AppStore>().text.inProgress,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/app_text.dart';
import '../../models/plan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';

/// The three plans, and which one this restaurant is on.
///
/// There is no payment processing yet and this screen does not pretend
/// otherwise: it says what each plan gives you and how to change, and the
/// change is a conversation. A fake "Upgrade" button that took a card number
/// and did nothing would be worse than an honest one that does not.
class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final current = store.settings.plan;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: t.pricing,
        subtitle: '${t.currentPlan}: ${planLabel(current, t)}',
      ),
      body: PageWidth(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            for (final plan in Plan.values) ...[
              _PlanCard(
                plan: plan,
                current: plan == current,
                store: store,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            AppCard(
              color: AppColors.surface,
              elevated: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.inkFaint),
                  const SizedBox(width: 9),
                  Expanded(child: Text(t.howToUpgrade, style: AppType.label)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.current,
    required this.store,
  });

  final Plan plan;
  final bool current;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final price = plan.monthlyPrice == 0
        ? t.freeForever
        : t.perMonth('\$${plan.monthlyPrice.toStringAsFixed(2)}');

    return AppCard(
      borderColor: current ? AppColors.brand : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planLabel(plan, t),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              if (current)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    t.onThisPlan,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.brandDark,
            ),
          ),
          const SizedBox(height: 12),
          _Line(
            text: plan.hasUnlimitedTables
                ? t.tablesUnlimited
                : t.tablesLimit(plan.maxTables!),
          ),
          _Line(text: t.staffLimit(plan.maxStaff!)),
          _Line(text: t.ordersUnlimited),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded,
              size: 17, color: AppColors.statusReady),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 15, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Localised name of a plan. Kept out of [Plan] so the model has no dependency
/// on the string table, matching how order statuses are handled.
String planLabel(Plan plan, AppText t) => switch (plan) {
      Plan.free => t.planFree,
      Plan.basic => t.planBasic,
      Plan.pro => t.planPro,
    };

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/plan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../merchant.dart';
import '../platform_store.dart';
import 'new_merchant_sheet.dart';

/// Every restaurant on the platform, and the levers for each.
class MerchantsScreen extends StatefulWidget {
  const MerchantsScreen({super.key});

  @override
  State<MerchantsScreen> createState() => _MerchantsScreenState();
}

class _MerchantsScreenState extends State<MerchantsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlatformStore>().load();
    });
  }

  Future<void> _act(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) showToast(context, done);
    } on StateError catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlatformStore>();
    final money = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        automaticallyImplyLeading: false,
        title: 'Merchants',
        subtitle: store.signedInAs,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: store.loading ? null : store.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: store.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-merchant',
        onPressed: () => showNewMerchantSheet(context),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('New merchant'),
      ),
      body: store.error != null
          ? EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load merchants',
              message: store.error!,
              action: FilledButton(
                onPressed: store.load,
                child: const Text('Try again'),
              ),
            )
          : store.loading && store.merchants.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: store.load,
                  child: PageWidth(
                    maxWidth: 1000,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [
                        _PlatformTotals(store: store, money: money),
                        const SizedBox(height: 20),
                        SectionLabel(
                            '${store.merchantCount} restaurants'),
                        if (store.merchants.isEmpty)
                          const EmptyState(
                            icon: Icons.storefront_rounded,
                            title: 'No merchants yet',
                            message:
                                'Add the first one with the button below.',
                          )
                        else
                          for (final m in store.merchants) ...[
                            _MerchantCard(
                              merchant: m,
                              money: money,
                              onPlan: (plan) => _act(
                                () => store.setPlan(m, plan),
                                '${m.name} moved to ${plan.label}',
                              ),
                              onSuspend: (value) => _act(
                                () => store.setSuspended(m, value),
                                value
                                    ? '${m.name} suspended'
                                    : '${m.name} reinstated',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  ),
                ),
    );
  }
}

/// The numbers that answer "how is the business doing" without opening a
/// single merchant.
class _PlatformTotals extends StatelessWidget {
  const _PlatformTotals({required this.store, required this.money});

  final PlatformStore store;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, String, IconData, Color)>[
      ('Monthly recurring', money.format(store.monthlyRecurring),
          Icons.trending_up_rounded, AppColors.statusReady),
      ('Merchants', '${store.merchantCount}', Icons.storefront_rounded,
          AppColors.statusNew),
      ('Orders today', '${store.ordersToday}', Icons.receipt_long_rounded,
          AppColors.statusPaid),
      ('Taken today', money.format(store.revenueToday),
          Icons.payments_rounded, AppColors.brand),
      // The two worth acting on: who is pressed against a cap and might pay
      // more, and who signed up and never started.
      ('At a plan limit', '${store.atLimitCount}',
          Icons.trending_up_rounded, AppColors.statusCooking),
      ('Never ordered', '${store.dormantCount}',
          Icons.hourglass_empty_rounded, AppColors.inkFaint),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 760
            ? 3
            : constraints.maxWidth > 420
                ? 3
                : 2;
        final scale = MediaQuery.textScalerOf(context)
            .scale(1.0)
            .clamp(1.0, 1.3)
            .toDouble();
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6 / scale,
          children: [
            for (final tile in tiles)
              AppCard(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(tile.$3, size: 18, color: tile.$4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tile.$2,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                        Text(tile.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.label),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({
    required this.merchant,
    required this.money,
    required this.onPlan,
    required this.onSuspend,
  });

  final Merchant merchant;
  final NumberFormat money;
  final ValueChanged<Plan> onPlan;
  final ValueChanged<bool> onSuspend;

  @override
  Widget build(BuildContext context) {
    final m = merchant;
    return AppCard(
      borderColor: m.suspended ? AppColors.danger : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (m.suspended) ...[
                          const SizedBox(width: 8),
                          const _Tag(
                              label: 'Suspended', color: AppColors.danger),
                        ],
                        if (m.atAnyLimit && !m.suspended) ...[
                          const SizedBox(width: 8),
                          const _Tag(
                              label: 'At limit',
                              color: AppColors.statusCooking),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '/${m.slug}   ·   since '
                      '${DateFormat('d MMM yyyy').format(m.createdAt)}',
                      style: AppType.label,
                    ),
                  ],
                ),
              ),
              Text(
                money.format(m.revenueTotal),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Stat(
                label: 'Tables',
                value: m.plan.maxTables == null
                    ? '${m.tablesUsed}'
                    : '${m.tablesUsed} / ${m.plan.maxTables}',
                warn: m.atTableLimit,
              ),
              _Stat(
                label: 'Staff',
                value: '${m.staffUsed} / ${m.plan.maxStaff}',
                warn: m.atStaffLimit,
              ),
              _Stat(label: 'Orders', value: '${m.ordersTotal}'),
              _Stat(label: 'Today', value: '${m.ordersToday}'),
              _Stat(
                label: 'Last order',
                value: m.lastOrderAt == null
                    ? 'never'
                    : DateFormat('d MMM').format(m.lastOrderAt!),
                warn: m.lastOrderAt == null,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Text('Plan', style: AppType.label),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final plan in Plan.values)
                      _PlanChip(
                        plan: plan,
                        selected: plan == m.plan,
                        onTap: plan == m.plan ? null : () => onPlan(plan),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => onSuspend(!m.suspended),
                icon: Icon(
                  m.suspended
                      ? Icons.play_circle_rounded
                      : Icons.pause_circle_rounded,
                  size: 18,
                ),
                label: Text(m.suspended ? 'Reinstate' : 'Suspend'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      m.suspended ? AppColors.statusReady : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: warn ? AppColors.statusCooking : AppColors.ink,
          ),
        ),
        Text(label, style: AppType.label),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandDark : AppColors.inkSoft;
    return Material(
      color: selected ? AppColors.brandTint : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            plan.label,
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ),
    );
  }
}

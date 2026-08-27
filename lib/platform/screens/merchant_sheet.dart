import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/plan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../merchant.dart';
import '../platform_store.dart';
import 'merchants_screen.dart' show healthLabel, healthColor;

/// One merchant, in full, with the levers.
///
/// The list answers "who needs me"; this answers "what is going on with them
/// and what can I do about it".
Future<void> showMerchantSheet(BuildContext context, Merchant merchant) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _MerchantSheet(merchantId: merchant.id),
  );
}

class _MerchantSheet extends StatelessWidget {
  const _MerchantSheet({required this.merchantId});

  final String merchantId;

  Future<void> _act(
    BuildContext context,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      if (context.mounted) showToast(context, done);
    } on StateError catch (error) {
      if (context.mounted) showToast(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlatformStore>();
    final money = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final date = DateFormat('d MMM yyyy');

    // Read from the store each build rather than from the value passed in, so
    // the sheet updates itself after a plan change instead of showing what was
    // true when it opened.
    final m = store.merchants.where((e) => e.id == merchantId).firstOrNull;
    if (m == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final colour = healthColor(m.health);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: sheetMaxHeight(context)),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint(colour),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(m.logo, style: const TextStyle(fontSize: 23)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4),
                      ),
                      Text(healthLabel(m.health),
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: colour)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (m.setupGaps.isNotEmpty) ...[
              _Callout(
                color: AppColors.statusCooking,
                icon: Icons.build_rounded,
                title: 'They cannot take an order yet',
                body: 'Missing ${m.setupGaps.join(', ')}. Signed up '
                    '${m.daysSinceSignUp} days ago and has never traded. '
                    'Worth a call — this is usually somebody who did not '
                    'realise the menu was theirs to fill in.',
              ),
              const SizedBox(height: 14),
            ] else if (m.health == MerchantHealth.quiet) ...[
              _Callout(
                color: AppColors.statusPaid,
                icon: Icons.trending_down_rounded,
                title: 'No orders for ${m.daysSinceLastOrder} days',
                body: 'They were taking orders and have stopped. Worth asking '
                    'why before it becomes a cancellation.',
              ),
              const SizedBox(height: 14),
            ] else if (m.atAnyLimit && !m.suspended) ...[
              _Callout(
                color: AppColors.statusReady,
                icon: Icons.trending_up_rounded,
                title: 'Pressed against the ${m.plan.label} limit',
                body: m.atTableLimit
                    ? 'They have used all ${m.plan.maxTables} tables. If they '
                        'want another, the plan has to move.'
                    : 'They have used all ${m.plan.maxStaff} staff accounts.',
              ),
              const SizedBox(height: 14),
            ],

            const SectionLabel('Trade'),
            _Rows(rows: [
              ('Orders, all time', '${m.ordersTotal}'),
              ('Orders today', '${m.ordersToday}'),
              ('Orders, last 7 days', _trend(m)),
              ('Revenue, all time', money.format(m.revenueTotal)),
              ('Revenue, last 30 days', money.format(m.revenue30d)),
              (
                'Last order',
                m.lastOrderAt == null
                    ? 'never'
                    : '${date.format(m.lastOrderAt!)}  '
                        '(${m.daysSinceLastOrder} days ago)'
              ),
            ]),

            const SizedBox(height: 16),
            const SectionLabel('Setup'),
            _Rows(rows: [
              (
                'Tables',
                m.plan.maxTables == null
                    ? '${m.tablesUsed}'
                    : '${m.tablesUsed} of ${m.plan.maxTables}'
              ),
              ('Staff accounts', '${m.staffUsed} of ${m.plan.maxStaff}'),
              ('Menu categories', '${m.categories}'),
              ('Dishes', '${m.menuItems}'),
            ]),

            const SizedBox(height: 16),
            const SectionLabel('Account'),
            _Rows(rows: [
              ('Slug', '/${m.slug}'),
              ('Owner signs in as', m.ownerUsername.isEmpty
                  ? '—'
                  : m.ownerUsername),
              ('Phone', m.phone.isEmpty ? 'not set' : m.phone),
              ('Address', m.address.isEmpty ? 'not set' : m.address),
              ('Signed up',
                  '${date.format(m.createdAt)}  (${m.daysSinceSignUp} days)'),
            ]),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text: 'https://ezorder-pearl.vercel.app/#/order/${m.slug}'
                        '/table/01'));
                showToast(context, 'Table 01 link copied');
              },
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Copy their table 01 link'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
              ),
            ),

            const SizedBox(height: 20),
            const SectionLabel('Plan'),
            Row(
              children: [
                for (final plan in Plan.values) ...[
                  Expanded(
                    child: _PlanButton(
                      plan: plan,
                      selected: plan == m.plan,
                      onTap: plan == m.plan
                          ? null
                          : () => _act(
                                context,
                                () => store.setPlan(m, plan),
                                '${m.name} moved to ${plan.label}',
                              ),
                    ),
                  ),
                  if (plan != Plan.values.last) const SizedBox(width: 8),
                ],
              ],
            ),

            const SizedBox(height: 20),
            const SectionLabel('Access'),
            Text(
              m.suspended
                  ? 'Customers cannot place orders. Staff can still sign in '
                      'and read their history.'
                  : 'Suspending stops new orders. Staff keep their access, so '
                      'they can still close out what is already on the floor.',
              style: AppType.label,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _act(
                context,
                () => store.setSuspended(m, !m.suspended),
                m.suspended
                    ? '${m.name} reinstated'
                    : '${m.name} suspended',
              ),
              icon: Icon(m.suspended
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded),
              label: Text(m.suspended ? 'Reinstate' : 'Suspend'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor:
                    m.suspended ? AppColors.statusReady : AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _trend(Merchant m) {
    final change = m.weeklyTrend;
    if (change == null) return '${m.orders7d}';
    final pct = (change * 100).round();
    final arrow = pct > 0 ? '▲' : (pct < 0 ? '▼' : '');
    return '${m.orders7d}   $arrow ${pct.abs()}% vs the week before';
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      color: AppColors.surface,
      elevated: false,
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(row.$1, style: AppType.label)),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint(color),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const SizedBox(height: 3),
                Text(body,
                    style: const TextStyle(fontSize: 13.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanButton extends StatelessWidget {
  const _PlanButton({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? AppColors.brandDark : AppColors.inkSoft;
    return Material(
      color: selected ? AppColors.brandTint : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(plan.label,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: ink)),
              Text(
                plan.monthlyPrice == 0
                    ? 'free'
                    : '\$${plan.monthlyPrice.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12.5, color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

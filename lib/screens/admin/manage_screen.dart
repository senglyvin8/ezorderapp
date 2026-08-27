import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/upgrade_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/plan_meter.dart';
import 'admin_menu_screen.dart';
import 'admin_settings_screen.dart';
import 'pricing_screen.dart';
import 'admin_tables_screen.dart';
import 'staff_screen.dart';

/// Configuration, kept off the main tabs so daily operations stay one tap
/// away and setup lives behind a door.
class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;

    void open(Widget screen) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => screen),
        );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        automaticallyImplyLeading: false,
        title: t.more,
        subtitle: store.restaurantDisplayName,
      ),
      body: PageWidth(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _PlanUsage(store: store),
            const SizedBox(height: 14),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Row(
                    icon: Icons.restaurant_menu_rounded,
                    label: t.menu,
                    detail: t.menuSummary(
                        store.menuItems.length, store.sortedCategories.length),
                    onTap: () => open(const AdminMenuScreen()),
                  ),
                  const Divider(),
                  _Row(
                    icon: Icons.table_bar_rounded,
                    label: t.tablesAndQr,
                    detail: t.tablesSummary(
                      store.tables.length,
                      store.tables
                          .where((e) => store.isTableOccupied(e.id))
                          .length,
                    ),
                    onTap: () => open(const AdminTablesScreen()),
                  ),
                  const Divider(),
                  _Row(
                    icon: Icons.badge_rounded,
                    label: t.staff,
                    detail: t.staffCount(store.accounts.length),
                    onTap: () => open(const StaffScreen()),
                  ),
                  const Divider(),
                  _Row(
                    icon: Icons.settings_rounded,
                    label: t.settings,
                    detail: t.settingsSubtitle,
                    onTap: () => open(const AdminSettingsScreen()),
                  ),
                  const Divider(),
                  _Row(
                    icon: Icons.workspace_premium_rounded,
                    label: t.pricing,
                    detail: planLabel(store.settings.plan, t),
                    onTap: () => open(const PricingScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 15, 12, 15),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.small),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 19, color: AppColors.inkSoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppType.cardTitle),
                  const SizedBox(height: 2),
                  Text(detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// What plan this restaurant is on and how much of it is spoken for.
///
/// Sits at the top of Manage because the answer to "why can I not add another
/// table?" should be visible before the attempt, not only after it fails.
class _PlanUsage extends StatelessWidget {
  const _PlanUsage({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final plan = store.settings.plan;
    final tables = store.tables.length;
    final staff = store.accounts.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  size: 19, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${t.currentPlan}  ·  ${planLabel(plan, t)}',
                  style: AppType.cardTitle,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const PricingScreen()),
                ),
                child: Text(plan.next == null ? t.viewPlans : t.upgrade),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PlanMeter(
            label: t.tables,
            used: tables,
            limit: plan.maxTables,
            store: store,
            reason: UpgradeReason.tableCap,
            card: false,
          ),
          const SizedBox(height: 10),
          PlanMeter(
            label: t.staffAccounts,
            used: staff,
            limit: plan.maxStaff,
            store: store,
            reason: UpgradeReason.staffCap,
            card: false,
          ),
        ],
      ),
    );
  }
}


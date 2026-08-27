import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/app_theme.dart';
import '../cashier/cashier_root.dart';
import '../kitchen/kitchen_root.dart';
import 'admin_dashboard_screen.dart';
import 'admin_orders_screen.dart';
import 'manage_screen.dart';

/// The owner's workspace.
///
/// An admin can do everything, so the kitchen and cashier screens sit on the
/// main tabs beside the dashboard, and setup lives behind Manage.
class AdminRoot extends StatefulWidget {
  const AdminRoot({super.key});

  @override
  State<AdminRoot> createState() => _AdminRootState();
}

class _AdminRootState extends State<AdminRoot> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppStore>().text;
    final destinations = [
      (icon: Icons.dashboard_rounded, label: t.dashboard),
      (icon: Icons.soup_kitchen_rounded, label: t.kitchen),
      (icon: Icons.point_of_sale_rounded, label: t.roleCashier),
      (icon: Icons.receipt_long_rounded, label: t.orders),
      (icon: Icons.tune_rounded, label: t.more),
    ];

    const pages = [
      AdminDashboardScreen(),
      KitchenRoot(),
      CashierRoot(),
      AdminOrdersScreen(),
      ManageScreen(),
    ];

    final wide = MediaQuery.sizeOf(context).width >= 820;
    final body = IndexedStack(index: _index, children: pages);

    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppColors.card,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              indicatorColor: AppColors.brandTint,
              selectedIconTheme:
                  const IconThemeData(color: AppColors.brandDark, size: 24),
              unselectedIconTheme:
                  const IconThemeData(color: AppColors.inkSoft, size: 24),
              selectedLabelTextStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.brandDark,
              ),
              unselectedLabelTextStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSoft,
              ),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}

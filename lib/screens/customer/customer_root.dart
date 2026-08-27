import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/app_theme.dart';
import 'cart_screen.dart';
import 'menu_screen.dart';
import 'qr_entry_screen.dart';
import 'track_order_screen.dart';

/// Customer experience: scan a table, browse, order, watch the tracker.
/// No account, no login — Rule 1.
class CustomerRoot extends StatefulWidget {
  const CustomerRoot({super.key});

  @override
  State<CustomerRoot> createState() => _CustomerRootState();
}

class _CustomerRootState extends State<CustomerRoot> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;

    if (!store.hasCustomerSession) {
      return const QrEntryScreen();
    }

    final cartCount = store.cartItemCount;
    final openOrders = store.myOrders.where((o) => o.status.isActive).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: IndexedStack(
        index: _index,
        children: [
          MenuScreen(onOpenCart: () => _goTo(1), onLeaveTable: () => _goTo(0)),
          CartScreen(
            onBrowseMenu: () => _goTo(0),
            onTrackOrder: () => _goTo(2),
          ),
          const TrackOrderScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: t.menu,
          ),
          NavigationDestination(
            icon: _Badged(count: cartCount, child: const Icon(Icons.shopping_bag_outlined)),
            selectedIcon:
                _Badged(count: cartCount, child: const Icon(Icons.shopping_bag_rounded)),
            label: t.cart,
          ),
          NavigationDestination(
            icon: _Badged(
              count: openOrders,
              color: AppColors.statusReady,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: _Badged(
              count: openOrders,
              color: AppColors.statusReady,
              child: const Icon(Icons.receipt_long_rounded),
            ),
            label: t.myOrderTab,
          ),
        ],
      ),
    );
  }
}

class _Badged extends StatelessWidget {
  const _Badged({required this.child, required this.count, this.color});

  final Widget child;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -8,
          top: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 17),
            decoration: BoxDecoration(
              color: color ?? AppColors.brand,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.card, width: 1.5),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

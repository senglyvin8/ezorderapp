import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'data/app_store.dart';
import 'screens/admin/admin_root.dart';
import 'screens/cashier/cashier_root.dart';
import 'screens/customer/customer_root.dart';
import 'screens/kitchen/kitchen_root.dart';
import 'screens/table_entry_page.dart';
import 'models/staff_account.dart';
import 'theme/app_theme.dart';
import 'widgets/session_bar.dart';

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Brand.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Honour the reader's own text-size setting — someone who has turned
      // text up on their phone gets it here too — but cap it, because a
      // kitchen ticket that no longer fits its card helps nobody.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler
                .clamp(minScaleFactor: 1.0, maxScaleFactor: Style.maxTextScale),
          ),
          child: child!,
        );
      },
      onGenerateRoute: _onGenerateRoute,
    );
  }

  /// Handles the deep links a table QR code encodes, for example
  /// `/order/demo/table/05` (and the equivalent `/restaurant/demo/table/05`).
  /// Anything else lands on the demo shell.
  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');
    final segments = uri.pathSegments;
    final isTableLink = segments.length == 4 &&
        (segments[0] == 'order' || segments[0] == 'restaurant') &&
        segments[2] == 'table';

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => isTableLink
          ? TableEntryPage(tableNumber: segments[3])
          : const AppShell(),
    );
  }
}

/// Chooses what to show: the anonymous customer experience, or the workspace
/// of whoever is signed in.
///
/// Access is decided here *and* enforced in [AppStore], so a hidden button is
/// never the only thing keeping a cashier out of the menu editor.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser;
    final staffMode = store.mode == AppMode.staff && user != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const SessionBar(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: staffMode
                  ? _workspaceFor(user.role)
                  : const CustomerRoot(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceFor(StaffRole role) => switch (role) {
        StaffRole.admin => const AdminRoot(),
        StaffRole.kitchen => const KitchenRoot(),
        StaffRole.cashier => const CashierRoot(),
      };
}

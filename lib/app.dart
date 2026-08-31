import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'data/app_store.dart';
import 'data/guest_mode.dart';
import 'data/merchant_binding.dart';
import 'screens/admin/admin_root.dart';
import 'screens/cashier/cashier_root.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/customer/customer_root.dart';
import 'screens/kitchen/kitchen_root.dart';
import 'screens/table_entry_page.dart';
import 'models/staff_account.dart';
import 'models/table_link.dart';
import 'theme/app_theme.dart';
import 'widgets/guest_banner.dart';
import 'widgets/session_bar.dart';

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key, this.onRebind, this.guest = false});

  /// How to point this device at another merchant, when that is something this
  /// build can do at all. Null on the demo and on a build compiled for one
  /// restaurant; the sign-in screen hides the affordance rather than offering
  /// one that cannot work.
  final Future<void> Function()? onRebind;

  /// True while this device is looking round the demo rather than running a
  /// restaurant. Drives the banner that says so.
  final bool guest;

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
        return Provider<RebindDevice?>.value(
          // Always provided, sometimes null: a screen deep in the tree can ask
          // for it without having to know whether this build has one.
          value: onRebind == null ? null : RebindDevice(onRebind!),
          child: Provider<GuestSession>.value(
            value: GuestSession(guest),
            child: MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                  minScaleFactor: 1.0, maxScaleFactor: Style.maxTextScale),
            ),
              child: child!,
            ),
          ),
        );
      },
      onGenerateRoute: _onGenerateRoute,
      // A scanned sticker is one destination, not a trail.
      //
      // Flutter's default reads `/order/demo/table/05` as a path to walk and
      // builds a route for every prefix of it — `/`, `/order`, `/order/demo`,
      // `/order/demo/table` — leaving the diner on the menu with four dead
      // screens stacked underneath, and the transitions fighting each other
      // hard enough to throw during layout. Nobody navigated through those
      // screens; they pointed a camera at a table.
      onGenerateInitialRoutes: (initialRoute) =>
          [_onGenerateRoute(RouteSettings(name: initialRoute))],
    );
  }

  /// Handles the deep links a table QR code encodes, for example
  /// `/order/demo/table/05` (and the equivalent `/restaurant/demo/table/05`).
  /// Anything else lands on the demo shell.
  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final link = TableLink.parse(settings.name);

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => link == null
          ? const AppShell()
          : TableEntryPage(tableNumber: link.tableNumber),
    );
  }
}

/// Chooses what to show: the anonymous customer experience, or the workspace
/// of whoever is signed in.
///
/// Access is decided here *and* enforced in [AppStore], so a hidden button is
/// never the only thing keeping a cashier out of the menu editor.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Set when somebody on the sign-in screen says they are a customer.
  ///
  /// Staff need the customer view — to demo it, or to order for a walk-in —
  /// and on an installed build the sign-in screen is the only thing in front
  /// of them. It lasts until the app is reopened, which is the right lifetime:
  /// a tablet that gets restarted should be asking for a PIN again.
  bool _asCustomer = false;

  /// Whether to meet this person with sign-in rather than a menu.
  ///
  /// An installed app is a staff device. Somebody who went to an app store,
  /// downloaded this and opened it is a member of staff or an owner — a diner
  /// never installs anything, they point a camera at a table.
  ///
  /// The web build is the opposite and must stay that way: it is what the QR
  /// codes open, so it belongs to the diner. Meeting a takeaway customer with
  /// a password box would break the one thing the product is for. A scanned
  /// link is already past this either way, because it opens a table and so
  /// starts a customer session before the shell is built.
  bool _staffGate(AppStore store) =>
      !kIsWeb &&
      !store.isSignedIn &&
      !store.hasCustomerSession &&
      !_asCustomer;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser;
    final staffMode = store.mode == AppMode.staff && user != null;

    if (_staffGate(store)) {
      return SignInScreen(
        onBrowseAsCustomer: () => setState(() => _asCustomer = true),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const GuestBanner(),
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

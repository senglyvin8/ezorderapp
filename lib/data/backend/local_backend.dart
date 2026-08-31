import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/cart_line.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';
import '../../models/order.dart';
import '../../models/restaurant_settings.dart';
import '../../config/app_config.dart';
import '../../models/email_address.dart';
import '../../models/plan.dart';
import '../../models/restaurant_table.dart';
import '../../models/staff_account.dart';
import '../../models/upgrade_request.dart';
import '../demo_data.dart';
import 'backend.dart';

/// The restaurant, kept on this device.
///
/// This is the demo: a seeded menu, seeded staff and a day's worth of orders,
/// mirrored into SharedPreferences so a reload picks up where it left off. It
/// is also what the test suite runs against, which is why the rules are
/// implemented here in full rather than stubbed — a guard that only exists in
/// Postgres is a guard the tests cannot see.
///
/// Everything is synchronous underneath; the Futures are there because the
/// interface has to fit a real database too.
class LocalBackend implements Backend {
  LocalBackend();

  static const String _prefsKey = 'rqo_data_v5';

  SharedPreferences? _prefs;
  int _idCounter = 0;

  RestaurantSettings _settings = DemoData.settings();
  List<MenuCategory> _categories = DemoData.categories();
  List<MenuItem> _menuItems = DemoData.menuItems();
  List<RestaurantTable> _tables = DemoData.tables();
  List<Order> _orders = [];
  List<StaffAccount> _accounts = [];
  int _nextOrderNumber = DemoData.nextOrderNumber();
  String? _currentUserId;
  UpgradeRequest? _upgradeRequest;

  /// Nobody is running a platform behind a demo on one phone, so the contact
  /// details are the compile-time ones. On Supabase they come from the
  /// database and can change without an app release.
  static const SupportContact _support = SupportContact(
    phone: Support.phone,
    telegram: Support.telegram,
    hours: Support.hours,
  );

  @override
  bool get isDemo => true;

  /// Nothing else is writing to this device, so there is never anything to
  /// hear about.
  @override
  Stream<RestaurantData> get changes => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  StaffAccount? get currentUser =>
      _accounts.where((a) => a.id == _currentUserId).firstOrNull;

  @override
  RestaurantData get current => RestaurantData(
        settings: _settings,
        categories: _categories,
        menuItems: _menuItems,
        tables: _tables,
        orders: _orders,
        accounts: _accounts,
        support: _support,
        upgradeRequest: _upgradeRequest,
      );

  // ------------------------------------------------------------ persistence

  @override
  Future<RestaurantData> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_prefsKey);
    if (raw == null) {
      _seedDemo();
      await _persist();
    } else {
      try {
        _restore(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A malformed snapshot should never block the demo.
        _seedDemo();
        await _persist();
      }
    }
    return current;
  }

  /// Nothing else is writing to this device, so there is never anything new to
  /// read. Harmless, and it keeps the screens from having to know which
  /// backend they are talking to.
  @override
  Future<void> refresh() async {}

  void _seedDemo() {
    _accounts = DemoData.accounts();
    _currentUserId = null;
    _settings = DemoData.settings();
    _categories = DemoData.categories();
    _menuItems = DemoData.menuItems();
    _tables = DemoData.tables();
    _orders = DemoData.orders(DateTime.now());
    _nextOrderNumber = DemoData.nextOrderNumber();
    _upgradeRequest = null;
  }

  void _restore(Map<String, dynamic> json) {
    _settings =
        RestaurantSettings.fromJson(json['settings'] as Map<String, dynamic>);
    // A snapshot written before merchant IDs existed has none. The demo has
    // exactly one restaurant and its code is a constant, so it can simply be
    // filled in — the alternative is an installed demo that never shows the
    // feature until somebody wipes it.
    if (_settings.code.isEmpty) {
      _settings = _settings.copyWith(code: Brand.merchantCode);
    }
    _categories = (json['categories'] as List<dynamic>)
        .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    _menuItems = (json['menuItems'] as List<dynamic>)
        .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
        .toList();
    _tables = (json['tables'] as List<dynamic>)
        .map((e) => RestaurantTable.fromJson(e as Map<String, dynamic>))
        .toList();
    _orders = (json['orders'] as List<dynamic>)
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
    _nextOrderNumber = (json['nextOrderNumber'] as num).toInt();
    _accounts = (json['accounts'] as List<dynamic>? ?? const [])
        .map((e) => StaffAccount.fromJson(e as Map<String, dynamic>))
        .toList();
    if (_accounts.isEmpty) _accounts = DemoData.accounts();
    _currentUserId = json['currentUserId'] as String?;
    final request = json['upgradeRequest'];
    _upgradeRequest = request == null
        ? null
        : UpgradeRequest.fromJson(request as Map<String, dynamic>);
  }

  Map<String, dynamic> _snapshot() => {
        'settings': _settings.toJson(),
        'categories': _categories.map((e) => e.toJson()).toList(),
        'menuItems': _menuItems.map((e) => e.toJson()).toList(),
        'tables': _tables.map((e) => e.toJson()).toList(),
        'orders': _orders.map((e) => e.toJson()).toList(),
        'nextOrderNumber': _nextOrderNumber,
        'accounts': _accounts.map((e) => e.toJson()).toList(),
        'currentUserId': _currentUserId,
        if (_upgradeRequest != null) 'upgradeRequest': _upgradeRequest!.toJson(),
      };

  Future<void> _persist() async {
    await _prefs?.setString(_prefsKey, jsonEncode(_snapshot()));
  }

  /// Mutations are synchronous here; the write rides along behind them rather
  /// than making every caller wait on a disk round trip.
  void _commit() => unawaited(_persist());

  String _uid(String prefix) {
    _idCounter++;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  @override
  Future<void> resetDemoData() async {
    _require(_canManage, 'reset the demo data');
    _seedDemo();
    // _seedDemo replaces the account list, so the id we were signed in with no
    // longer exists. Without this the admin who pressed the button is silently
    // signed out and left on a settings screen they are no longer allowed to
    // be on. Land them back on the seeded admin instead.
    _currentUserId = _accounts
        .where((a) => a.role == StaffRole.admin && a.active)
        .firstOrNull
        ?.id;
    await _persist();
  }

  // ------------------------------------------------------ accounts & access

  bool get _canManage => currentUser?.role.canManageRestaurant ?? false;
  bool get _canCook => currentUser?.role.canWorkKitchen ?? false;
  bool get _canTakePayment => currentUser?.role.canTakePayment ?? false;

  /// Guard used by every staff-only mutation.
  ///
  /// Permissions are checked here rather than only in the UI, so hiding a
  /// button is not the thing keeping a cashier out of the menu editor.
  void _require(bool allowed, String action) {
    if (!allowed) {
      throw StateError(
        currentUser == null
            ? 'Sign in to $action'
            : '${currentUser!.name} is not allowed to $action',
      );
    }
  }

  @override
  Future<StaffAccount?> signInWithPassword(
      String identifier, String password) async {
    // Hashing is deliberately slow; yielding first lets the caller paint a
    // progress state before the main thread blocks on it.
    await Future<void>.delayed(Duration.zero);
    // Either identifier reaches the same account: an owner types the address
    // they were given, and one who has been signing in with a username for a
    // year carries on doing that.
    final typed = identifier.trim().toLowerCase();
    final account = _accounts
        .where((a) =>
            a.usesPassword &&
            a.active &&
            typed.isNotEmpty &&
            (a.email.toLowerCase() == typed ||
                a.username.toLowerCase() == typed))
        .firstOrNull;
    if (account == null || !account.verify(password)) return null;
    _currentUserId = account.id;
    _commit();
    return account;
  }

  @override
  Future<StaffAccount?> signInWithPin(String accountId, String pin) async {
    await Future<void>.delayed(Duration.zero);
    final account = _accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null || !account.verify(pin)) return null;
    _currentUserId = account.id;
    _commit();
    return account;
  }

  /// There is no email on a device with no service behind it, so there is
  /// nothing to send and nobody to send it. Said plainly rather than failing
  /// silently: the demo prints its own credentials on the sign-in screen, so
  /// nobody using it is actually locked out.
  @override
  Future<void> sendPasswordReset(String email) async {
    throw StateError(
      'The demo has no email behind it. The sign-in details are on this screen.',
    );
  }

  @override
  Future<void> setNewPassword(String password) async {
    throw StateError('The demo has no password reset.');
  }

  @override
  Future<void> requestSignUp({
    required String email,
    required String password,
    required String restaurantName,
    required String slug,
    String ownerName = '',
  }) async {
    throw StateError('The demo restaurant is the only one on this device.');
  }

  @override
  Future<SignUpRequest?> mySignUpRequest() async => null;

  @override
  Future<bool> slugAvailable(String slug) async => false;

  @override
  Stream<void> get passwordRecovery => const Stream.empty();

  @override
  Future<void> signOut() async {
    _currentUserId = null;
    _commit();
  }

  @override
  Future<StaffAccount> addStaff({
    required String name,
    required StaffRole role,
    required String secret,
    String username = '',
    String email = '',
  }) async {
    _require(_canManage, 'manage staff');
    // Mirrors the trigger in 0006_plans.sql. Counts everyone with an account,
    // including anyone switched off: a deactivated account still occupies a
    // seat, and counting only active staff would make the cap evadable.
    final plan = _settings.plan;
    if (!plan.canAddStaff(_accounts.length)) {
      throw StateError(
        'The ${plan.label} plan allows ${plan.maxStaff} staff accounts. '
        'Upgrade to add more.',
      );
    }
    final address = EmailAddress.normalize(email);

    // Which of the two this account is, decided by whether an address was
    // given rather than by role. Somebody with their own phone gets an address
    // and a password; somebody sharing the counter tablet gets a PIN.
    if (address == null && email.trim().isNotEmpty) {
      throw StateError('That does not look like an email address');
    }
    if (address != null) {
      if (secret.trim().length < 8) {
        throw StateError('A password must be at least 8 characters');
      }
    } else if (role != StaffRole.admin) {
      if (secret.length != StaffAccount.pinLength) {
        throw StateError('A PIN must be ${StaffAccount.pinLength} digits');
      }
    }

    if (role == StaffRole.admin) {
      // An owner signs in with an address, so there has to be one. The older
      // username form is still accepted for the accounts that already have it,
      // which is why this is not simply "an admin needs an email".
      if (address == null && username.trim().isEmpty) {
        throw StateError('An owner needs an email address to sign in with');
      }
    }

    // Sign-in matches the *first* account with the identifier typed, so a
    // duplicate would lock the second admin out for good with nothing on
    // screen to explain why. PINs need no such check: staff are picked by name
    // first, so the PIN is only ever verified against the chosen account.
    final wanted = username.trim().toLowerCase();
    if (wanted.isNotEmpty &&
        _accounts.any((a) => a.username.toLowerCase() == wanted)) {
      throw StateError('Another account already uses that username');
    }
    if (address != null &&
        _accounts.any((a) => a.email.toLowerCase() == address)) {
      throw StateError('Another account already uses that email address');
    }

    final account = StaffAccount.create(
      id: _uid('staff'),
      name: name.trim(),
      role: role,
      secret: secret,
      username: username.trim(),
      email: address ?? '',
    );
    _accounts = [..._accounts, account];
    _commit();
    return account;
  }

  @override
  Future<void> setMyLoginEmail(String email) async {
    _require(_canManage, 'change the sign-in email');
    final address = EmailAddress.normalize(email);
    if (address == null) {
      throw StateError('That does not look like an email address');
    }
    final me = currentUser;
    if (me == null) throw StateError('Sign in first');
    if (_accounts.any((a) => a.id != me.id && a.email.toLowerCase() == address)) {
      throw StateError('Another account already uses that email address');
    }
    _accounts = _accounts
        .map((a) => a.id == me.id ? a.copyWith(email: address) : a)
        .toList();
    _commit();
  }

  @override
  Future<void> renameStaff(String id, String name) async {
    _require(_canManage, 'manage staff');
    _accounts =
        _accounts.map((a) => a.id == id ? a.copyWith(name: name) : a).toList();
    _commit();
  }

  @override
  Future<void> resetStaffSecret(String id, String secret) async {
    _require(_canManage, 'manage staff');
    final target = _accounts.where((a) => a.id == id).firstOrNull;
    if (target != null &&
        !target.usesPassword &&
        secret.length != StaffAccount.pinLength) {
      throw StateError('A PIN must be ${StaffAccount.pinLength} digits');
    }
    _accounts =
        _accounts.map((a) => a.id == id ? a.withSecret(secret) : a).toList();
    _commit();
  }

  @override
  Future<void> setStaffActive(String id, bool active) async {
    _require(_canManage, 'manage staff');
    if (!active) _guardLastAdmin(id);
    _accounts = _accounts
        .map((a) => a.id == id ? a.copyWith(active: active) : a)
        .toList();
    if (!active && _currentUserId == id) _currentUserId = null;
    _commit();
  }

  @override
  Future<void> deleteStaff(String id) async {
    _require(_canManage, 'manage staff');
    if (id == _currentUserId) {
      throw StateError('You cannot delete the account you are signed in with');
    }
    _guardLastAdmin(id);
    _accounts = _accounts.where((a) => a.id != id).toList();
    _commit();
  }

  /// Locking every admin out of the app would be unrecoverable without a
  /// server to reset from, so the last active admin is protected.
  void _guardLastAdmin(String id) {
    final target = _accounts.where((a) => a.id == id).firstOrNull;
    if (target == null || target.role != StaffRole.admin) return;
    final remaining = _accounts
        .where((a) => a.role == StaffRole.admin && a.active && a.id != id)
        .length;
    if (remaining == 0) {
      throw StateError('There must be at least one active admin');
    }
  }

  // ----------------------------------------------------------------- orders

  @override
  Future<Order> placeOrder({
    required OrderType type,
    String? tableId,
    required List<CartLine> lines,
    String note = '',
    bool onBehalfOfCustomer = false,
    String? clientKey,
  }) async {
    // Mirrors the lookup in place_order() — 0013. Nothing on one device races
    // itself, but the outbox retries through this path too, and an order that
    // arrives twice should still be placed once.
    if (clientKey != null) {
      final already = _orders.where((o) => o.clientKey == clientKey).firstOrNull;
      if (already != null) return already;
    }
    if (onBehalfOfCustomer) {
      _require(_canTakePayment, 'take an order for a customer');
    }
    if (lines.isEmpty) {
      throw StateError('The cart is empty');
    }
    final table = type.needsTable
        ? _tables.where((t) => t.id == tableId).firstOrNull
        : null;
    if (type.needsTable && table == null) {
      throw StateError(onBehalfOfCustomer
          ? 'Pick a table for a dine-in order'
          : 'No table selected — scan a table QR first');
    }

    // Mirrors the checks in place_order() — 0008_platform.sql. A cart is a
    // snapshot taken when the dish was tapped, and the menu moves on without
    // it: a dish sells out while the customer reads the rest of the menu, or
    // the owner deletes one while a phone still holds it. Checking only at
    // add-to-cart time sends the kitchen food it cannot cook.
    final items = lines.map((l) {
      final item = _menuItems.where((m) => m.id == l.foodId).firstOrNull;
      if (item == null) {
        throw StateError('That dish is not on this menu');
      }
      if (!item.available) {
        throw StateError('${item.name} is sold out');
      }
      return OrderItem(
        id: _uid('item'),
        foodId: l.foodId,
        name: l.name,
        nameKm: l.nameKm,
        price: l.price,
        // As in the SQL: a line is worth at least one of the dish, so a
        // quantity of zero or less can never bill or feed anybody.
        quantity: l.quantity < 1 ? 1 : l.quantity,
        note: l.note,
      );
    }).toList();
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
    final clean = note.trim();

    final order = Order(
      id: _uid('order'),
      orderNumber: '${_nextOrderNumber++}',
      type: type,
      tableId: table?.id,
      tableNumber: table?.number,
      items: items,
      subtotal: subtotal,
      total: subtotal,
      customerNote: clean.isEmpty ? null : clean,
      status: OrderStatus.newOrder,
      createdAt: DateTime.now(),
      placedBy: onBehalfOfCustomer ? currentUser?.name : null,
      clientKey: clientKey,
    );

    _orders = [..._orders, order];
    _commit();
    return order;
  }

  void _transition(String orderId, OrderStatus from, OrderStatus to,
      {String? paymentMethod, bool stampPaidAt = false}) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) throw StateError('Unknown order');
    final current = _orders[index];
    if (current.status != from) {
      throw StateError(
        'Order #${current.orderNumber} is ${current.status.label}, '
        'it cannot move to ${to.label}',
      );
    }
    _orders = [..._orders]
      ..[index] = current.copyWith(
        status: to,
        paymentMethod: paymentMethod,
        paidAt: stampPaidAt ? DateTime.now() : null,
      );
    _commit();
  }

  @override
  Future<void> startCooking(String orderId) async {
    _require(_canCook, 'work the kitchen');
    _transition(orderId, OrderStatus.newOrder, OrderStatus.cooking);
  }

  @override
  Future<void> markReady(String orderId) async {
    _require(_canCook, 'work the kitchen');
    _transition(orderId, OrderStatus.cooking, OrderStatus.ready);
  }

  @override
  Future<void> collectPayment(String orderId, String paymentMethod) async {
    _require(_canTakePayment, 'take payment');
    _transition(
      orderId,
      OrderStatus.ready,
      OrderStatus.paid,
      paymentMethod: paymentMethod,
      stampPaidAt: true,
    );
  }

  @override
  Future<void> completeOrder(String orderId) async {
    _require(_canTakePayment, 'close an order');
    _transition(orderId, OrderStatus.paid, OrderStatus.completed);
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    _require(_canTakePayment, 'cancel an order');
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) throw StateError('Unknown order');
    final current = _orders[index];
    if (!current.status.isCancellable) {
      throw StateError(
        'Order #${current.orderNumber} is ${current.status.label}, '
        'it is too late to cancel it',
      );
    }
    _orders = [..._orders]
      ..[index] = current.copyWith(
        status: OrderStatus.cancelled,
        cancelledBy: currentUser?.name,
        cancelledAt: DateTime.now(),
      );
    _commit();
  }

  @override
  Future<void> setOrderItemQuantity(
      String orderId, String itemId, int quantity) async {
    _require(_canTakePayment, 'change an order');
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) throw StateError('Unknown order');
    final current = _orders[index];
    if (!current.status.isCancellable) {
      throw StateError(
        'Order #${current.orderNumber} is ${current.status.label}, '
        'it can no longer be changed',
      );
    }
    final itemIndex = current.items.indexWhere((i) => i.id == itemId);
    if (itemIndex < 0) throw StateError('That dish is not on this order');
    if (quantity <= 0 && current.items.length == 1) {
      throw StateError(
        'That is the only dish left — cancel order '
        '#${current.orderNumber} instead',
      );
    }

    final items = [...current.items];
    if (quantity <= 0) {
      items.removeAt(itemIndex);
    } else {
      items[itemIndex] = items[itemIndex].copyWith(quantity: quantity);
    }
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
    _orders = [..._orders]
      ..[index] = current.copyWith(
        items: items,
        subtotal: subtotal,
        total: subtotal,
      );
    _commit();
  }

  // ------------------------------------------------------------- menu admin

  @override
  Future<void> addMenuItem(MenuItem item) async {
    _require(_canManage, 'edit the menu');
    _menuItems = [
      ..._menuItems,
      MenuItem(
        id: _uid('food'),
        name: item.name,
        nameKm: item.nameKm,
        description: item.description,
        descriptionKm: item.descriptionKm,
        price: item.price,
        categoryId: item.categoryId,
        image: item.image,
        photo: item.photo,
        discountPercent: item.discountPercent,
        available: item.available,
        popular: item.popular,
        signature: item.signature,
      ),
    ];
    _commit();
  }

  @override
  Future<void> updateMenuItem(MenuItem item) async {
    _require(_canManage, 'edit the menu');
    _menuItems = _menuItems.map((m) => m.id == item.id ? item : m).toList();
    _commit();
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    _require(_canManage, 'edit the menu');
    _menuItems = _menuItems.where((m) => m.id != id).toList();
    _commit();
  }

  @override
  Future<void> setItemAvailability(String id, bool available) async {
    _require(_canManage, 'edit the menu');
    _menuItems = _menuItems
        .map((m) => m.id == id ? m.copyWith(available: available) : m)
        .toList();
    _commit();
  }

  @override
  Future<MenuCategory> addCategory(String name, {String nameKm = ''}) async {
    _require(_canManage, 'edit the menu');
    final nextOrder = _categories.isEmpty
        ? 1
        : _categories.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) +
            1;
    final category = MenuCategory(
      id: _uid('cat'),
      name: name,
      nameKm: nameKm,
      sortOrder: nextOrder,
    );
    _categories = [..._categories, category];
    _commit();
    return category;
  }

  @override
  Future<void> renameCategory(String id, String name,
      {String nameKm = ''}) async {
    _require(_canManage, 'edit the menu');
    _categories = _categories
        .map((c) => c.id == id ? c.copyWith(name: name, nameKm: nameKm) : c)
        .toList();
    _commit();
  }

  /// Removes a category together with the dishes filed under it.
  @override
  Future<void> deleteCategory(String id) async {
    _require(_canManage, 'edit the menu');
    _categories = _categories.where((c) => c.id != id).toList();
    _menuItems = _menuItems.where((m) => m.categoryId != id).toList();
    _commit();
  }

  // ------------------------------------------------------------ table admin

  @override
  Future<RestaurantTable> addTable() async {
    _require(_canManage, 'manage tables');
    // Mirrors the trigger in 0006_plans.sql. Implemented here as well as in
    // Postgres so the tests can see it — a cap that only exists in the
    // database is a cap nothing in this repository exercises.
    final plan = _settings.plan;
    if (!plan.canAddTable(_tables.length)) {
      throw StateError(
        'The ${plan.label} plan allows ${plan.maxTables} tables. '
        'Upgrade to add more.',
      );
    }
    final used = _tables.map((t) => int.tryParse(t.number) ?? 0).toList();
    final next = (used.isEmpty ? 0 : used.reduce((a, b) => a > b ? a : b)) + 1;
    final number = next.toString().padLeft(2, '0');
    final table = RestaurantTable(
      id: _uid('table'),
      number: number,
      name: 'Table $number',
      qrId: RestaurantTable.qrIdFor(number),
    );
    _tables = [..._tables, table];
    _commit();
    return table;
  }

  @override
  Future<void> renameTable(String id, String name) async {
    _require(_canManage, 'manage tables');
    _tables =
        _tables.map((t) => t.id == id ? t.copyWith(name: name) : t).toList();
    _commit();
  }

  /// A table with an order still in progress cannot be removed.
  @override
  Future<void> deleteTable(String id) async {
    _require(_canManage, 'manage tables');
    final occupied = _orders
        .any((o) => !o.isTakeaway && o.tableId == id && o.status.isActive);
    if (occupied) {
      throw StateError('This table still has an active order');
    }
    _tables = _tables.where((t) => t.id != id).toList();
    _commit();
  }

  // --------------------------------------------------------------- settings

  @override
  Future<void> updateSettings(RestaurantSettings settings) async {
    _require(_canManage, 'change settings');
    _settings = settings;
    _commit();
  }

  // ------------------------------------------------------------ plan change

  /// Mirrors request_upgrade() in 0010_upgrades.sql, including the part that
  /// matters: asking again edits the open request rather than filing a second.
  ///
  /// There is nobody to receive it on a device with no platform behind it, and
  /// it is still worth keeping — the demo shows the whole flow, and the tests
  /// can watch an owner ask and then withdraw.
  @override
  Future<void> requestUpgrade({
    required Plan toPlan,
    required UpgradeReason reason,
    required String contactName,
    required String contactPhone,
    String note = '',
  }) async {
    _require(_canManage, 'ask for a plan change');

    final open = _upgradeRequest;
    if (open != null && open.isOpen) {
      _upgradeRequest = open.copyWith(
        toPlan: toPlan,
        reason: reason,
        // Blank keeps what is already on the request: the sheet sends what the
        // owner typed, and an empty field means "leave it alone", not "wipe
        // the number you were going to call me on".
        contactName: contactName.trim().isEmpty ? null : contactName.trim(),
        contactPhone: contactPhone.trim().isEmpty ? null : contactPhone.trim(),
        note: note,
      );
      _commit();
      return;
    }

    _upgradeRequest = UpgradeRequest(
      id: _uid('req'),
      fromPlan: _settings.plan,
      toPlan: toPlan,
      reason: reason,
      status: UpgradeStatus.pending,
      createdAt: DateTime.now(),
      contactName: contactName.trim(),
      contactPhone: contactPhone.trim(),
      note: note,
    );
    _commit();
  }

  @override
  Future<void> cancelUpgradeRequest() async {
    _require(_canManage, 'withdraw a plan change request');
    _upgradeRequest = null;
    _commit();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../l10n/app_text.dart';
import '../models/cart_line.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/restaurant_settings.dart';
import '../models/restaurant_table.dart';
import '../models/staff_account.dart';
import 'demo_data.dart';

/// What the app is showing: the anonymous customer experience, or the
/// workspace of whoever is signed in.
enum AppMode { customer, staff }

/// Virtual category id for the "Popular" tab on the customer menu.
const String kPopularCategoryId = 'popular';

/// Single source of truth for the whole prototype.
///
/// Every role reads and writes the same [Order] list, which is what makes the
/// end-to-end demo work: the kitchen moving an order to READY immediately
/// changes what the customer's tracker shows. State is mirrored into
/// SharedPreferences so a reload keeps the demo where it was.
class AppStore extends ChangeNotifier {
  static const String _prefsKey = 'rqo_state_v4';

  SharedPreferences? _prefs;
  int _idCounter = 0;

  RestaurantSettings _settings = DemoData.settings();
  List<MenuCategory> _categories = DemoData.categories();
  List<MenuItem> _menuItems = DemoData.menuItems();
  List<RestaurantTable> _tables = DemoData.tables();
  List<Order> _orders = [];
  int _nextOrderNumber = DemoData.nextOrderNumber();

  List<StaffAccount> _accounts = [];
  String? _currentUserId;
  AppMode _mode = AppMode.customer;
  AppLanguage _language = Brand.defaultLanguage;
  String? _activeTableId;
  OrderType _orderType = OrderType.dineIn;
  List<CartLine> _cart = [];
  String _cartNote = '';
  final List<String> _sessionOrderIds = [];

  // ---------------------------------------------------------------- getters

  RestaurantSettings get settings => _settings;
  List<MenuCategory> get categories => List.unmodifiable(_categories);
  List<MenuItem> get menuItems => List.unmodifiable(_menuItems);
  List<RestaurantTable> get tables => List.unmodifiable(_tables);
  List<Order> get orders => List.unmodifiable(_orders);
  AppMode get mode => _mode;
  AppLanguage get language => _language;
  OrderType get orderType => _orderType;

  List<StaffAccount> get accounts => List.unmodifiable(_accounts);

  StaffAccount? get currentUser =>
      _accounts.where((a) => a.id == _currentUserId).firstOrNull;

  bool get isSignedIn => currentUser != null;

  /// Accounts offered on the PIN pad — active kitchen and cashier staff.
  List<StaffAccount> get pinAccounts =>
      _accounts.where((a) => a.active && !a.usesPassword).toList();

  bool get canManageRestaurant =>
      currentUser?.role.canManageRestaurant ?? false;
  bool get canWorkKitchen => currentUser?.role.canWorkKitchen ?? false;
  bool get canTakePayment => currentUser?.role.canTakePayment ?? false;

  /// A customer is browsing once they have scanned a table or chosen takeaway.
  bool get hasCustomerSession =>
      _activeTableId != null || _orderType == OrderType.takeaway;

  /// The string table for the language currently selected.
  AppText get text => AppText(_language);
  List<CartLine> get cart => List.unmodifiable(_cart);
  String get cartNote => _cartNote;
  String? get activeTableId => _activeTableId;

  RestaurantTable? get activeTable => _activeTableId == null
      ? null
      : _tables.where((t) => t.id == _activeTableId).firstOrNull;

  int get cartItemCount => _cart.fold(0, (sum, l) => sum + l.quantity);
  double get cartSubtotal => _cart.fold(0, (sum, l) => sum + l.lineTotal);
  double get cartTotal => cartSubtotal;

  String money(double value) =>
      '${_settings.currencySymbol}${value.toStringAsFixed(2)}';

  /// Categories shown to the customer, with the virtual "Popular" tab first.
  List<MenuCategory> get customerCategories => [
        const MenuCategory(
            id: kPopularCategoryId, name: 'Popular', sortOrder: 0),
        ..._sortedCategories,
      ];

  List<MenuCategory> get _sortedCategories {
    final list = [..._categories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  List<MenuCategory> get sortedCategories => List.unmodifiable(_sortedCategories);

  List<MenuItem> itemsInCategory(String categoryId) {
    if (categoryId == kPopularCategoryId) {
      return _menuItems.where((m) => m.popular).toList();
    }
    return _menuItems.where((m) => m.categoryId == categoryId).toList();
  }

  MenuItem? menuItem(String id) => _menuItems.where((m) => m.id == id).firstOrNull;

  MenuCategory? category(String id) =>
      _categories.where((c) => c.id == id).firstOrNull;

  String categoryName(String id) =>
      category(id)?.name ?? (id == kPopularCategoryId ? 'Popular' : 'Unknown');

  Order? order(String id) => _orders.where((o) => o.id == id).firstOrNull;

  List<Order> ordersWithStatus(OrderStatus status) {
    final list = _orders.where((o) => o.status == status).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Everything currently in flight, oldest first — what the cashier watches.
  /// Cancelled and completed orders have left the floor, so they drop out.
  List<Order> get liveOrders {
    final list = _orders.where((o) => o.status.isActive).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Everything that has left the floor — paid, closed or cancelled — with the
  /// most recently settled first.
  List<Order> get settledOrders {
    DateTime settledAt(Order o) => o.paidAt ?? o.cancelledAt ?? o.createdAt;
    final list = _orders.where((o) => !o.status.isActive).toList()
      ..sort((a, b) => settledAt(b).compareTo(settledAt(a)));
    return list;
  }

  /// Newest first, used by the admin order list.
  List<Order> get ordersNewestFirst {
    final list = [..._orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Rule 8 — a submitted order is read-only for the customer. These are the
  /// orders the customer may watch: what they placed this session, plus any
  /// order still open on their table.
  List<Order> get myOrders {
    final list = _orders
        .where((o) =>
            _sessionOrderIds.contains(o.id) ||
            (_activeTableId != null &&
                !o.isTakeaway &&
                o.tableId == _activeTableId &&
                o.status.isActive))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  bool isTableOccupied(String tableId) => _orders
      .any((o) => !o.isTakeaway && o.tableId == tableId && o.status.isActive);

  RestaurantTable? tableByNumber(String number) =>
      _tables.where((t) => t.number == number).firstOrNull;

  /// Live counts for the kitchen board: what is queued, what is on the stove,
  /// what is waiting to go out, and how much has been cooked today.
  ({int waiting, int cooking, int toServe, int cookedOrders, int cookedDishes})
      get kitchenCounts {
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;

    final waiting = _orders.where((o) => o.status == OrderStatus.newOrder);
    final cooking = _orders.where((o) => o.status == OrderStatus.cooking);
    final toServe = _orders.where((o) => o.status == OrderStatus.ready);

    // Anything past the stove counts as cooked, however it was settled.
    final cooked = _orders.where((o) =>
        isToday(o.createdAt) &&
        (o.status == OrderStatus.ready ||
            o.status == OrderStatus.paid ||
            o.status == OrderStatus.completed));

    return (
      waiting: waiting.length,
      cooking: cooking.length,
      toServe: toServe.length,
      cookedOrders: cooked.length,
      cookedDishes: cooked.fold<int>(0, (sum, o) => sum + o.itemCount),
    );
  }

  /// Today's figures for the admin dashboard.
  ({int orders, double revenue, int pending, int completed}) get todaySummary {
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;

    final today = _orders.where((o) => isToday(o.createdAt)).toList();
    final revenue = today
        .where((o) =>
            o.status == OrderStatus.paid || o.status == OrderStatus.completed)
        .fold<double>(0, (sum, o) => sum + o.total);
    return (
      orders: today.length,
      revenue: revenue,
      pending: today.where((o) => o.status.isActive).length,
      completed: today.where((o) => o.status == OrderStatus.completed).length,
    );
  }

  // ------------------------------------------------------------ persistence

  Future<void> load() async {
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
    notifyListeners();
  }

  void _seedDemo() {
    _accounts = DemoData.accounts();
    _currentUserId = null;
    _mode = AppMode.customer;
    _orderType = OrderType.dineIn;
    _settings = DemoData.settings();
    _categories = DemoData.categories();
    _menuItems = DemoData.menuItems();
    _tables = DemoData.tables();
    _orders = DemoData.orders(DateTime.now());
    _nextOrderNumber = DemoData.nextOrderNumber();
    _cart = [];
    _cartNote = '';
    _activeTableId = null;
    _sessionOrderIds.clear();
  }

  /// Dish name in the language currently selected.
  String itemDisplayName(MenuItem item) => item.displayName(_language);

  /// Restaurant name in the language currently selected.
  String get restaurantDisplayName => _settings.displayName(_language);

  /// Dishes that have no Khmer name yet, so the admin can see the gaps.
  int get untranslatedItemCount =>
      _menuItems.where((m) => m.nameKm.trim().isEmpty).length;

  int get untranslatedCategoryCount =>
      _categories.where((c) => c.nameKm.trim().isEmpty).length;

  void _restore(Map<String, dynamic> json) {
    _settings =
        RestaurantSettings.fromJson(json['settings'] as Map<String, dynamic>);
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
    _mode = AppMode.values.firstWhere(
      (m) => m.name == json['mode'],
      orElse: () => AppMode.customer,
    );
    _orderType = OrderType.fromWire(json['orderType'] as String? ?? 'DINE_IN');
    _language = AppLanguage.values.firstWhere(
      (l) => l.name == json['language'],
      orElse: () => Brand.defaultLanguage,
    );
    _activeTableId = json['activeTableId'] as String?;
    _cart = (json['cart'] as List<dynamic>? ?? const [])
        .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
        .toList();
    _cartNote = json['cartNote'] as String? ?? '';
    _sessionOrderIds
      ..clear()
      ..addAll((json['sessionOrderIds'] as List<dynamic>? ?? const [])
          .map((e) => e as String));
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
        'mode': _mode.name,
        'orderType': _orderType.wire,
        'language': _language.name,
        'activeTableId': _activeTableId,
        'cart': _cart.map((e) => e.toJson()).toList(),
        'cartNote': _cartNote,
        'sessionOrderIds': _sessionOrderIds,
      };

  Future<void> _persist() async {
    await _prefs?.setString(_prefsKey, jsonEncode(_snapshot()));
  }

  /// [notify] rebuilds listeners; [persist] writes the snapshot. Typing in the
  /// order note wants neither — nothing else on screen reads it, and the whole
  /// snapshot is far too big to serialise per keystroke. It rides along with
  /// the next real change, or with the order itself.
  void _commit({bool notify = true, bool persist = true}) {
    if (notify) notifyListeners();
    if (persist) unawaited(_persist());
  }

  Future<void> resetDemoData() async {
    _require(canManageRestaurant, 'reset the demo data');
    _seedDemo();
    // _seedDemo replaces the account list, so the id we were signed in with no
    // longer exists. Without this the admin who pressed the button is silently
    // signed out and left on a settings screen they are no longer allowed to
    // be on. Land them back on the seeded admin instead.
    final admin = _accounts
        .where((a) => a.role == StaffRole.admin && a.active)
        .firstOrNull;
    _currentUserId = admin?.id;
    _mode = admin == null ? AppMode.customer : AppMode.staff;
    await _persist();
    notifyListeners();
  }

  String _uid(String prefix) {
    _idCounter++;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  // ------------------------------------------------------ accounts & access

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

  /// Admin sign-in. Returns false on a bad username or password.
  ///
  /// Async because hashing is deliberately slow; yielding first lets the
  /// caller paint a progress state before the main thread blocks on it.
  Future<bool> signInWithPassword(String username, String password) async {
    await Future<void>.delayed(Duration.zero);
    final account = _accounts
        .where((a) =>
            a.usesPassword &&
            a.active &&
            a.username.toLowerCase() == username.trim().toLowerCase())
        .firstOrNull;
    if (account == null || !account.verify(password)) return false;
    _currentUserId = account.id;
    _mode = AppMode.staff;
    notifyListeners();
    unawaited(_persist());
    return true;
  }

  /// Kitchen and cashier sign-in: pick your name, enter your PIN.
  Future<bool> signInWithPin(String accountId, String pin) async {
    await Future<void>.delayed(Duration.zero);
    final account = _accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null || !account.verify(pin)) return false;
    _currentUserId = account.id;
    _mode = AppMode.staff;
    notifyListeners();
    unawaited(_persist());
    return true;
  }

  void signOut() {
    _currentUserId = null;
    _mode = AppMode.customer;
    notifyListeners();
    unawaited(_persist());
  }

  /// Staff can drop into the customer view (to demo it, or to order for a
  /// walk-in) without losing their session.
  void setMode(AppMode mode) {
    if (_mode == mode) return;
    if (mode == AppMode.staff && !isSignedIn) return;
    _mode = mode;
    _commit();
  }

  StaffAccount addStaff({
    required String name,
    required StaffRole role,
    required String secret,
    String username = '',
  }) {
    _require(canManageRestaurant, 'manage staff');
    if (role != StaffRole.admin && secret.length != StaffAccount.pinLength) {
      throw StateError('A PIN must be ${StaffAccount.pinLength} digits');
    }
    // Sign-in matches the *first* account with the username typed, so a
    // duplicate would lock the second admin out for good with nothing on
    // screen to explain why. PINs need no such check: staff are picked by name
    // first, so the PIN is only ever verified against the chosen account.
    final wanted = username.trim().toLowerCase();
    if (wanted.isNotEmpty &&
        _accounts.any((a) => a.username.toLowerCase() == wanted)) {
      throw StateError('Another account already uses that username');
    }
    final account = StaffAccount.create(
      id: _uid('staff'),
      name: name.trim(),
      role: role,
      secret: secret,
      username: username.trim(),
    );
    _accounts = [..._accounts, account];
    _commit();
    return account;
  }

  void renameStaff(String id, String name) {
    _require(canManageRestaurant, 'manage staff');
    _accounts =
        _accounts.map((a) => a.id == id ? a.copyWith(name: name) : a).toList();
    _commit();
  }

  void resetStaffSecret(String id, String secret) {
    _require(canManageRestaurant, 'manage staff');
    final target = _accounts.where((a) => a.id == id).firstOrNull;
    if (target != null &&
        !target.usesPassword &&
        secret.length != StaffAccount.pinLength) {
      throw StateError('A PIN must be ${StaffAccount.pinLength} digits');
    }
    _accounts = _accounts
        .map((a) => a.id == id ? a.withSecret(secret) : a)
        .toList();
    _commit();
  }

  void setStaffActive(String id, bool active) {
    _require(canManageRestaurant, 'manage staff');
    if (!active) _guardLastAdmin(id);
    _accounts = _accounts
        .map((a) => a.id == id ? a.copyWith(active: active) : a)
        .toList();
    if (!active && _currentUserId == id) signOut();
    _commit();
  }

  void deleteStaff(String id) {
    _require(canManageRestaurant, 'manage staff');
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

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    _commit();
  }

  void toggleLanguage() => setLanguage(
        _language == AppLanguage.en ? AppLanguage.km : AppLanguage.en,
      );

  /// Category name in the language currently selected.
  String categoryDisplayName(String id) {
    if (id == kPopularCategoryId) return text.popular;
    return category(id)?.displayName(_language) ?? text.notFound;
  }

  // -------------------------------------------------------- customer session

  /// Rule 1 & 3 — scanning a table QR is the whole "login".
  void openTable(String tableId) {
    if (_activeTableId != tableId || _orderType != OrderType.dineIn) {
      _cart = [];
      _cartNote = '';
      _sessionOrderIds.clear();
    }
    _activeTableId = tableId;
    _orderType = OrderType.dineIn;
    _commit();
  }

  /// Starts a takeaway order, which needs no table at all.
  void startTakeaway() {
    if (_orderType != OrderType.takeaway) {
      _cart = [];
      _cartNote = '';
      _sessionOrderIds.clear();
    }
    _activeTableId = null;
    _orderType = OrderType.takeaway;
    _commit();
  }

  /// Moves an order already in progress to dine-in at [tableId].
  ///
  /// Unlike [openTable] this keeps the cart: the customer has not started
  /// over, they have only told us where they are sitting. It is what the
  /// Dine-in tab does when nothing has been scanned yet.
  void chooseTable(String tableId) {
    if (_tables.every((t) => t.id != tableId)) {
      throw StateError('Unknown table');
    }
    _activeTableId = tableId;
    _orderType = OrderType.dineIn;
    _commit();
  }

  /// Switching in the cart. Dine-in needs a table, so the caller has to send
  /// the customer back to scan one if there is none.
  void setOrderType(OrderType type) {
    if (_orderType == type) return;
    if (type == OrderType.dineIn && _activeTableId == null) {
      throw StateError('Scan a table QR to dine in');
    }
    _orderType = type;
    if (type == OrderType.takeaway) _activeTableId = null;
    _commit();
  }

  /// Resolves a scanned payload to a table. Accepts a full URL, a path such as
  /// `/order/demo/table/05`, or a raw qr id like `restaurant-demo-table-05`.
  RestaurantTable? resolveScannedValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final byQrId = _tables.where((t) => t.qrId == trimmed).firstOrNull;
    if (byQrId != null) return byQrId;

    final match = RegExp(r'table[/\-](\d+)', caseSensitive: false)
        .firstMatch(trimmed.toLowerCase());
    if (match != null) {
      final digits = match.group(1)!;
      return tableByNumber(digits.padLeft(2, '0')) ?? tableByNumber(digits);
    }
    return null;
  }

  void leaveTable() {
    _activeTableId = null;
    _orderType = OrderType.dineIn;
    _cart = [];
    _cartNote = '';
    _sessionOrderIds.clear();
    _commit();
  }

  // ------------------------------------------------------------------- cart

  /// Rule 9 — sold-out dishes never reach the cart.
  void addToCart(MenuItem item, {int quantity = 1, String? note}) {
    if (!item.available) {
      throw StateError('${item.name} is sold out');
    }
    final cleanNote = (note ?? '').trim();
    final unitPrice = item.effectivePrice;
    final existing = _cart.indexWhere(
      (l) =>
          l.foodId == item.id &&
          (l.note ?? '') == cleanNote &&
          l.price == unitPrice,
    );
    if (existing >= 0) {
      _cart[existing] = _cart[existing]
          .copyWith(quantity: _cart[existing].quantity + quantity);
    } else {
      _cart = [
        ..._cart,
        CartLine(
          id: _uid('line'),
          foodId: item.id,
          name: item.name,
          nameKm: item.nameKm,
          price: unitPrice,
          quantity: quantity,
          note: cleanNote.isEmpty ? null : cleanNote,
        ),
      ];
    }
    _commit();
  }

  void setCartLineQuantity(String lineId, int quantity) {
    if (quantity <= 0) {
      removeCartLine(lineId);
      return;
    }
    _cart = _cart
        .map((l) => l.id == lineId ? l.copyWith(quantity: quantity) : l)
        .toList();
    _commit();
  }

  void setCartLineNote(String lineId, String note) {
    final clean = note.trim();
    _cart = _cart
        .map((l) => l.id == lineId
            ? l.copyWith(note: clean, clearNote: clean.isEmpty)
            : l)
        .toList();
    _commit();
  }

  void removeCartLine(String lineId) {
    _cart = _cart.where((l) => l.id != lineId).toList();
    _commit();
  }

  void setCartNote(String note) {
    _cartNote = note;
    _commit(notify: false, persist: false);
  }

  void clearCart() {
    _cart = [];
    _cartNote = '';
    _commit();
  }

  // ----------------------------------------------------------------- orders

  /// Rule 11 as amended — a dine-in order carries its table, a takeaway order
  /// carries the takeaway marker. Rule 12 — the number is always unique.
  Order submitOrder() {
    final table = activeTable;
    final takeaway = _orderType == OrderType.takeaway;
    if (!takeaway && table == null) {
      throw StateError('No table selected — scan a table QR first');
    }
    if (_cart.isEmpty) {
      throw StateError('The cart is empty');
    }

    final items = _cart
        .map((l) => OrderItem(
              id: _uid('item'),
              foodId: l.foodId,
              name: l.name,
              nameKm: l.nameKm,
              price: l.price,
              quantity: l.quantity,
              note: l.note,
            ))
        .toList();
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
    final note = _cartNote.trim();

    final order = Order(
      id: _uid('order'),
      orderNumber: '${_nextOrderNumber++}',
      type: _orderType,
      tableId: takeaway ? null : table!.id,
      tableNumber: takeaway ? null : table!.number,
      items: items,
      subtotal: subtotal,
      total: subtotal,
      customerNote: note.isEmpty ? null : note,
      status: OrderStatus.newOrder,
      createdAt: DateTime.now(),
    );

    _orders = [..._orders, order];
    _sessionOrderIds.add(order.id);
    _cart = [];
    _cartNote = '';
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
    final updated = current.copyWith(
      status: to,
      paymentMethod: paymentMethod,
      paidAt: stampPaidAt ? DateTime.now() : null,
    );
    _orders = [..._orders]..[index] = updated;
    _commit();
  }

  /// Rule 6 — kitchen owns NEW -> COOKING -> READY.
  void startCooking(String orderId) {
    _require(canWorkKitchen, 'work the kitchen');
    _transition(orderId, OrderStatus.newOrder, OrderStatus.cooking);
  }

  void markReady(String orderId) {
    _require(canWorkKitchen, 'work the kitchen');
    _transition(orderId, OrderStatus.cooking, OrderStatus.ready);
  }

  /// Rule 7 — cashier owns READY -> PAID -> COMPLETED.
  void collectPayment(String orderId, String paymentMethod) {
    _require(canTakePayment, 'take payment');
    _transition(
      orderId,
      OrderStatus.ready,
      OrderStatus.paid,
      paymentMethod: paymentMethod,
      stampPaidAt: true,
    );
  }

  void completeOrder(String orderId) {
    _require(canTakePayment, 'close an order');
    _transition(orderId, OrderStatus.paid, OrderStatus.completed);
  }

  /// Cancels an order on the customer's behalf.
  ///
  /// Only while it is still queued: once the kitchen has started, the food is
  /// already being made and cancelling it would leave a cooked dish that
  /// nobody has paid for. The check lives here, not only on the button, so a
  /// stale screen cannot cancel something the kitchen picked up a second ago.
  void cancelOrder(String orderId) {
    _require(canTakePayment, 'cancel an order');
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

  /// Changes how much of one dish a customer is having, before the kitchen
  /// starts on it. A quantity of zero drops the line entirely.
  ///
  /// The same window as [cancelOrder], for the same reason: once a pan is on
  /// the heat the dish exists whether or not it is still wanted. Removing the
  /// last remaining line is refused — an order with nothing on it is not a
  /// thing the kitchen or the till can do anything with, so that case is a
  /// cancellation and should be made as one, deliberately.
  void setOrderItemQuantity(String orderId, String itemId, int quantity) {
    _require(canTakePayment, 'change an order');
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

  /// Takes one dish off an order outright. See [setOrderItemQuantity].
  void removeOrderItem(String orderId, String itemId) =>
      setOrderItemQuantity(orderId, itemId, 0);

  /// Places an order at the counter on a customer's behalf.
  ///
  /// This is deliberately separate from [submitOrder]: the staff member's
  /// basket must not touch [cart], which belongs to whichever customer session
  /// this device is also showing. It lands in NEW like any other order, so the
  /// kitchen and the tracker treat it identically — only [Order.placedBy]
  /// records that it came from the till.
  Order placeStaffOrder({
    required OrderType type,
    String? tableId,
    required List<CartLine> lines,
    String note = '',
  }) {
    _require(canTakePayment, 'take an order for a customer');
    if (lines.isEmpty) {
      throw StateError('Add at least one dish');
    }
    final table = type.needsTable
        ? _tables.where((t) => t.id == tableId).firstOrNull
        : null;
    if (type.needsTable && table == null) {
      throw StateError('Pick a table for a dine-in order');
    }

    final items = lines
        .map((l) => OrderItem(
              id: _uid('item'),
              foodId: l.foodId,
              name: l.name,
              nameKm: l.nameKm,
              price: l.price,
              quantity: l.quantity,
              note: l.note,
            ))
        .toList();
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
      placedBy: currentUser?.name,
    );

    _orders = [..._orders, order];
    _commit();
    return order;
  }

  // ------------------------------------------------------------ menu admin

  void addMenuItem({
    required String name,
    required String description,
    required double price,
    required String categoryId,
    required String image,
    String nameKm = '',
    String descriptionKm = '',
    String? photo,
    int discountPercent = 0,
    bool available = true,
    bool popular = false,
    bool signature = false,
  }) {
    _require(canManageRestaurant, 'edit the menu');
    _menuItems = [
      ..._menuItems,
      MenuItem(
        id: _uid('food'),
        name: name,
        nameKm: nameKm,
        description: description,
        descriptionKm: descriptionKm,
        price: price,
        categoryId: categoryId,
        image: image,
        photo: photo,
        discountPercent: discountPercent,
        available: available,
        popular: popular,
        signature: signature,
      ),
    ];
    _commit();
  }

  void updateMenuItem(MenuItem item) {
    _require(canManageRestaurant, 'edit the menu');
    _menuItems =
        _menuItems.map((m) => m.id == item.id ? item : m).toList();
    _commit();
  }

  void deleteMenuItem(String id) {
    _require(canManageRestaurant, 'edit the menu');
    _menuItems = _menuItems.where((m) => m.id != id).toList();
    _commit();
  }

  void setItemAvailability(String id, bool available) {
    _require(canManageRestaurant, 'edit the menu');
    _menuItems = _menuItems
        .map((m) => m.id == id ? m.copyWith(available: available) : m)
        .toList();
    _commit();
  }

  MenuCategory addCategory(String name, {String nameKm = ''}) {
    _require(canManageRestaurant, 'edit the menu');
    final nextOrder = _categories.isEmpty
        ? 1
        : _categories.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
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

  void renameCategory(String id, String name, {String nameKm = ''}) {
    _require(canManageRestaurant, 'edit the menu');
    _categories = _categories
        .map((c) => c.id == id ? c.copyWith(name: name, nameKm: nameKm) : c)
        .toList();
    _commit();
  }

  /// Removes a category together with the dishes filed under it.
  void deleteCategory(String id) {
    _require(canManageRestaurant, 'edit the menu');
    _categories = _categories.where((c) => c.id != id).toList();
    _menuItems = _menuItems.where((m) => m.categoryId != id).toList();
    _commit();
  }

  int itemCountInCategory(String id) =>
      _menuItems.where((m) => m.categoryId == id).length;

  // ----------------------------------------------------------- table admin

  RestaurantTable addTable() {
    _require(canManageRestaurant, 'manage tables');
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

  void renameTable(String id, String name) {
    _require(canManageRestaurant, 'manage tables');
    _tables =
        _tables.map((t) => t.id == id ? t.copyWith(name: name) : t).toList();
    _commit();
  }

  /// A table with an order still in progress cannot be removed.
  void deleteTable(String id) {
    _require(canManageRestaurant, 'manage tables');
    if (isTableOccupied(id)) {
      throw StateError('This table still has an active order');
    }
    _tables = _tables.where((t) => t.id != id).toList();
    if (_activeTableId == id) {
      _activeTableId = null;
      _cart = [];
      _cartNote = '';
    }
    _commit();
  }

  // -------------------------------------------------------------- settings

  void updateSettings(RestaurantSettings settings) {
    _require(canManageRestaurant, 'change settings');
    _settings = settings;
    _commit();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../l10n/app_text.dart';
import '../models/cart_line.dart';
import '../models/date_range.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/restaurant_settings.dart';
import '../models/plan.dart';
import '../models/restaurant_table.dart';
import '../models/staff_account.dart';
import '../models/upgrade_request.dart';
import 'backend/backend.dart';
import 'backend/local_backend.dart';
import 'demo_data.dart';

/// What the app is showing: the anonymous customer experience, or the
/// workspace of whoever is signed in.
enum AppMode { customer, staff }

/// Virtual category id for the "Popular" tab on the customer menu.
const String kPopularCategoryId = 'popular';

/// Single source of truth for the whole app.
///
/// It owns two quite different things, and keeping them apart is what lets the
/// same screens run against a phone's own storage or a shared database:
///
///  * **The restaurant** — menu, tables, orders, staff. Comes from a [Backend]
///    and may be changed by somebody else at any moment, so it is cached here
///    and refreshed when the backend says so.
///  * **This device's session** — which table was scanned, what is in the
///    cart, which language, which mode. Nobody else's business, never leaves
///    the device, and persists in SharedPreferences either way.
///
/// Every mutation is a Future because a real backend is a round trip away, and
/// every one may throw [StateError] with a message meant to be shown.
class AppStore extends ChangeNotifier {
  AppStore({Backend? backend}) : _backend = backend ?? LocalBackend();

  /// The device's own session. The restaurant's data lives wherever the
  /// backend keeps it, which on Supabase is not here at all.
  static const String _prefsKey = 'rqo_session_v5';

  final Backend _backend;
  StreamSubscription<RestaurantData>? _watch;
  SharedPreferences? _prefs;
  int _idCounter = 0;

  RestaurantData _data = RestaurantData(
    settings: DemoData.settings(),
    categories: DemoData.categories(),
    menuItems: DemoData.menuItems(),
    tables: DemoData.tables(),
    orders: const [],
    accounts: const [],
    support: const SupportContact(
      phone: Support.phone,
      telegram: Support.telegram,
      hours: Support.hours,
    ),
  );

  AppMode _mode = AppMode.customer;
  AppLanguage _language = Brand.defaultLanguage;
  String? _activeTableId;
  OrderType _orderType = OrderType.dineIn;
  List<CartLine> _cart = [];
  String _cartNote = '';
  final List<String> _sessionOrderIds = [];

  // ---------------------------------------------------------------- getters

  /// True when this build has no database behind it — the on-device demo.
  bool get isDemo => _backend.isDemo;

  RestaurantSettings get settings => _data.settings;
  List<MenuCategory> get categories => List.unmodifiable(_data.categories);
  List<MenuItem> get menuItems => List.unmodifiable(_data.menuItems);
  List<RestaurantTable> get tables => List.unmodifiable(_data.tables);
  List<Order> get orders => List.unmodifiable(_data.orders);
  AppMode get mode => _mode;
  AppLanguage get language => _language;
  OrderType get orderType => _orderType;

  List<StaffAccount> get accounts => List.unmodifiable(_data.accounts);

  /// How the owner reaches the people running the service.
  SupportContact get support => _data.support;

  /// The open request for a bigger plan, or null when there is none.
  UpgradeRequest? get upgradeRequest => _data.upgradeRequest;

  StaffAccount? get currentUser => _backend.currentUser;

  bool get isSignedIn => currentUser != null;

  /// Accounts offered on the PIN pad — active kitchen and cashier staff.
  List<StaffAccount> get pinAccounts =>
      _data.accounts.where((a) => a.active && !a.usesPassword).toList();

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
      : _data.tables.where((t) => t.id == _activeTableId).firstOrNull;

  int get cartItemCount => _cart.fold(0, (sum, l) => sum + l.quantity);
  double get cartSubtotal => _cart.fold(0, (sum, l) => sum + l.lineTotal);
  double get cartTotal => cartSubtotal;

  /// True when the dish behind [line] has sold out or left the menu since it
  /// was added.
  ///
  /// A cart is a snapshot, and the menu carries on without it — the kitchen
  /// runs out of pork while somebody is still reading the drinks. The order
  /// would be refused on submit either way; this lets the cart say so while
  /// there is still a Remove button next to the line.
  bool cartLineUnavailable(CartLine line) {
    final item = menuItem(line.foodId);
    return item == null || !item.available;
  }

  String money(double value) =>
      '${settings.currencySymbol}${value.toStringAsFixed(2)}';

  /// Categories shown to the customer, with the virtual "Popular" tab first.
  List<MenuCategory> get customerCategories => [
        const MenuCategory(
            id: kPopularCategoryId, name: 'Popular', sortOrder: 0),
        ..._sortedCategories,
      ];

  List<MenuCategory> get _sortedCategories {
    final list = [..._data.categories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  List<MenuCategory> get sortedCategories =>
      List.unmodifiable(_sortedCategories);

  List<MenuItem> itemsInCategory(String categoryId) {
    if (categoryId == kPopularCategoryId) {
      return _data.menuItems.where((m) => m.popular).toList();
    }
    return _data.menuItems.where((m) => m.categoryId == categoryId).toList();
  }

  MenuItem? menuItem(String id) =>
      _data.menuItems.where((m) => m.id == id).firstOrNull;

  MenuCategory? category(String id) =>
      _data.categories.where((c) => c.id == id).firstOrNull;

  Order? order(String id) => _data.orders.where((o) => o.id == id).firstOrNull;

  List<Order> ordersWithStatus(OrderStatus status) {
    final list = _data.orders.where((o) => o.status == status).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Everything currently in flight, oldest first — what the cashier watches.
  /// Cancelled and completed orders have left the floor, so they drop out.
  List<Order> get liveOrders {
    final list = _data.orders.where((o) => o.status.isActive).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Everything that has left the floor — paid, closed or cancelled — with the
  /// most recently settled first.
  List<Order> get settledOrders {
    DateTime settledAt(Order o) => o.paidAt ?? o.cancelledAt ?? o.createdAt;
    final list = _data.orders.where((o) => !o.status.isActive).toList()
      ..sort((a, b) => settledAt(b).compareTo(settledAt(a)));
    return list;
  }

  /// Newest first, used by the admin order list.
  List<Order> get ordersNewestFirst {
    final list = [..._data.orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Rule 8 — a submitted order is read-only for the customer. These are the
  /// orders the customer may watch: what they placed this session, plus any
  /// order still open on their table.
  List<Order> get myOrders {
    final list = _data.orders
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

  bool isTableOccupied(String tableId) => _data.orders
      .any((o) => !o.isTakeaway && o.tableId == tableId && o.status.isActive);

  RestaurantTable? tableByNumber(String number) =>
      _data.tables.where((t) => t.number == number).firstOrNull;

  /// Live counts for the kitchen board: what is queued, what is on the stove,
  /// what is waiting to go out, and how much has been cooked today.
  ({int waiting, int cooking, int toServe, int cookedOrders, int cookedDishes})
      get kitchenCounts {
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;

    final waiting = _data.orders.where((o) => o.status == OrderStatus.newOrder);
    final cooking = _data.orders.where((o) => o.status == OrderStatus.cooking);
    final toServe = _data.orders.where((o) => o.status == OrderStatus.ready);

    // Anything past the stove counts as cooked, however it was settled.
    final cooked = _data.orders.where((o) =>
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

  /// Orders inside [range], newest first. The report's one source of truth —
  /// the figures and the export both read this, so they cannot disagree.
  List<Order> ordersIn(ReportRange range) {
    final now = DateTime.now();
    final list = _data.orders
        .where((o) => range.contains(o.createdAt, now: now))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Headline figures for a report window.
  ///
  /// Revenue counts only money actually taken — paid and completed. A
  /// cancelled order earns nothing, and an order still on the stove has not
  /// earned anything yet.
  ({
    int orders,
    double revenue,
    int pending,
    int completed,
    int cancelled,
    int dishes,
    double average,
  }) summaryFor(ReportRange range) {
    final orders = ordersIn(range);
    final settled = orders
        .where((o) =>
            o.status == OrderStatus.paid || o.status == OrderStatus.completed)
        .toList();
    final revenue = settled.fold<double>(0, (sum, o) => sum + o.total);
    return (
      orders: orders.length,
      revenue: revenue,
      pending: orders.where((o) => o.status.isActive).length,
      completed:
          orders.where((o) => o.status == OrderStatus.completed).length,
      cancelled:
          orders.where((o) => o.status == OrderStatus.cancelled).length,
      dishes: orders
          .where((o) => o.status != OrderStatus.cancelled)
          .fold<int>(0, (sum, o) => sum + o.itemCount),
      // Averaged over orders that were actually paid for; dividing takings by
      // a count that includes cancellations would understate every ticket.
      average: settled.isEmpty ? 0 : revenue / settled.length,
    );
  }

  /// What sold, most first — the question an owner actually asks of a report.
  List<({String name, int quantity, double revenue})> topDishes(
    ReportRange range, {
    int limit = 10,
  }) {
    final counts = <String, ({int quantity, double revenue})>{};
    for (final order in ordersIn(range)) {
      if (order.status == OrderStatus.cancelled) continue;
      for (final item in order.items) {
        final current = counts[item.name] ?? (quantity: 0, revenue: 0.0);
        counts[item.name] = (
          quantity: current.quantity + item.quantity,
          revenue: current.revenue + item.lineTotal,
        );
      }
    }
    final list = counts.entries
        .map((e) =>
            (name: e.key, quantity: e.value.quantity, revenue: e.value.revenue))
        .toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    return list.take(limit).toList();
  }

  /// Today's figures for the admin dashboard.
  ({int orders, double revenue, int pending, int completed}) get todaySummary {
    final s = summaryFor(const ReportRange.today());
    return (
      orders: s.orders,
      revenue: s.revenue,
      pending: s.pending,
      completed: s.completed,
    );
  }

  /// Dish name in the language currently selected.
  String itemDisplayName(MenuItem item) => item.displayName(_language);

  /// Restaurant name in the language currently selected.
  String get restaurantDisplayName => settings.displayName(_language);

  /// Dishes that have no Khmer name yet, so the admin can see the gaps.
  int get untranslatedItemCount =>
      _data.menuItems.where((m) => m.nameKm.trim().isEmpty).length;

  int get untranslatedCategoryCount =>
      _data.categories.where((c) => c.nameKm.trim().isEmpty).length;

  int itemCountInCategory(String id) =>
      _data.menuItems.where((m) => m.categoryId == id).length;

  /// Category name in the language currently selected.
  String categoryDisplayName(String id) {
    if (id == kPopularCategoryId) return text.popular;
    return category(id)?.displayName(_language) ?? text.notFound;
  }

  // ------------------------------------------------------------ persistence

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_prefsKey);
    if (raw != null) {
      try {
        _restoreSession(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A malformed session should never block the app; start a fresh one.
        _resetSession();
      }
    }

    _data = await _backend.load();

    // Somebody else — the kitchen tablet, the till, another diner — changing
    // an order is the whole point of having a database. On the local backend
    // this stream never fires.
    _watch = _backend.changes.listen((data) {
      _data = data;
      notifyListeners();
    });

    // A restored session can outlive the account it was signed in with.
    if (!isSignedIn) _mode = AppMode.customer;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_watch?.cancel());
    unawaited(_backend.dispose());
    super.dispose();
  }

  void _resetSession() {
    _mode = AppMode.customer;
    _language = Brand.defaultLanguage;
    _activeTableId = null;
    _orderType = OrderType.dineIn;
    _cart = [];
    _cartNote = '';
    _sessionOrderIds.clear();
  }

  void _restoreSession(Map<String, dynamic> json) {
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

  Map<String, dynamic> _sessionSnapshot() => {
        'mode': _mode.name,
        'orderType': _orderType.wire,
        'language': _language.name,
        'activeTableId': _activeTableId,
        'cart': _cart.map((e) => e.toJson()).toList(),
        'cartNote': _cartNote,
        'sessionOrderIds': _sessionOrderIds,
      };

  Future<void> _persist() async {
    await _prefs?.setString(_prefsKey, jsonEncode(_sessionSnapshot()));
  }

  /// [notify] rebuilds listeners; [persist] writes the session. Typing in the
  /// order note wants neither — nothing else on screen reads it, and there is
  /// no sense serialising per keystroke. It rides along with the next real
  /// change, or with the order itself.
  void _commit({bool notify = true, bool persist = true}) {
    if (notify) notifyListeners();
    if (persist) unawaited(_persist());
  }

  /// Runs a backend mutation and republishes whatever it left behind.
  ///
  /// Failures propagate untouched: they carry a message written for the person
  /// holding the phone, and every caller already shows it.
  Future<T> _mutate<T>(Future<T> Function() action) async {
    final result = await action();
    _data = _backend.current;
    _commit(persist: false);
    return result;
  }

  Future<void> resetDemoData() => _mutate(() => _backend.resetDemoData());

  String _uid(String prefix) {
    _idCounter++;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  // ------------------------------------------------------ accounts & access

  /// Owner sign-in, with an email address and a password. Returns false on a
  /// bad address or password.
  Future<bool> signInWithPassword(String identifier, String password) async {
    final account = await _backend.signInWithPassword(identifier, password);
    if (account == null) return false;
    _data = _backend.current;
    _mode = AppMode.staff;
    _commit();
    return true;
  }

  /// Kitchen and cashier sign-in: pick your name, enter your PIN.
  Future<bool> signInWithPin(String accountId, String pin) async {
    final account = await _backend.signInWithPin(accountId, pin);
    if (account == null) return false;
    _data = _backend.current;
    _mode = AppMode.staff;
    _commit();
    return true;
  }

  Future<void> signOut() async {
    await _backend.signOut();
    _data = _backend.current;
    _mode = AppMode.customer;
    _commit();
  }

  /// Staff can drop into the customer view (to demo it, or to order for a
  /// walk-in) without losing their session.
  void setMode(AppMode mode) {
    if (_mode == mode) return;
    if (mode == AppMode.staff && !isSignedIn) return;
    _mode = mode;
    _commit();
  }

  Future<StaffAccount> addStaff({
    required String name,
    required StaffRole role,
    required String secret,
    String username = '',
    String email = '',
  }) =>
      _mutate(() => _backend.addStaff(
            name: name,
            role: role,
            secret: secret,
            username: username,
            email: email,
          ));

  Future<void> setMyLoginEmail(String email) =>
      _mutate(() => _backend.setMyLoginEmail(email));

  Future<void> renameStaff(String id, String name) =>
      _mutate(() => _backend.renameStaff(id, name));

  Future<void> resetStaffSecret(String id, String secret) =>
      _mutate(() => _backend.resetStaffSecret(id, secret));

  Future<void> setStaffActive(String id, bool active) async {
    await _mutate(() => _backend.setStaffActive(id, active));
    // Turning off the account you are signed in with logs you out; the shell
    // has to leave the workspace with it.
    if (!isSignedIn && _mode == AppMode.staff) {
      _mode = AppMode.customer;
      _commit();
    }
  }

  Future<void> deleteStaff(String id) => _mutate(() => _backend.deleteStaff(id));

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    _commit();
  }

  void toggleLanguage() => setLanguage(
        _language == AppLanguage.en ? AppLanguage.km : AppLanguage.en,
      );

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
    if (_data.tables.every((t) => t.id != tableId)) {
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

    final byQrId = _data.tables.where((t) => t.qrId == trimmed).firstOrNull;
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
    // The stepper cannot go below one, but this is the door every caller comes
    // through, and a zero would put a line in the cart that costs nothing and
    // feeds nobody — a negative one would take money off the bill.
    if (quantity < 1) {
      throw StateError('Choose at least one ${item.name}');
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

  /// Sends this device's cart to the kitchen.
  Future<Order> submitOrder() async {
    final order = await _mutate(() => _backend.placeOrder(
          type: _orderType,
          tableId: _activeTableId,
          lines: _cart,
          note: _cartNote,
        ));
    _sessionOrderIds.add(order.id);
    _cart = [];
    _cartNote = '';
    _commit();
    return order;
  }

  /// Takes an order at the counter on a customer's behalf.
  ///
  /// Deliberately separate from [submitOrder]: the staff member's basket must
  /// not touch [cart], which belongs to whichever customer session this device
  /// is also showing.
  Future<Order> placeStaffOrder({
    required OrderType type,
    String? tableId,
    required List<CartLine> lines,
    String note = '',
  }) =>
      _mutate(() => _backend.placeOrder(
            type: type,
            tableId: tableId,
            lines: lines,
            note: note,
            onBehalfOfCustomer: true,
          ));

  /// Rule 6 — kitchen owns NEW -> COOKING -> READY.
  Future<void> startCooking(String orderId) =>
      _mutate(() => _backend.startCooking(orderId));

  Future<void> markReady(String orderId) =>
      _mutate(() => _backend.markReady(orderId));

  /// Rule 7 — cashier owns READY -> PAID -> COMPLETED.
  Future<void> collectPayment(String orderId, String paymentMethod) =>
      _mutate(() => _backend.collectPayment(orderId, paymentMethod));

  Future<void> completeOrder(String orderId) =>
      _mutate(() => _backend.completeOrder(orderId));

  /// Cancels an order on the customer's behalf, while it is still queued.
  Future<void> cancelOrder(String orderId) =>
      _mutate(() => _backend.cancelOrder(orderId));

  /// Changes how much of one dish a customer is having, before the kitchen
  /// starts on it. A quantity of zero drops the line entirely.
  Future<void> setOrderItemQuantity(
          String orderId, String itemId, int quantity) =>
      _mutate(() => _backend.setOrderItemQuantity(orderId, itemId, quantity));

  /// Takes one dish off an order outright. See [setOrderItemQuantity].
  Future<void> removeOrderItem(String orderId, String itemId) =>
      setOrderItemQuantity(orderId, itemId, 0);

  // ------------------------------------------------------------ menu admin

  Future<void> addMenuItem({
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
  }) =>
      _mutate(() => _backend.addMenuItem(MenuItem(
            // The backend mints the real one; this is only a placeholder so
            // the same model can carry a dish that does not exist yet.
            id: '',
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
          )));

  Future<void> updateMenuItem(MenuItem item) =>
      _mutate(() => _backend.updateMenuItem(item));

  Future<void> deleteMenuItem(String id) =>
      _mutate(() => _backend.deleteMenuItem(id));

  Future<void> setItemAvailability(String id, bool available) =>
      _mutate(() => _backend.setItemAvailability(id, available));

  Future<MenuCategory> addCategory(String name, {String nameKm = ''}) =>
      _mutate(() => _backend.addCategory(name, nameKm: nameKm));

  Future<void> renameCategory(String id, String name, {String nameKm = ''}) =>
      _mutate(() => _backend.renameCategory(id, name, nameKm: nameKm));

  /// Removes a category together with the dishes filed under it.
  Future<void> deleteCategory(String id) =>
      _mutate(() => _backend.deleteCategory(id));

  // ----------------------------------------------------------- table admin

  Future<RestaurantTable> addTable() => _mutate(() => _backend.addTable());

  Future<void> renameTable(String id, String name) =>
      _mutate(() => _backend.renameTable(id, name));

  /// A table with an order still in progress cannot be removed.
  Future<void> deleteTable(String id) async {
    await _mutate(() => _backend.deleteTable(id));
    if (_activeTableId == id) {
      _activeTableId = null;
      _cart = [];
      _cartNote = '';
      _commit();
    }
  }

  // -------------------------------------------------------------- settings

  Future<void> updateSettings(RestaurantSettings settings) =>
      _mutate(() => _backend.updateSettings(settings));

  // ------------------------------------------------------------- plan limits

  /// True when the plan has no room for another staff account.
  ///
  /// The database decides — the caps are enforced by triggers in
  /// `0006_plans.sql` — but the screens ask this first so the answer to "why
  /// can I not add another?" arrives before the attempt rather than after it
  /// fails.
  bool get atStaffLimit => !settings.plan.canAddStaff(accounts.length);
  bool get atTableLimit => !settings.plan.canAddTable(tables.length);

  Future<void> requestUpgrade({
    required Plan toPlan,
    required UpgradeReason reason,
    required String contactName,
    required String contactPhone,
    String note = '',
  }) =>
      _mutate(() => _backend.requestUpgrade(
            toPlan: toPlan,
            reason: reason,
            contactName: contactName,
            contactPhone: contactPhone,
            note: note,
          ));

  Future<void> cancelUpgradeRequest() =>
      _mutate(() => _backend.cancelUpgradeRequest());
}

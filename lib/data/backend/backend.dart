import '../../models/cart_line.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';
import '../../models/order.dart';
import '../../models/restaurant_settings.dart';
import '../../models/plan.dart';
import '../../models/restaurant_table.dart';
import '../../models/staff_account.dart';
import '../../models/upgrade_request.dart';

/// A failure worth trying again.
///
/// The wifi dropped, the request timed out, DNS went odd mid-service. The
/// order was not refused — it never arrived. That is a different thing from
/// the database saying no, and the difference decides whether retrying is
/// sensible or whether it will fail identically forever.
///
/// Deliberately a [StateError]: every screen already catches those and shows
/// the message, so an unclassified failure still behaves exactly as it did.
/// Code that wants to queue and retry catches this narrower type instead.
class TransientFailure extends StateError {
  TransientFailure(super.message);
}

/// Everything the restaurant shares: its profile, its menu, its tables, its
/// orders and who can sign in.
///
/// Deliberately *not* everything the app knows. Which table this phone
/// scanned, what is in this diner's cart, which language this device is set
/// to — none of that belongs to the restaurant, and none of it is here. That
/// stays on the device whichever backend is in use.
class RestaurantData {
  const RestaurantData({
    required this.settings,
    required this.categories,
    required this.menuItems,
    required this.tables,
    required this.orders,
    required this.accounts,
    required this.support,
    this.upgradeRequest,
  });

  final RestaurantSettings settings;
  final List<MenuCategory> categories;
  final List<MenuItem> menuItems;
  final List<RestaurantTable> tables;
  final List<Order> orders;
  final List<StaffAccount> accounts;

  /// How to reach the people running the service. Platform-level rather than
  /// restaurant-level, and it rides along here because it is read on the same
  /// trip and changes about as often as the menu does — which is to say
  /// almost never, and never at a moment worth a second round trip.
  final SupportContact support;

  /// The merchant's open request for a bigger plan, if they have one. Null is
  /// the ordinary case: most restaurants are not asking for anything.
  final UpgradeRequest? upgradeRequest;

  RestaurantData copyWith({
    RestaurantSettings? settings,
    List<MenuCategory>? categories,
    List<MenuItem>? menuItems,
    List<RestaurantTable>? tables,
    List<Order>? orders,
    List<StaffAccount>? accounts,
    SupportContact? support,
    UpgradeRequest? upgradeRequest,
    // A request that has just been withdrawn has to be able to become null,
    // which `upgradeRequest ?? this.upgradeRequest` can never express.
    bool clearUpgradeRequest = false,
  }) =>
      RestaurantData(
        settings: settings ?? this.settings,
        categories: categories ?? this.categories,
        menuItems: menuItems ?? this.menuItems,
        tables: tables ?? this.tables,
        orders: orders ?? this.orders,
        accounts: accounts ?? this.accounts,
        support: support ?? this.support,
        upgradeRequest: clearUpgradeRequest
            ? null
            : (upgradeRequest ?? this.upgradeRequest),
      );
}

/// Where the restaurant's data actually lives.
///
/// Two implementations: [LocalBackend] keeps it on the device, which is the
/// demo and what the tests run against; [SupabaseBackend] keeps it in Postgres,
/// which is what makes the kitchen tablet and the diner's phone two views of
/// one restaurant rather than two unrelated apps.
///
/// Every mutation returns a Future and every one may throw [StateError] with a
/// message meant for a human — the UI shows these directly. Permission and
/// state-machine failures come back the same way whichever backend is in use;
/// on Supabase they originate in Postgres, which is the point.
abstract class Backend {
  /// True when this is the on-device demo rather than a real database.
  bool get isDemo;

  /// Reads everything. Called once at startup and again after anything the
  /// backend cannot report incrementally.
  Future<RestaurantData> load();

  /// The data as the backend last saw it. Read straight after a mutation, so
  /// the screen that triggered it repaints without waiting for a round trip
  /// it has already made.
  RestaurantData get current;

  /// Fires whenever the data changed underneath us — another device took an
  /// order, the kitchen started cooking. The local backend never fires it;
  /// there is nobody else to hear from.
  Stream<RestaurantData> get changes;

  Future<void> dispose();

  // ------------------------------------------------------------------- auth

  /// Whoever is signed in, or null. Kept by the backend because on Supabase
  /// the session outlives the app.
  StaffAccount? get currentUser;

  /// Owners sign in with their email address and a password; kitchen and
  /// cashier tap a name and enter a PIN. Both return null when the credentials
  /// are wrong or the account is turned off — never a reason, so neither can
  /// be probed.
  ///
  /// [identifier] is whatever was typed. An address is used as it stands; a
  /// bare word is the older per-restaurant username, which still works.
  Future<StaffAccount?> signInWithPassword(String identifier, String password);
  Future<StaffAccount?> signInWithPin(String accountId, String pin);

  /// Emails an owner a link to set a new password.
  ///
  /// Owners only. Kitchen and cashier staff have no address — they tap a name
  /// and key in a PIN — and the owner resets those from the staff screen. An
  /// owner locked out of their own restaurant has nobody above them to ask,
  /// which is the whole reason this exists.
  ///
  /// Deliberately says nothing about whether the address belongs to anybody.
  /// A form that answers that question is a way to find out who banks here.
  Future<void> sendPasswordReset(String email);

  /// Sets a new password for whoever the recovery link signed in.
  ///
  /// Only meaningful while a recovery session is open — the link in the email
  /// is what authorises this, and it expires.
  Future<void> setNewPassword(String password);

  /// Fires when a recovery link has been followed and a new password is now
  /// wanted. Never fires on a backend with no email behind it.
  Stream<void> get passwordRecovery;
  Future<void> signOut();

  // ----------------------------------------------------------------- orders

  /// Rule 11 — a dine-in order carries its table, takeaway carries none.
  /// Rule 12 — the number is unique, and the backend hands it out.
  Future<Order> placeOrder({
    required OrderType type,
    String? tableId,
    required List<CartLine> lines,
    String note = '',
    bool onBehalfOfCustomer = false,
    /// Minted on the device before the first attempt and kept across retries,
    /// so an order sent twice after a dropped connection is placed once. See
    /// `0013_idempotent_orders.sql`.
    String? clientKey,
  });

  /// Rule 6 — kitchen owns NEW -> COOKING -> READY.
  Future<void> startCooking(String orderId);
  Future<void> markReady(String orderId);

  /// Rule 7 — cashier owns READY -> PAID -> COMPLETED.
  Future<void> collectPayment(String orderId, String paymentMethod);
  Future<void> completeOrder(String orderId);

  /// Only while the order is still queued.
  Future<void> cancelOrder(String orderId);
  Future<void> setOrderItemQuantity(String orderId, String itemId, int quantity);

  // ------------------------------------------------------------------- menu

  Future<void> addMenuItem(MenuItem item);
  Future<void> updateMenuItem(MenuItem item);
  Future<void> deleteMenuItem(String id);
  Future<void> setItemAvailability(String id, bool available);

  Future<MenuCategory> addCategory(String name, {String nameKm = ''});
  Future<void> renameCategory(String id, String name, {String nameKm = ''});
  Future<void> deleteCategory(String id);

  // ----------------------------------------------------------------- tables

  Future<RestaurantTable> addTable();
  Future<void> renameTable(String id, String name);
  Future<void> deleteTable(String id);

  // ------------------------------------------------------------------ staff

  /// Creates an account. An admin needs an [email] — that is what they will
  /// sign in with — and everyone else a six digit PIN.
  Future<StaffAccount> addStaff({
    required String name,
    required StaffRole role,
    required String secret,
    String username = '',
    String email = '',
  });
  /// Changes the address the signed-in owner uses to sign in.
  ///
  /// Their own, and only their own: this moves an auth identity, which is not
  /// something one person should be able to do to another.
  Future<void> setMyLoginEmail(String email);

  Future<void> renameStaff(String id, String name);
  Future<void> resetStaffSecret(String id, String secret);
  Future<void> setStaffActive(String id, bool active);
  Future<void> deleteStaff(String id);

  // --------------------------------------------------------------- settings

  Future<void> updateSettings(RestaurantSettings settings);

  // ------------------------------------------------------------- plan change

  /// Asks to be moved onto a bigger plan.
  ///
  /// There is no billing, so this files a request rather than taking money:
  /// it lands in the operator's console and the owner sees that it did. Asking
  /// twice edits the first request instead of filing a second — a support
  /// queue holding four copies of one ask is worse than no queue.
  Future<void> requestUpgrade({
    required Plan toPlan,
    required UpgradeReason reason,
    required String contactName,
    required String contactPhone,
    String note = '',
  });

  /// Withdraws the open request. An owner who asked by mistake should not have
  /// to live with a card on their pricing screen they cannot dismiss.
  Future<void> cancelUpgradeRequest();

  /// Throws on a real backend: there is no demo data to put back, and wiping a
  /// live restaurant from a settings screen is not a feature.
  Future<void> resetDemoData();
}

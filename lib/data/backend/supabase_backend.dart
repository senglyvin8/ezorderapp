import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/backend_config.dart';
import '../../models/cart_line.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';
import '../../models/order.dart';
import '../../models/restaurant_settings.dart';
import '../../models/restaurant_table.dart';
import '../../models/staff_account.dart';
import 'backend.dart';

/// The restaurant, kept in Postgres.
///
/// Two things make this different from [LocalBackend] rather than just further
/// away:
///
///  * **The rules are the database's.** Every mutation is an RPC that checks
///    the caller's role and the order's state in SQL before it writes. This
///    class does not decide whether a cashier may cancel an order; it asks,
///    and surfaces the refusal. A patched build of this app cannot talk its
///    way past it.
///  * **Somebody else is writing too.** Realtime keeps the kitchen tablet, the
///    till and the diner's phone looking at the same orders.
///
/// Errors come back as [StateError] carrying the database's own message, so
/// the screens can keep the `on StateError` / toast pattern they already use.
class SupabaseBackend implements Backend {
  SupabaseBackend(this._client);

  final SupabaseClient _client;

  final StreamController<RestaurantData> _changes =
      StreamController<RestaurantData>.broadcast();
  RealtimeChannel? _channel;

  String? _restaurantId;
  StaffAccount? _currentUser;
  RestaurantData? _cache;

  @override
  bool get isDemo => false;

  @override
  Stream<RestaurantData> get changes => _changes.stream;

  @override
  RestaurantData get current =>
      _cache ??
      (throw StateError('The restaurant has not finished loading yet'));

  @override
  StaffAccount? get currentUser => _currentUser;

  @override
  Future<void> dispose() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await _client.removeChannel(channel);
    await _changes.close();
  }

  /// Turns a Postgres or auth failure into the same kind of error the rest of
  /// the app already handles.
  ///
  /// Database messages are written for the person holding the phone — "Order
  /// #113 is COOKING, it cannot move from NEW" — so they are shown as-is
  /// rather than replaced with something vaguer.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      throw StateError(_clean(e.message));
    } on AuthException catch (e) {
      throw StateError(_clean(e.message));
    } on StateError {
      rethrow;
    } catch (e) {
      throw StateError('Could not reach the restaurant’s database. $e');
    }
  }

  /// Postgres prefixes messages raised by a function; the reader does not need
  /// to see that.
  static String _clean(String message) {
    final trimmed = message.trim();
    for (final prefix in const ['ERROR:', 'error:', 'PostgrestException:']) {
      if (trimmed.startsWith(prefix)) {
        return trimmed.substring(prefix.length).trim();
      }
    }
    return trimmed;
  }

  // ---------------------------------------------------------------- loading

  @override
  Future<RestaurantData> load() => _guard(() async {
        // A diner has no account, but RLS needs an identity to scope "my
        // orders" to. An anonymous session is that identity — it costs the
        // diner nothing and never asks them for anything.
        if (_client.auth.currentUser == null) {
          await _client.auth.signInAnonymously();
        }

        final restaurant = await _client
            .from('restaurants')
            .select()
            .eq('slug', BackendConfig.slug)
            .maybeSingle();

        if (restaurant == null) {
          throw StateError(
            'No restaurant with the slug "${BackendConfig.slug}". '
            'Check RESTAURANT_SLUG, or run provision_restaurant() first.',
          );
        }
        _restaurantId = restaurant['id'] as String;

        await _refreshCurrentUser();
        final data = await _fetchAll(restaurant);
        _cache = data;
        _subscribe();
        return data;
      });

  Future<RestaurantData> _fetchAll(Map<String, dynamic> restaurant) async {
    final id = _restaurantId!;

    // Issued together rather than one after another: five sequential round
    // trips is a visible pause on a phone in a restaurant.
    final categories = _client.from('categories').select().eq('restaurant_id', id);
    final menuItems = _client.from('menu_items').select().eq('restaurant_id', id);
    final tables =
        _client.from('restaurant_tables').select().eq('restaurant_id', id);
    final orders = _fetchOrders();
    final accounts = _fetchAccounts();

    return RestaurantData(
      settings: _settingsFrom(restaurant),
      categories: (await categories)
          .map(_categoryFrom)
          .sorted((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      menuItems: (await menuItems).map(_menuItemFrom).toList(),
      tables: (await tables)
          .map(_tableFrom)
          .sorted((a, b) => a.number.compareTo(b.number)),
      orders: await orders,
      accounts: await accounts,
    );
  }

  /// One round trip for orders and their lines: PostgREST can embed the child
  /// rows, and a kitchen board that issued one query per ticket would be
  /// unusable on a restaurant's wifi.
  Future<List<Order>> _fetchOrders() async {
    final rows = await _client
        .from('orders')
        .select('*, order_items(*)')
        .eq('restaurant_id', _restaurantId!)
        .order('created_at');
    return rows.map(_orderFrom).toList();
  }

  /// Signed in, the full staff list. Signed out, the public directory — the
  /// PIN pad has to show names to tap before anyone is anyone.
  Future<List<StaffAccount>> _fetchAccounts() async {
    if (_currentUser != null) {
      final rows = await _client
          .from('staff')
          .select()
          .eq('restaurant_id', _restaurantId!);
      return rows.map(_staffFrom).toList();
    }
    final rows = await _client.rpc<List<dynamic>>(
      'staff_directory',
      params: {'p_slug': BackendConfig.slug},
    );
    return rows.map((r) => _staffFrom(r as Map<String, dynamic>)).toList();
  }

  Future<void> _refreshCurrentUser() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _currentUser = null;
      return;
    }
    final row = await _client.from('staff').select().eq('id', uid).maybeSingle();
    _currentUser = row == null ? null : _staffFrom(row);
  }

  // --------------------------------------------------------------- realtime

  /// What makes the live board live, and the live menu live.
  ///
  /// Two kinds of change, handled differently because they cost differently:
  ///
  ///  * **Orders** move constantly, and only the order list needs re-reading.
  ///  * **The menu** barely moves, but when it does everything downstream of
  ///    it is stale, so the whole restaurant is re-read. This is what makes an
  ///    owner adding a dish appear on a diner's already-open phone instead of
  ///    waiting for them to reload — and, more importantly, what stops a
  ///    customer ordering something taken off the menu five minutes ago.
  ///
  /// Either way it refetches rather than applying row deltas. At a
  /// restaurant's volume — a few rows a minute — that is cheaper than
  /// reconstructing state by hand and getting it subtly wrong.
  void _subscribe() {
    if (_channel != null) return;
    final channel = _client.channel('restaurant:$_restaurantId');

    for (final table in const ['orders', 'order_items']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => unawaited(_pushOrders()),
      );
    }
    for (final table in const [
      'categories',
      'menu_items',
      'restaurant_tables',
      'restaurants',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => unawaited(_pushEverything()),
      );
    }
    _channel = channel..subscribe();
  }

  /// Realtime filters events through row level security using the identity the
  /// channel subscribed with. Signing in or out changes that identity, so the
  /// channel has to be rebuilt — otherwise a cook who has just signed in keeps
  /// receiving the anonymous view and never sees a new ticket land.
  Future<void> _resubscribe() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await _client.removeChannel(channel);
    _subscribe();
  }

  /// A menu change invalidates more than the orders, so re-read the lot.
  Future<void> _pushEverything() async {
    if (_cache == null || _changes.isClosed) return;
    try {
      await _reload();
    } catch (_) {
      // A dropped refresh is not worth interrupting service over.
    }
  }

  Future<void> _pushOrders() async {
    if (_cache == null || _changes.isClosed) return;
    try {
      final orders = await _fetchOrders();
      _cache = _cache!.copyWith(orders: orders);
      if (!_changes.isClosed) _changes.add(_cache!);
    } catch (_) {
      // A dropped refresh is not worth interrupting service over — the next
      // change, or the next reload, puts it right.
    }
  }

  Future<void> _reload() async {
    if (_restaurantId == null) return;
    final restaurant = await _client
        .from('restaurants')
        .select()
        .eq('id', _restaurantId!)
        .single();
    _cache = await _fetchAll(restaurant);
    if (!_changes.isClosed) _changes.add(_cache!);
  }

  // ------------------------------------------------------------------- auth

  @override
  Future<StaffAccount?> signInWithPassword(String username, String password) =>
      _guard(() => _signIn(BackendConfig.loginEmail(username.trim()), password));

  @override
  Future<StaffAccount?> signInWithPin(String accountId, String pin) =>
      _guard(() => _signIn(BackendConfig.loginEmail(accountId), pin));

  Future<StaffAccount?> _signIn(String email, String secret) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: secret);
    } on AuthException {
      // Wrong secret, unknown account, deactivated — all the same answer, so
      // none of them can be told apart by trying.
      return null;
    }
    await _refreshCurrentUser();
    if (_currentUser == null || !_currentUser!.active) {
      await _client.auth.signOut();
      _currentUser = null;
      return null;
    }
    await _reload();
    await _resubscribe();
    return _currentUser;
  }

  @override
  Future<void> signOut() => _guard(() async {
        await _client.auth.signOut();
        _currentUser = null;
        // Straight back to an anonymous session: the device is a customer
        // again, and the customer app still needs to read the menu.
        await _client.auth.signInAnonymously();
        await _reload();
        await _resubscribe();
      });

  // ----------------------------------------------------------------- orders

  @override
  Future<Order> placeOrder({
    required OrderType type,
    String? tableId,
    required List<CartLine> lines,
    String note = '',
    bool onBehalfOfCustomer = false,
  }) =>
      _guard(() async {
        if (lines.isEmpty) throw StateError('The cart is empty');

        // Only the dish and the quantity are sent. The price is read from the
        // menu inside place_order(), so a patched client cannot invent one.
        final orderId = await _client.rpc<String>('place_order', params: {
          'p_restaurant_id': _restaurantId,
          'p_type': type.wire,
          'p_table_id': tableId,
          'p_note': note.trim(),
          'p_items': [
            for (final line in lines)
              {
                'food_id': line.foodId,
                'quantity': line.quantity,
                'note': line.note,
              }
          ],
        });

        final row = await _client
            .from('orders')
            .select('*, order_items(*)')
            .eq('id', orderId)
            .single();
        await _pushOrders();
        return _orderFrom(row);
      });

  @override
  Future<void> startCooking(String orderId) =>
      _rpcVoid('start_cooking', {'p_order_id': orderId});

  @override
  Future<void> markReady(String orderId) =>
      _rpcVoid('mark_ready', {'p_order_id': orderId});

  @override
  Future<void> collectPayment(String orderId, String paymentMethod) => _rpcVoid(
      'collect_payment', {'p_order_id': orderId, 'p_method': paymentMethod});

  @override
  Future<void> completeOrder(String orderId) =>
      _rpcVoid('complete_order', {'p_order_id': orderId});

  @override
  Future<void> cancelOrder(String orderId) =>
      _rpcVoid('cancel_order', {'p_order_id': orderId});

  @override
  Future<void> setOrderItemQuantity(
          String orderId, String itemId, int quantity) =>
      _rpcVoid('set_order_item_quantity', {
        'p_order_id': orderId,
        'p_item_id': itemId,
        'p_quantity': quantity,
      });

  /// Calls a mutation and refreshes the board. Realtime will report the change
  /// too, but not before this future completes — and a button that stays stale
  /// until a socket catches up feels broken.
  Future<void> _rpcVoid(String fn, Map<String, dynamic> params) =>
      _guard(() async {
        await _client.rpc<void>(fn, params: params);
        await _pushOrders();
      });

  // ------------------------------------------------------------- menu admin

  /// Moves an uploaded picture out of the row and into Storage.
  ///
  /// The editor hands over base64, because that is what a file picker and a
  /// camera produce. Putting that in the column is what made a one-dish menu
  /// 268 KB — every diner downloading every photo on every load. So the bytes
  /// go to a public bucket and the row keeps a URL, which a CDN serves and a
  /// browser caches.
  ///
  /// Files are `<restaurant_id>/<uuid>.jpg`; the folder is what Storage's
  /// policies check, so one restaurant's admin cannot write into another's.
  Future<MenuItem> _withPhotoUploaded(MenuItem item) async {
    final raw = item.photo;
    if (raw == null || raw.isEmpty) return item;

    final Uint8List bytes;
    try {
      bytes = base64Decode(raw);
    } catch (_) {
      // Not decodable, so not a picture. Drop it rather than storing a column
      // full of something nobody can render.
      return item.copyWith(clearPhoto: true);
    }

    final path = '$_restaurantId/${_uuid()}.jpg';
    await _client.storage.from(_photoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
            cacheControl: '31536000',
          ),
        );
    final url = _client.storage.from(_photoBucket).getPublicUrl(path);
    // The base64 is left on the in-memory object and simply never written:
    // _menuItemValues always sends `photo: null` on this backend, and the
    // reload that follows replaces it with what the row actually holds.
    return item.copyWith(photoUrl: url);
  }

  static const String _photoBucket = 'menu-photos';

  /// Enough uniqueness for a filename; the row's own id is not available yet
  /// when a dish is being created.
  String _uuid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_photoSeq++}';
  int _photoSeq = 0;

  @override
  Future<void> addMenuItem(MenuItem item) => _guard(() async {
        final stored = await _withPhotoUploaded(item);
        await _client.from('menu_items').insert({
          'restaurant_id': _restaurantId,
          ..._menuItemValues(stored),
        });
        await _reload();
      });

  @override
  Future<void> updateMenuItem(MenuItem item) => _guard(() async {
        final stored = await _withPhotoUploaded(item);
        await _client
            .from('menu_items')
            .update(_menuItemValues(stored))
            .eq('id', item.id);
        await _reload();
      });

  @override
  Future<void> deleteMenuItem(String id) => _guard(() async {
        await _client.from('menu_items').delete().eq('id', id);
        await _reload();
      });

  @override
  Future<void> setItemAvailability(String id, bool available) =>
      _guard(() async {
        await _client
            .from('menu_items')
            .update({'available': available}).eq('id', id);
        await _reload();
      });

  @override
  Future<MenuCategory> addCategory(String name, {String nameKm = ''}) =>
      _guard(() async {
        final existing = _cache?.categories ?? const <MenuCategory>[];
        final nextOrder = existing.isEmpty
            ? 1
            : existing.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) +
                1;
        final row = await _client
            .from('categories')
            .insert({
              'restaurant_id': _restaurantId,
              'name': name.trim(),
              'name_km': nameKm.trim(),
              'sort_order': nextOrder,
            })
            .select()
            .single();
        await _reload();
        return _categoryFrom(row);
      });

  @override
  Future<void> renameCategory(String id, String name, {String nameKm = ''}) =>
      _guard(() async {
        await _client
            .from('categories')
            .update({'name': name.trim(), 'name_km': nameKm.trim()}).eq(
                'id', id);
        await _reload();
      });

  @override
  Future<void> deleteCategory(String id) => _guard(() async {
        // The dishes go with it — `on delete cascade` in the schema, matching
        // the warning the admin screen shows.
        await _client.from('categories').delete().eq('id', id);
        await _reload();
      });

  // ------------------------------------------------------------ table admin

  @override
  Future<RestaurantTable> addTable() => _guard(() async {
        final existing = _cache?.tables ?? const <RestaurantTable>[];
        final used = existing.map((t) => int.tryParse(t.number) ?? 0).toList();
        final next =
            (used.isEmpty ? 0 : used.reduce((a, b) => a > b ? a : b)) + 1;
        final number = next.toString().padLeft(2, '0');

        final row = await _client
            .from('restaurant_tables')
            .insert({
              'restaurant_id': _restaurantId,
              'number': number,
              'name': 'Table $number',
              'qr_id': RestaurantTable.qrIdFor(number),
            })
            .select()
            .single();
        await _reload();
        return _tableFrom(row);
      });

  @override
  Future<void> renameTable(String id, String name) => _guard(() async {
        await _client
            .from('restaurant_tables')
            .update({'name': name.trim()}).eq('id', id);
        await _reload();
      });

  @override
  Future<void> deleteTable(String id) => _guard(() async {
        final busy = (_cache?.orders ?? const <Order>[]).any(
            (o) => !o.isTakeaway && o.tableId == id && o.status.isActive);
        if (busy) throw StateError('This table still has an active order');
        await _client.from('restaurant_tables').delete().eq('id', id);
        await _reload();
      });

  // ------------------------------------------------------------------ staff

  @override
  Future<StaffAccount> addStaff({
    required String name,
    required StaffRole role,
    required String secret,
    String username = '',
  }) =>
      _guard(() async {
        if (role != StaffRole.admin &&
            secret.length != StaffAccount.pinLength) {
          throw StateError('A PIN must be ${StaffAccount.pinLength} digits');
        }
        final id = await _client.rpc<String>('create_staff_account', params: {
          'p_name': name.trim(),
          'p_role': role.wire,
          'p_secret': secret,
          'p_username': username.trim(),
        });
        await _reload();
        return (_cache?.accounts ?? const <StaffAccount>[])
                .firstWhereOrNull((a) => a.id == id) ??
            StaffAccount(
                id: id, name: name.trim(), role: role, username: username);
      });

  @override
  Future<void> renameStaff(String id, String name) => _guard(() async {
        await _client.from('staff').update({'name': name.trim()}).eq('id', id);
        await _reload();
      });

  @override
  Future<void> resetStaffSecret(String id, String secret) => _guard(() async {
        await _client.rpc<void>('reset_staff_secret',
            params: {'p_staff_id': id, 'p_secret': secret});
      });

  @override
  Future<void> setStaffActive(String id, bool active) => _guard(() async {
        await _client.rpc<void>('set_staff_active',
            params: {'p_staff_id': id, 'p_active': active});
        if (!active && id == _currentUser?.id) await signOut();
        await _reload();
      });

  @override
  Future<void> deleteStaff(String id) => _guard(() async {
        await _client.rpc<void>('delete_staff_account',
            params: {'p_staff_id': id});
        await _reload();
      });

  // --------------------------------------------------------------- settings

  @override
  Future<void> updateSettings(RestaurantSettings settings) => _guard(() async {
        await _client.from('restaurants').update({
          'name': settings.name,
          'name_km': settings.nameKm,
          'logo': settings.logo,
          'phone': settings.phone,
          'address': settings.address,
          'currency_symbol': settings.currencySymbol,
          'currency_code': settings.currencyCode,
          'payment_methods': settings.paymentMethods,
        }).eq('id', _restaurantId!);
        await _reload();
      });

  @override
  Future<void> resetDemoData() async {
    throw StateError(
      'There is no demo data to restore — this restaurant is live.',
    );
  }

  // ---------------------------------------------------------------- mapping

  static RestaurantSettings _settingsFrom(Map<String, dynamic> r) =>
      RestaurantSettings(
        name: r['name'] as String,
        nameKm: r['name_km'] as String? ?? '',
        logo: r['logo'] as String? ?? '🍽️',
        phone: r['phone'] as String? ?? '',
        address: r['address'] as String? ?? '',
        currencySymbol: r['currency_symbol'] as String? ?? r'$',
        currencyCode: r['currency_code'] as String? ?? 'USD',
        paymentMethods:
            ((r['payment_methods'] as List?) ?? const []).cast<String>(),
      );

  static MenuCategory _categoryFrom(Map<String, dynamic> r) => MenuCategory(
        id: r['id'] as String,
        name: r['name'] as String,
        nameKm: r['name_km'] as String? ?? '',
        sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
      );

  static MenuItem _menuItemFrom(Map<String, dynamic> r) => MenuItem(
        id: r['id'] as String,
        name: r['name'] as String,
        nameKm: r['name_km'] as String? ?? '',
        description: r['description'] as String? ?? '',
        descriptionKm: r['description_km'] as String? ?? '',
        price: _toDouble(r['price']),
        categoryId: r['category_id'] as String,
        image: r['image'] as String? ?? 'plate',
        photo: r['photo'] as String?,
        photoUrl: r['photo_url'] as String?,
        discountPercent: (r['discount_percent'] as num?)?.toInt() ?? 0,
        available: r['available'] as bool? ?? true,
        popular: r['popular'] as bool? ?? false,
        signature: r['signature'] as bool? ?? false,
      );

  static Map<String, dynamic> _menuItemValues(MenuItem m) => {
        'category_id': m.categoryId,
        'name': m.name,
        'name_km': m.nameKm,
        'description': m.description,
        'description_km': m.descriptionKm,
        'price': m.price,
        'discount_percent': m.discountPercent,
        'image': m.image,
        // Deliberately null: on this backend the bytes live in Storage and the
        // row keeps only the URL.
        'photo': null,
        'photo_url': m.photoUrl,
        'available': m.available,
        'popular': m.popular,
        'signature': m.signature,
      };

  static RestaurantTable _tableFrom(Map<String, dynamic> r) => RestaurantTable(
        id: r['id'] as String,
        number: r['number'] as String,
        name: (r['name'] as String?)?.isNotEmpty == true
            ? r['name'] as String
            : 'Table ${r['number']}',
        qrId: r['qr_id'] as String,
      );

  static StaffAccount _staffFrom(Map<String, dynamic> r) => StaffAccount(
        id: r['id'] as String,
        name: r['name'] as String,
        role: StaffRole.fromWire(r['role'] as String),
        username: r['username'] as String? ?? '',
        active: r['active'] as bool? ?? true,
      );

  static Order _orderFrom(Map<String, dynamic> r) {
    final items = ((r['order_items'] as List?) ?? const [])
        .map((i) => _orderItemFrom(i as Map<String, dynamic>))
        .toList();
    return Order(
      id: r['id'] as String,
      orderNumber: '${r['order_number']}',
      type: OrderType.fromWire(r['type'] as String? ?? 'DINE_IN'),
      tableId: r['table_id'] as String?,
      tableNumber: r['table_number'] as String?,
      items: items,
      subtotal: _toDouble(r['subtotal']),
      total: _toDouble(r['total']),
      customerNote: r['customer_note'] as String?,
      status: OrderStatus.fromWire(r['status'] as String),
      paymentMethod: r['payment_method'] as String?,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      paidAt: _toDate(r['paid_at']),
      placedBy: r['placed_by'] as String?,
      cancelledBy: r['cancelled_by'] as String?,
      cancelledAt: _toDate(r['cancelled_at']),
    );
  }

  static OrderItem _orderItemFrom(Map<String, dynamic> r) => OrderItem(
        id: r['id'] as String,
        foodId: r['food_id'] as String? ?? '',
        name: r['name'] as String,
        nameKm: r['name_km'] as String? ?? '',
        price: _toDouble(r['price']),
        quantity: (r['quantity'] as num).toInt(),
        note: r['note'] as String?,
      );

  /// `numeric` arrives as a String over the wire, not a double.
  static double _toDouble(Object? value) => switch (value) {
        num n => n.toDouble(),
        String s => double.tryParse(s) ?? 0,
        _ => 0,
      };

  static DateTime? _toDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();
}

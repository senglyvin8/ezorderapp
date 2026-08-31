import '../l10n/app_text.dart';

/// Where the food is going.
enum OrderType {
  dineIn('DINE_IN'),
  takeaway('TAKEAWAY');

  const OrderType(this.wire);
  final String wire;

  static OrderType fromWire(String value) => OrderType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => OrderType.dineIn,
      );

  bool get needsTable => this == OrderType.dineIn;
}

/// Lifecycle of an order.
///
/// Kitchen owns `NEW -> COOKING -> READY` (Rule 6).
/// Cashier owns `READY -> PAID -> COMPLETED` (Rule 7).
///
/// `CANCELLED` is a dead end reachable only from `NEW`: once a pan is on the
/// heat the food exists whether or not the customer still wants it, so the
/// cashier can only pull an order back before the kitchen starts.
enum OrderStatus {
  newOrder('NEW', 'New Order'),
  cooking('COOKING', 'In Progress'),
  ready('READY', 'Ready to Serve'),
  paid('PAID', 'Paid'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled');

  const OrderStatus(this.wire, this.label);

  /// Value stored in JSON, matching the agreed data model.
  final String wire;
  final String label;

  static OrderStatus fromWire(String value) => OrderStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => OrderStatus.newOrder,
      );

  bool get isActive =>
      this != OrderStatus.completed && this != OrderStatus.cancelled;

  /// Only a queued order can still be pulled back — see the enum doc.
  bool get isCancellable => this == OrderStatus.newOrder;

  /// Position in the customer-facing tracker. A cancelled order sits outside
  /// the ladder entirely, so it lights no step at all.
  int get trackerIndex => switch (this) {
        OrderStatus.newOrder => 0,
        OrderStatus.cooking => 1,
        OrderStatus.ready => 3, // ready to serve, now waiting for payment
        OrderStatus.paid => 4,
        OrderStatus.completed => 5,
        OrderStatus.cancelled => -1,
      };
}

/// One line of an order. Quantity and note are captured at add-to-cart time.
class OrderItem {
  const OrderItem({
    required this.id,
    required this.foodId,
    required this.name,
    required this.price,
    required this.quantity,
    this.nameKm = '',
    this.note,
  });

  final String id;
  final String foodId;
  final String name;

  /// Khmer name captured when the dish was ordered.
  final String nameKm;

  /// Unit price actually charged, after any discount.
  final double price;
  final int quantity;
  final String? note;

  double get lineTotal => price * quantity;

  String displayName(AppLanguage lang) =>
      lang == AppLanguage.km && nameKm.trim().isNotEmpty ? nameKm : name;

  OrderItem copyWith({int? quantity, String? note, bool clearNote = false}) =>
      OrderItem(
        id: id,
        foodId: foodId,
        name: name,
        nameKm: nameKm,
        price: price,
        quantity: quantity ?? this.quantity,
        note: clearNote ? null : (note ?? this.note),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'foodId': foodId,
        'name': name,
        if (nameKm.isNotEmpty) 'nameKm': nameKm,
        'price': price,
        'quantity': quantity,
        if (note != null) 'note': note,
      };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as String,
        foodId: json['foodId'] as String,
        name: json['name'] as String,
        nameKm: json['nameKm'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        quantity: (json['quantity'] as num).toInt(),
        note: json['note'] as String?,
      );
}

/// A submitted order.
///
/// Rule 11 as amended: a dine-in order always carries the table it was scanned
/// at; a takeaway order carries no table and is called by its number instead.
/// Rule 12 is unchanged — the number is always unique.
class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.items,
    required this.subtotal,
    required this.total,
    required this.status,
    required this.createdAt,
    this.type = OrderType.dineIn,
    this.tableId,
    this.tableNumber,
    this.customerNote,
    this.paymentMethod,
    this.paidAt,
    this.placedBy,
    this.cancelledBy,
    this.cancelledAt,
    this.clientKey,
  });

  final String id;
  final String orderNumber;
  final OrderType type;

  /// Null for takeaway.
  final String? tableId;
  final String? tableNumber;

  bool get isTakeaway => type == OrderType.takeaway;
  final List<OrderItem> items;
  final double subtotal;
  final double total;
  final String? customerNote;
  final OrderStatus status;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime? paidAt;

  /// Name of the member of staff who keyed the order in at the counter.
  /// Null when the customer placed it themselves from their own phone.
  final String? placedBy;

  /// Who cancelled it, and when. Both null unless [status] is cancelled.
  final String? cancelledBy;
  final DateTime? cancelledAt;

  /// The key the device minted before it first tried to send this order.
  ///
  /// Null for anything placed before the outbox existed, and for orders that
  /// went straight through on a working connection. It exists so that sending
  /// the same order twice — which a dropped connection makes unavoidable —
  /// places it once. See `0013_idempotent_orders.sql`.
  final String? clientKey;

  bool get isStaffPlaced => placedBy != null;

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// Item-level notes, used by the kitchen ticket.
  List<String> get itemNotes => items
      .where((i) => (i.note ?? '').trim().isNotEmpty)
      .map((i) => '${i.name}: ${i.note!.trim()}')
      .toList();

  Order copyWith({
    OrderStatus? status,
    String? paymentMethod,
    DateTime? paidAt,
    String? cancelledBy,
    DateTime? cancelledAt,
    List<OrderItem>? items,
    double? subtotal,
    double? total,
  }) =>
      Order(
        id: id,
        orderNumber: orderNumber,
        type: type,
        tableId: tableId,
        tableNumber: tableNumber,
        items: items ?? this.items,
        subtotal: subtotal ?? this.subtotal,
        total: total ?? this.total,
        customerNote: customerNote,
        status: status ?? this.status,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        createdAt: createdAt,
        paidAt: paidAt ?? this.paidAt,
        placedBy: placedBy,
        cancelledBy: cancelledBy ?? this.cancelledBy,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        clientKey: clientKey,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'type': type.wire,
        if (tableId != null) 'tableId': tableId,
        if (tableNumber != null) 'tableNumber': tableNumber,
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'total': total,
        if (customerNote != null) 'customerNote': customerNote,
        'status': status.wire,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        'createdAt': createdAt.toIso8601String(),
        if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
        if (placedBy != null) 'placedBy': placedBy,
        if (cancelledBy != null) 'cancelledBy': cancelledBy,
        if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
        if (clientKey != null) 'clientKey': clientKey,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String,
        type: OrderType.fromWire(json['type'] as String? ?? 'DINE_IN'),
        tableId: json['tableId'] as String?,
        tableNumber: json['tableNumber'] as String?,
        items: (json['items'] as List<dynamic>)
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        subtotal: (json['subtotal'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        customerNote: json['customerNote'] as String?,
        status: OrderStatus.fromWire(json['status'] as String),
        paymentMethod: json['paymentMethod'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        paidAt: json['paidAt'] == null
            ? null
            : DateTime.parse(json['paidAt'] as String),
        placedBy: json['placedBy'] as String?,
        cancelledBy: json['cancelledBy'] as String?,
        cancelledAt: json['cancelledAt'] == null
            ? null
            : DateTime.parse(json['cancelledAt'] as String),
        clientKey: json['clientKey'] as String?,
      );
}

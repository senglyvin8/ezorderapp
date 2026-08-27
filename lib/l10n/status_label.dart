import '../models/order.dart';
import 'app_text.dart';

/// Where an order goes: the table it was scanned at, or the takeaway counter.
/// Kitchen and cashier read this instead of the table number, because a
/// takeaway order has none.
String orderPlaceLabel(Order order, AppText t) => order.isTakeaway
    ? t.takeaway
    : t.table(order.tableNumber ?? '—');

/// Localised label for an order status. Kept out of [AppText] so the string
/// table has no dependency on the models.
String statusLabel(OrderStatus status, AppText t) => switch (status) {
      OrderStatus.newOrder => t.statusNew,
      OrderStatus.cooking => t.statusInProgress,
      OrderStatus.ready => t.statusReady,
      OrderStatus.paid => t.statusPaid,
      OrderStatus.completed => t.statusCompleted,
      OrderStatus.cancelled => t.statusCancelled,
    };

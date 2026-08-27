import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../l10n/app_text.dart';
import '../models/order.dart';

/// Turns a set of orders into a spreadsheet.
///
/// CSV rather than a real workbook: it opens on a double click in Excel and in
/// Google Sheets, and it is small enough to be read and checked by eye when
/// somebody disputes a figure.
///
/// Two details are what make the difference between a file that works and one
/// that looks broken to whoever opens it, and both are easy to get wrong:
///
///  * **The byte order mark.** Without it Excel reads the file as the local
///    codepage and every Khmer dish name arrives as mojibake. This app's menu
///    is bilingual, so that is not an edge case.
///  * **CRLF line endings.** Excel on Windows treats a lone newline inside a
///    quoted field inconsistently; CRLF is what it expects.
abstract class OrderExport {
  /// One row per dish, not per order.
  ///
  /// A row per order would need the dishes crammed into one cell, which cannot
  /// be summed, filtered or pivoted — the three things anybody opening this in
  /// a spreadsheet actually wants. The order-level columns repeat down the
  /// rows, which is what makes a pivot table work.
  static String csv(List<Order> orders, AppText t) {
    final date = DateFormat('yyyy-MM-dd');
    final time = DateFormat('HH:mm:ss');

    final rows = <List<String>>[
      [
        'Order number',
        'Date',
        'Time',
        'Type',
        'Table',
        'Status',
        'Dish',
        'Dish (Khmer)',
        'Unit price',
        'Quantity',
        'Line total',
        'Item note',
        'Order total',
        'Payment method',
        'Order note',
        'Taken by',
        'Cancelled by',
      ],
    ];

    for (final order in orders) {
      for (final item in order.items) {
        rows.add([
          order.orderNumber,
          date.format(order.createdAt),
          time.format(order.createdAt),
          order.isTakeaway ? 'Takeaway' : 'Dine in',
          order.tableNumber ?? '',
          order.status.label,
          item.name,
          item.nameKm,
          _money(item.price),
          '${item.quantity}',
          _money(item.lineTotal),
          item.note ?? '',
          _money(order.total),
          order.paymentMethod ?? '',
          order.customerNote ?? '',
          order.placedBy ?? '',
          order.cancelledBy ?? '',
        ]);
      }
      // An order with no lines left should still appear; a cancelled order that
      // vanishes from the export is how a report stops reconciling.
      if (order.items.isEmpty) {
        rows.add([
          order.orderNumber,
          date.format(order.createdAt),
          time.format(order.createdAt),
          order.isTakeaway ? 'Takeaway' : 'Dine in',
          order.tableNumber ?? '',
          order.status.label,
          '', '', '', '', '', '',
          _money(order.total),
          order.paymentMethod ?? '',
          order.customerNote ?? '',
          order.placedBy ?? '',
          order.cancelledBy ?? '',
        ]);
      }
    }

    return rows.map((r) => r.map(_field).join(',')).join('\r\n');
  }

  /// Bytes ready to be written to a file, byte order mark included.
  static Uint8List bytes(List<Order> orders, AppText t) {
    const bom = [0xEF, 0xBB, 0xBF];
    return Uint8List.fromList([...bom, ...utf8.encode(csv(orders, t))]);
  }

  /// Plain decimals, never the currency symbol.
  ///
  /// A cell reading `$3.50` is text as far as a spreadsheet is concerned and
  /// will not sum. The symbol belongs in the column heading, or nowhere.
  static String _money(double value) => value.toStringAsFixed(2);

  /// Quotes a field if it could otherwise break the row apart.
  ///
  /// A leading `=`, `+`, `-` or `@` is prefixed with an apostrophe: a dish
  /// named `=SUM(A1)` would otherwise be evaluated as a formula when the file
  /// is opened. That is CSV injection, and a restaurant menu is an unusually
  /// easy place to plant it.
  static String _field(String raw) {
    var value = raw.replaceAll('\r\n', ' ').replaceAll('\n', ' ');
    if (value.isNotEmpty && '=+-@\t\r'.contains(value[0])) {
      value = "'$value";
    }
    if (value.contains(',') || value.contains('"') || value.contains("'")) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// A filename that sorts chronologically and says what it holds.
  static String filename(String restaurant, DateTime when) {
    final slug = restaurant
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final stamp = DateFormat('yyyy-MM-dd-HHmm').format(when);
    return '${slug.isEmpty ? 'orders' : slug}-orders-$stamp.csv';
  }
}

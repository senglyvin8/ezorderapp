import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/data/order_export.dart';
import 'package:restaurant_qr_ordering/l10n/app_text.dart';
import 'package:restaurant_qr_ordering/models/order.dart';

/// The export is the one artefact that leaves the app and gets opened by
/// software we do not control, so the awkward cases are pinned here.
void main() {
  const t = AppText(AppLanguage.en);

  Order order({
    String number = '101',
    List<OrderItem> items = const [],
    OrderStatus status = OrderStatus.completed,
    double total = 10,
    String? note,
    String? tableNumber = '05',
  }) =>
      Order(
        id: 'o-$number',
        orderNumber: number,
        items: items,
        subtotal: total,
        total: total,
        status: status,
        createdAt: DateTime(2026, 8, 26, 14, 30, 5),
        tableNumber: tableNumber,
        customerNote: note,
      );

  OrderItem item({
    String name = 'Rice',
    String nameKm = '',
    double price = 5,
    int quantity = 2,
    String? note,
  }) =>
      OrderItem(
        id: 'i',
        foodId: 'f',
        name: name,
        nameKm: nameKm,
        price: price,
        quantity: quantity,
        note: note,
      );

  group('shape', () {
    test('one row per dish, so a spreadsheet can sum and pivot it', () {
      final csv = OrderExport.csv([
        order(items: [item(name: 'Rice'), item(name: 'Latte')])
      ], t);
      final lines = csv.split('\r\n');
      expect(lines.first, startsWith('Order number,'));
      expect(lines.length, 3, reason: 'a header and two dishes');
      expect(lines[1], contains('Rice'));
      expect(lines[2], contains('Latte'));
    });

    test('the order columns repeat down the rows', () {
      final csv = OrderExport.csv([
        order(number: '777', items: [item(), item(name: 'Latte')])
      ], t);
      expect('777'.allMatches(csv).length, greaterThanOrEqualTo(2));
    });

    test('an order with no lines still appears', () {
      // A cancelled order that vanishes from the export is how a report stops
      // reconciling against the till.
      final csv = OrderExport.csv(
          [order(number: '900', status: OrderStatus.cancelled)], t);
      expect(csv, contains('900'));
      expect(csv, contains('Cancelled'));
    });

    test('rows are CRLF terminated, which is what Excel expects', () {
      final csv = OrderExport.csv([order(items: [item()])], t);
      expect(csv, contains('\r\n'));
    });
  });

  group('fields that would otherwise break the file', () {
    test('a comma in a note does not split the row', () {
      final csv = OrderExport.csv([
        order(items: [item()], note: 'No chilli, extra lime')
      ], t);
      expect(csv, contains('"No chilli, extra lime"'));
      expect(csv.split('\r\n')[1].split('","').length, greaterThan(0));
    });

    test('a quote in a name is doubled', () {
      final csv = OrderExport.csv([
        order(items: [item(name: 'The "Special"')])
      ], t);
      expect(csv, contains('"The ""Special"""'));
    });

    test('a newline in a note is flattened, not left to break the row', () {
      final csv = OrderExport.csv([
        order(items: [item()], note: 'line one\nline two')
      ], t);
      final lines = csv.split('\r\n');
      expect(lines.length, 2, reason: 'header plus one row, not three');
      expect(csv, contains('line one line two'));
    });
  });

  group('a dish name cannot become a formula', () {
    // CSV injection: a spreadsheet evaluates a cell beginning = + - or @. A
    // menu is an unusually easy place for someone to plant one.
    for (final prefix in ['=', '+', '-', '@']) {
      test('a name starting with $prefix is neutralised', () {
        final csv = OrderExport.csv([
          order(items: [item(name: '${prefix}SUM(A1:A9)')])
        ], t);
        expect(csv, contains("'$prefix"),
            reason: 'prefixed so the spreadsheet treats it as text');
      });
    }
  });

  group('money', () {
    test('is written as a plain number so it can be summed', () {
      final csv = OrderExport.csv([
        order(items: [item(price: 3.5, quantity: 2)], total: 7)
      ], t);
      expect(csv, contains('3.50'));
      expect(csv, isNot(contains(r'$3.50')),
          reason: 'a currency symbol makes the cell text, and text will '
              'not add up');
    });
  });

  group('encoding', () {
    test('Khmer survives, because the file starts with a byte order mark', () {
      final bytes = OrderExport.bytes([
        order(items: [item(name: 'Rice', nameKm: 'បាយ')])
      ], t);
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF],
          reason: 'without this Excel reads the local codepage and Khmer '
              'arrives as mojibake');
      expect(utf8.decode(bytes.sublist(3)), contains('បាយ'));
    });
  });

  group('filename', () {
    test('sorts chronologically and names the restaurant', () {
      final name =
          OrderExport.filename('ABC Restaurant', DateTime(2026, 8, 26, 14, 30));
      expect(name, 'abc-restaurant-orders-2026-08-26-1430.csv');
    });

    test('copes with a name that is all punctuation', () {
      expect(OrderExport.filename('!!!', DateTime(2026, 8, 26)),
          startsWith('orders-orders-'));
    });
  });
}

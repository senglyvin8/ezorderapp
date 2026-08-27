import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/status_label.dart';
import '../../models/order.dart';
import '../../theme/pdf_theme.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';

/// Receipt for a settled order, with a real print / save-as-PDF action.
///
/// Closing the invoice with **Done** is what moves a PAID order to COMPLETED.
class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final order = store.order(orderId);

    if (order == null) {
      return Scaffold(
        appBar: appTopBar(title: t.invoice),
        body: EmptyState(
          icon: Icons.receipt_long_rounded,
          title: t.invoiceNotFound,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: t.invoice,
        subtitle: t.orderNo(order.orderNumber),
      ),
      body: PageWidth(
        maxWidth: 460,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            _Receipt(order: order, store: store),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Printing.layoutPdf(
                name: 'invoice-${order.orderNumber}',
                onLayout: (format) => _buildPdf(store, order),
              ),
              icon: const Icon(Icons.print_rounded),
              label: Text(t.printInvoice),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                if (order.status == OrderStatus.paid) {
                  store.completeOrder(order.id);
                }
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                order.status == OrderStatus.paid ? t.doneCloseTable : t.done,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.order, required this.store});

  final Order order;
  final AppStore store;

  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Courier', 'Menlo', 'Roboto Mono'],
    fontSize: 14.5,
    height: 1.5,
  );

  @override
  Widget build(BuildContext context) {
    final settings = store.settings;
    final t = store.text;
    final lang = store.language;
    final stamp = order.paidAt ?? order.createdAt;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            store.restaurantDisplayName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          if (settings.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              settings.address,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
            ),
          ],
          if (settings.phone.isNotEmpty)
            Text(
              settings.phone,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
            ),
          const SizedBox(height: 18),
          const _Dashes(),
          const SizedBox(height: 12),
          Text(t.orderNo(order.orderNumber), style: _mono),
          Text(orderPlaceLabel(order, t), style: _mono),
          Text(DateFormat('d MMM yyyy — h:mm a').format(stamp), style: _mono),
          const SizedBox(height: 12),
          const _Dashes(),
          const SizedBox(height: 12),
          for (final item in order.items) ...[
            Text(item.displayName(lang), style: _mono),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '  ${item.quantity} × ${store.money(item.price)}',
                    style: _mono,
                  ),
                ),
                Text(store.money(item.lineTotal), style: _mono),
              ],
            ),
            if ((item.note ?? '').isNotEmpty)
              Text('  note: ${item.note}',
                  style: _mono.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 8),
          ],
          const _Dashes(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(t.subtotal.toUpperCase(), style: _mono),
              ),
              Text(store.money(order.subtotal), style: _mono),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.total.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                store.money(order.total),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _Dashes(),
          const SizedBox(height: 12),
          Text('${t.payment}:', style: _mono),
          Text(order.paymentMethod ?? t.unpaid, style: _mono),
          if ((order.customerNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('${t.note}: ${order.customerNote}',
                style: _mono.copyWith(color: AppColors.inkSoft)),
          ],
          const SizedBox(height: 20),
          Text(
            t.thankYou,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Dashes extends StatelessWidget {
  const _Dashes();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 6).floor();
        return Text(
          List.filled(count, '-').join(),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: AppColors.inkFaint,
            height: 1,
          ),
        );
      },
    );
  }
}

/// Builds an 80mm receipt roll PDF, which prints and saves on every platform.
Future<Uint8List> _buildPdf(AppStore store, Order order) async {
  final doc = pw.Document(theme: await pdfTheme());
  final settings = store.settings;
  final t = store.text;
  final lang = store.language;
  final stamp = order.paidAt ?? order.createdAt;

  pw.Widget line(String left, String right, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 12 : 9.5,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(child: pw.Text(left, style: style)),
        pw.Text(right, style: style),
      ],
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text(
              store.restaurantDisplayName.toUpperCase(),
              style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (settings.address.isNotEmpty)
            pw.Center(
              child: pw.Text(settings.address,
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          if (settings.phone.isNotEmpty)
            pw.Center(
              child: pw.Text(settings.phone,
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          pw.SizedBox(height: 10),
          pw.Divider(height: 1),
          pw.SizedBox(height: 6),
          pw.Text(t.orderNo(order.orderNumber),
              style: const pw.TextStyle(fontSize: 9.5)),
          pw.Text(orderPlaceLabel(order, t),
              style: const pw.TextStyle(fontSize: 9.5)),
          pw.Text(DateFormat('d MMM yyyy - h:mm a').format(stamp),
              style: const pw.TextStyle(fontSize: 9.5)),
          pw.SizedBox(height: 6),
          pw.Divider(height: 1),
          pw.SizedBox(height: 6),
          for (final item in order.items) ...[
            pw.Text(item.displayName(lang),
                style: const pw.TextStyle(fontSize: 9.5)),
            line(
              '  ${item.quantity} x ${store.money(item.price)}',
              store.money(item.lineTotal),
            ),
            if ((item.note ?? '').isNotEmpty)
              pw.Text('  note: ${item.note}',
                  style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 4),
          ],
          pw.Divider(height: 1),
          pw.SizedBox(height: 4),
          line(t.subtotal.toUpperCase(), store.money(order.subtotal)),
          pw.SizedBox(height: 2),
          line(t.total.toUpperCase(), store.money(order.total), bold: true),
          pw.SizedBox(height: 8),
          pw.Divider(height: 1),
          pw.SizedBox(height: 6),
          pw.Text('${t.payment}: ${order.paymentMethod ?? t.unpaid}',
              style: const pw.TextStyle(fontSize: 9.5)),
          if ((order.customerNote ?? '').isNotEmpty)
            pw.Text('${t.note}: ${order.customerNote}',
                style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 14),
          pw.Center(
            child: pw.Text(t.thankYou,
                style: const pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/app_store.dart';
import '../../models/restaurant_table.dart';
import '../../theme/app_theme.dart';
import '../../theme/pdf_theme.dart';
import '../../widgets/app_chrome.dart';

/// Printable QR for one table.
///
/// When the prototype runs on the web the code encodes a real link back to
/// this app (`…/order/demo/table/05`), so a phone camera opens the menu for
/// that table. On mobile builds it falls back to the table identifier, which
/// the in-app scanner understands.
String qrPayloadFor(RestaurantTable table) {
  final base = Uri.base;
  if (base.scheme == 'http' || base.scheme == 'https') {
    return base
        .replace(path: table.deepLinkPath, query: null, fragment: null)
        .toString();
  }
  return table.qrId;
}

class QrScreen extends StatelessWidget {
  const QrScreen({super.key, required this.tableId});

  final String tableId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final table = store.tables.where((e) => e.id == tableId).firstOrNull;

    if (table == null) {
      return Scaffold(
        appBar: appTopBar(title: t.tableQrCode),
        body: EmptyState(
          icon: Icons.qr_code_2_rounded,
          title: t.notFound,
        ),
      );
    }

    final payload = qrPayloadFor(table);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(title: table.name, subtitle: t.tableQrCode),
      body: PageWidth(
        maxWidth: 460,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
          children: [
            AppCard(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                children: [
                  Text(
                    store.restaurantDisplayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 236,
                      gapless: true,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t.scanToOrder,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    table.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionLabel(t.encodedValue),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: SelectableText(
                payload,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: AppColors.inkSoft,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                t.identifier(table.qrId),
                style: const TextStyle(fontSize: 13.5, color: AppColors.inkFaint),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final bytes = await _buildQrPdf(store, table, payload);
                      await Printing.sharePdf(
                        bytes: bytes,
                        filename: 'table-${table.number}-qr.pdf',
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 19),
                    label: Text(t.download),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Printing.layoutPdf(
                      name: 'table-${table.number}-qr',
                      onLayout: (format) =>
                          _buildQrPdf(store, table, payload),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 19),
                    label: Text(t.printQr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A4 sheet with the QR large enough to scan from across the table.
Future<Uint8List> _buildQrPdf(
  AppStore store,
  RestaurantTable table,
  String payload,
) async {
  final doc = pw.Document(theme: await pdfTheme());

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Center(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(36),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1.4),
            borderRadius: pw.BorderRadius.circular(18),
          ),
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                store.restaurantDisplayName.toUpperCase(),
                style: const pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
              pw.SizedBox(height: 28),
              pw.BarcodeWidget(
                barcode: Barcode.qrCode(),
                data: payload,
                width: 280,
                height: 280,
                drawText: false,
              ),
              pw.SizedBox(height: 28),
              pw.Text(
                'SCAN TO ORDER',
                style: const pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(table.name, style: const pw.TextStyle(fontSize: 26)),
              pw.SizedBox(height: 20),
              pw.Text(
                table.qrId,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return doc.save();
}

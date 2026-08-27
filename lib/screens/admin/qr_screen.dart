import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/backend_config.dart';
import '../../data/app_store.dart';
import '../../models/restaurant_table.dart';
import '../../theme/app_theme.dart';
import '../../theme/pdf_theme.dart';
import '../../widgets/app_chrome.dart';

/// What a table's printed QR code carries.
///
/// The order of preference matters, because the phone showing this screen is
/// not the phone that will scan the sticker:
///
///  1. **The configured public address.** A real link a diner's camera can
///     open — the only one of these that works off a printed sticker. Set
///     `PUBLIC_URL` at build time; see `supabase/README.md`.
///  2. **Wherever this build is being served from**, when it is the web app
///     and no public address was configured. Useful while developing, useless
///     on a sticker, because it is usually `localhost`.
///  3. **The bare table identifier.** Only the in-app scanner understands
///     this. A phone camera will see a meaningless string and do nothing —
///     which is why [BackendConfig.hasPublicUrl] is worth telling the admin
///     about rather than silently printing a dud.
String qrPayloadFor(RestaurantTable table) {
  if (BackendConfig.hasPublicUrl) {
    return BackendConfig.tableLink(table.number);
  }
  final base = Uri.base;
  if (base.scheme == 'http' || base.scheme == 'https') {
    return base
        .replace(path: '/', query: null, fragment: '/${table.deepLinkPath.substring(1)}')
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
            // Printing a sticker nobody can scan is an expensive mistake to
            // discover on the restaurant floor, so say so here.
            if (!BackendConfig.hasPublicUrl && !payload.startsWith('http')) ...[
              AppCard(
                color: tint(AppColors.danger),
                elevated: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 19, color: AppColors.danger),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.qrNotScannable,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(t.qrNotScannableBody, style: AppType.label),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
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

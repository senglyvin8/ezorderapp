import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// The PDF base fonts carry neither Khmer nor the app's typeface, so receipts
/// and QR sheets embed Kantumruy Pro. Loaded once per session.
pw.Font? _appFont;

Future<pw.Font> loadAppPdfFont() async => _appFont ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/KantumruyPro.ttf'),
    );

/// Document theme that can render both scripts in the app's own face.
Future<pw.ThemeData> pdfTheme() async {
  final font = await loadAppPdfFont();
  return pw.ThemeData.withFont(base: font, bold: font, fontFallback: [font]);
}

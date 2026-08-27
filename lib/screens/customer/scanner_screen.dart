import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';

/// Live camera scanner.
///
/// Accepts anything the admin QR screen can produce: the deep link
/// `/order/demo/table/05`, a full URL ending in that path, or the raw
/// identifier `restaurant-demo-table-05`.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;
  String? _lastError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // Detections keep arriving from the camera for a frame or two after the
    // screen is popped, so this can fire on a dead widget.
    if (_handled || !mounted) return;
    final store = context.read<AppStore>();

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      final table = store.resolveScannedValue(value);
      if (table != null) {
        _handled = true;
        store.openTable(table.id);
        Navigator.of(context).pop();
        return;
      }
      setState(() => _lastError = store.text.unknownCode);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppStore>().text;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: appTopBar(title: t.scanTableQr),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraUnavailable(
              message: error.errorDetails?.message ?? t.cameraUnavailable,
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_lastError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _lastError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                Text(
                  t.pointCamera,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(t.pickTableInstead),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppStore>().text;
    return ColoredBox(
      color: AppColors.surface,
      child: EmptyState(
        icon: Icons.no_photography_rounded,
        title: t.cameraUnavailable,
        message: '$message\n\n${t.cameraHint}',
        action: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.backToTables),
        ),
      ),
    );
  }
}

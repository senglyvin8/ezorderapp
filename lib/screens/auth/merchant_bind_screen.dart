import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../config/app_config.dart';
import '../../data/merchant_binding.dart';
import '../../l10n/app_text.dart';
import '../../models/merchant_code.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';

/// Pointing a device at a merchant, once.
///
/// This is the screen that replaces `--dart-define=RESTAURANT_SLUG`, and the
/// whole design goal is that the person holding the tablet types as little as
/// possible: scan the owner's code and there is nothing to type at all.
///
/// It runs before there is an [AppStore] — there is no restaurant to have a
/// store *of* yet — so the strings are handed in rather than read from one.
class MerchantBindScreen extends StatefulWidget {
  const MerchantBindScreen({
    super.key,
    required this.text,
    required this.resolve,
    required this.onBound,
    this.current,
  });

  final AppText text;

  /// Turns a merchant ID into a restaurant, or null if there is no such one.
  final MerchantResolver resolve;

  final void Function(MerchantBinding binding) onBound;

  /// What this device is bound to now, when it is being re-pointed rather than
  /// set up. Shown so somebody re-purposing a tablet can see what they are
  /// about to replace.
  final MerchantBinding? current;

  @override
  State<MerchantBindScreen> createState() => _MerchantBindScreenState();
}

class _MerchantBindScreenState extends State<MerchantBindScreen> {
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Resolved, and waiting for somebody to say yes. Confirming is worth the
  /// extra tap: a tablet bound to the wrong restaurant shows a menu that is
  /// nearly right, which is far more confusing than one that is obviously
  /// wrong.
  MerchantBinding? _found;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookUp(String raw) async {
    final t = widget.text;
    final code = MerchantBinding.codeFromScan(raw);
    if (code == null) {
      setState(() => _error = t.merchantIdMalformed);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final found = await widget.resolve(code);
      if (!mounted) return;
      setState(() {
        _found = found;
        _error = found == null ? t.noMerchantWithThatId : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error =
          error is StateError ? error.message : t.cannotReachRestaurant);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _JoinScanner(text: widget.text),
      ),
    );
    if (scanned == null || !mounted) return;
    _code.text = MerchantBinding.codeFromScan(scanned) ?? scanned;
    await _lookUp(scanned);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text;
    final found = _found;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: PageWidth(
          maxWidth: 460,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
            children: [
              Center(
                child: Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(found?.logo ?? Brand.logo,
                      style: const TextStyle(fontSize: 30)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                found == null ? t.whichRestaurant : t.isThisRight,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              if (found == null) ...[
                Text(t.bindBlurb,
                    textAlign: TextAlign.center, style: AppType.body),
                const SizedBox(height: 22),
                TextField(
                  controller: _code,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.go,
                  onSubmitted: _busy ? null : _lookUp,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                  decoration: appInput(hint: 'EZ-4K7Q2M'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : () => _lookUp(_code.text),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: Text(t.continueLabel),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                  label: Text(t.scanTheCode),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ] else ...[
                Text(
                  found.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  MerchantCode.display(found.code),
                  textAlign: TextAlign.center,
                  style: AppType.label,
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy ? null : () => widget.onBound(found),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: Text(t.yesThatIsUs),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _found = null;
                    _code.clear();
                  }),
                  child: Text(t.cancel),
                ),
              ],
              if (widget.current != null && found == null) ...[
                const SizedBox(height: 24),
                Text(
                  t.deviceSetUpFor(widget.current!.name),
                  textAlign: TextAlign.center,
                  style: AppType.label,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Camera, for the join code only.
///
/// Deliberately separate from the diner's table scanner: that one needs a
/// restaurant already loaded to resolve a table against, and this one runs
/// before there is one.
class _JoinScanner extends StatefulWidget {
  const _JoinScanner({required this.text});

  final AppText text;

  @override
  State<_JoinScanner> createState() => _JoinScannerState();
}

class _JoinScannerState extends State<_JoinScanner> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // Detections keep arriving for a frame or two after the screen is popped,
    // so this can fire on a dead widget.
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      if (MerchantBinding.codeFromScan(value) == null) {
        setState(() => _error = widget.text.merchantIdMalformed);
        return;
      }
      _handled = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: appTopBar(title: widget.text.scanTheCode),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          if (_error != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 40,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

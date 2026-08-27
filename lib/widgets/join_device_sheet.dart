import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/app_store.dart';
import '../data/merchant_binding.dart';
import '../models/merchant_code.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// The code an owner shows a new phone or tablet.
///
/// Setting a device up used to mean a separate build of the app per
/// restaurant. Now it means pointing a camera at this, which is the difference
/// between shipping software and handing somebody a tablet that works.
///
/// It is not a credential and the sheet says as much: binding a device only
/// decides *whose* menu and orders it will ask for. Every member of staff
/// still signs in with their own PIN or password.
Future<void> showJoinDeviceSheet(BuildContext context, AppStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _JoinDeviceSheet(store: store),
  );
}

class _JoinDeviceSheet extends StatelessWidget {
  const _JoinDeviceSheet({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final code = store.settings.code;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: sheetMaxHeight(context, fraction: 0.92)),
        child: PageWidth(
          maxWidth: 460,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.setUpADevice,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(t.setUpADeviceBlurb,
                    textAlign: TextAlign.center, style: AppType.body),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(
                    data: MerchantBinding.joinPayloadFor(code),
                    version: QrVersions.auto,
                    size: 220,
                    gapless: true,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                // The same thing in characters, because a camera is not always
                // an option: a cracked lens, a device with the camera
                // permission refused, or somebody setting a tablet up over the
                // phone from another building.
                SelectableText(
                  MerchantCode.display(code),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Courier'],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) showToast(context, t.copied);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(t.copy),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

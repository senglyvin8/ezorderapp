import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_store.dart';
import '../models/merchant_code.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// The restaurant's merchant ID, big enough to read out loud.
///
/// It appears in two places on purpose: on Settings, where an owner goes
/// looking for it, and on the Staff screen, where they need it at the exact
/// moment they are setting somebody up on a new tablet.
///
/// Monospaced and letter-spaced because this is a string that gets read down a
/// phone. The alphabet already avoids I, L, O and U (see [MerchantCode]); the
/// spacing is what stops `4K7Q2M` being heard as five characters.
class MerchantIdCard extends StatelessWidget {
  const MerchantIdCard({super.key, required this.store, this.showBlurb = true});

  final AppStore store;

  /// The line explaining what it is for. On the Staff screen, where it sits
  /// beside the thing it is for, it would only be noise.
  final bool showBlurb;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final code = store.settings.code;
    // A project that has not run 0011 yet has no code to show, and an empty
    // card that says "Merchant ID" and nothing else is worse than no card.
    if (code.trim().isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded,
                  size: 18, color: AppColors.inkFaint),
              const SizedBox(width: 8),
              Expanded(child: Text(t.merchantId, style: AppType.label)),
              IconButton(
                tooltip: t.copy,
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) showToast(context, t.copied);
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 2),
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
          if (showBlurb) ...[
            const SizedBox(height: 8),
            Text(t.merchantIdBlurb, style: AppType.body),
          ],
        ],
      ),
    );
  }
}

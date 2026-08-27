import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../data/guest_mode.dart';
import '../data/merchant_binding.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// A standing reminder that none of this is real.
///
/// A demo that looks exactly like the product is the point — and it is also
/// the hazard. Somebody who took an order in the demo and expected a kitchen
/// to hear about it has been misled by the thing that was meant to sell them.
/// So it says so, on every screen, and never gets dismissed: the way out of
/// the banner is the way out of the demo.
///
/// Only shown to a guest. A real restaurant on the same build never sees it.
class GuestBanner extends StatelessWidget {
  const GuestBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Always provided by RestaurantApp, so this is a plain read rather than a
    // nullable one — a missing provider here is a wiring mistake and should
    // fail loudly rather than quietly hiding the banner.
    if (!context.watch<GuestSession>().isGuest) return const SizedBox.shrink();

    final store = context.watch<AppStore>();
    final t = store.text;
    final leave = context.read<RebindDevice?>();

    return Material(
      color: AppColors.statusCooking,
      child: SafeArea(
        bottom: false,
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 6, leave == null ? 12 : 4, 6),
          child: Row(
            children: [
              const Icon(Icons.science_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.guestMode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (leave != null)
                TextButton(
                  onPressed: () async {
                    final confirmed = await confirmDialog(
                      context,
                      title: t.leaveGuestMode,
                      message: t.leaveGuestModeBody,
                      confirmLabel: t.leaveGuestMode,
                      cancelLabel: t.cancel,
                    );
                    if (confirmed) await leave();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(t.leaveGuestMode),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/upgrade_request.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';
import 'upgrade_sheet.dart';

/// How much of the plan is used up, as a bar rather than a number alone.
///
/// "18 of 20" is easy to skim past; a bar that is nearly full is not. A full
/// one is tappable and opens the upgrade sheet — the moment somebody looks at
/// a red meter is the moment they want to know what to do about it.
class PlanMeter extends StatelessWidget {
  const PlanMeter({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
    required this.store,
    required this.reason,
    this.card = true,
  });

  final String label;
  final int used;

  /// Null means unlimited, which draws no bar at all.
  final int? limit;
  final AppStore store;

  /// Which wall this meter is measuring, so a tap opens the right sheet.
  final UpgradeReason reason;

  /// False inside something that is already a card, like the plan panel on
  /// Manage.
  final bool card;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final unlimited = limit == null;
    final fraction = unlimited ? 0.0 : (used / limit!).clamp(0.0, 1.0);
    final full = !unlimited && used >= limit!;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.label,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              unlimited ? t.usedUnlimited(used) : t.usedOf(used, limit!),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: full ? AppColors.danger : AppColors.inkSoft,
              ),
            ),
          ],
        ),
        // No bar when there is no ceiling. An indeterminate indicator would
        // both animate forever and say the wrong thing — "unlimited" is not
        // "loading".
        if (!unlimited) ...[
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation(
                full ? AppColors.danger : AppColors.brand,
              ),
            ),
          ),
        ],
        // The way out, on its own line. Beside the usage it would have to
        // share a row with a Khmer label and a fraction, and Khmer labels are
        // longer than their English counterparts — that row overflows on a
        // phone.
        if (full) ...[
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                t.upgrade,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandDark,
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 17, color: AppColors.brandDark),
            ],
          ),
        ],
      ],
    );

    final tappable = full
        ? InkWell(
            onTap: () => showUpgradeSheet(context, reason: reason),
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: Padding(
              padding: card
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(vertical: 4),
              child: body,
            ),
          )
        : body;

    if (!card) return tappable;
    return AppCard(child: tappable);
  }
}

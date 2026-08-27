import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/upgrade_request.dart';
import '../screens/admin/pricing_screen.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// What the merchant sees after they have asked: proof it landed, when, and
/// what happens next. A request that vanishes feels exactly like being
/// ignored.
class UpgradeRequestCard extends StatelessWidget {
  const UpgradeRequestCard({
    super.key,
    required this.request,
    required this.store,
  });

  final UpgradeRequest request;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          color: tint(AppColors.statusReady),
          elevated: false,
          borderColor: AppColors.statusReady.withValues(alpha: 0.25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 19, color: AppColors.statusReady),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${planLabel(request.fromPlan, t)} → '
                      '${planLabel(request.toPlan, t)}',
                      style: AppType.cardTitle,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t.requestSentOn(_shortDate(request.createdAt)),
                      style: AppType.label,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request.contactPhone.isEmpty
                          ? t.weWillBeInTouch
                          : t.weWillCall(request.contactPhone),
                      style: AppType.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () async {
              try {
                await store.cancelUpgradeRequest();
                if (context.mounted) showToast(context, t.requestWithdrawn);
              } on StateError catch (error) {
                if (context.mounted) {
                  showToast(context, error.message, error: true);
                }
              }
            },
            child: Text(t.withdrawRequest,
                style: const TextStyle(color: AppColors.inkSoft)),
          ),
        ),
      ],
    );
  }
}


String _shortDate(DateTime when) =>
    '${when.day} ${_months[when.month - 1]} ${when.year}';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

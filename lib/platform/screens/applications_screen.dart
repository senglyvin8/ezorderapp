import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../platform_store.dart';
import '../signup_queue.dart';

/// Restaurants asking to join.
///
/// The other queue in this console is merchants who already pay you wanting
/// something. This one is people deciding whether to become merchants at all,
/// and they are the more perishable of the two: somebody who signed up on
/// Tuesday and heard nothing by Friday has found another way to take orders.
///
/// Waiting ones first, longest wait at the top, because the database orders it
/// that way and the oldest is the one costing you something.
class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlatformStore>();
    final all = store.applications;
    final open = store.openApplications;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: 'Sign-up requests',
        subtitle:
            open.isEmpty ? 'Nobody is waiting' : '${open.length} waiting on you',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: store.loading ? null : store.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: all.isEmpty
          ? const EmptyState(
              icon: Icons.storefront_rounded,
              title: 'No requests',
              message: 'When a restaurant asks to join, it lands here.',
            )
          : RefreshIndicator(
              onRefresh: store.load,
              child: PageWidth(
                maxWidth: 900,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    for (final application in all) ...[
                      _ApplicationCard(application: application),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _ApplicationCard extends StatefulWidget {
  const _ApplicationCard({required this.application});
  final SignUpApplication application;

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  bool _busy = false;

  Future<void> _approve(PlatformStore store) async {
    final a = widget.application;
    final confirmed = await confirmDialog(
      context,
      title: 'Approve ${a.restaurantName}?',
      message: 'This creates the restaurant at ${a.slug}, makes '
          '${a.email} its owner, and gives it five tables. The web address '
          'goes into their printed QR codes and cannot be changed afterwards.',
      confirmLabel: 'Approve',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await store.approveApplication(a);
      if (mounted) showToast(context, '${a.restaurantName} is open');
    } on StateError catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(PlatformStore store) async {
    final reason = await _askReason();
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await store.rejectApplication(widget.application, reason);
      if (mounted) showToast(context, 'Turned down');
    } on StateError catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The reason is not optional, because the applicant reads it. "No" with
  /// nothing after it is the least useful answer there is, and they can apply
  /// again — better that they know what to change.
  Future<String?> _askReason() async {
    final controller = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Turn this down',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'They will see this when they sign in, and they can apply '
                'again.',
                style: AppType.body,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                maxLength: 200,
                decoration: appInput(
                  hint: 'We could not find this restaurant.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.inkSoft)),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: AppColors.danger,
              ),
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Turn down'),
            ),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    return sent == true ? reason : null;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<PlatformStore>();
    final a = widget.application;
    final open = a.status.isOpen;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.restaurantName, style: AppType.cardTitle),
                    const SizedBox(height: 3),
                    Text(
                      a.ownerName.isEmpty
                          ? a.email
                          : '${a.ownerName}  ·  ${a.email}',
                      style: AppType.label,
                    ),
                  ],
                ),
              ),
              _StatusChip(status: a.status),
            ],
          ),
          const SizedBox(height: 12),
          // The one thing that cannot be changed after approval, so it is the
          // one thing shown in full rather than summarised.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded,
                    size: 16, color: AppColors.inkFaint),
                const SizedBox(width: 7),
                Expanded(
                  child: Text('/order/${a.slug}/table/01',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            open
                ? 'Asked ${_ago(a.waited)} ago'
                : 'Answered ${DateFormat('d MMM').format(a.reviewedAt ?? a.askedAt)}',
            style: AppType.label,
          ),
          if (!open && a.note.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('“${a.note}”',
                style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.inkSoft)),
          ],
          if (open) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _reject(store),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size(0, 46),
                    ),
                    child: const Text('Turn down'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _approve(store),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    child: Text(_busy ? 'Working…' : 'Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _ago(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d';
    if (d.inHours >= 1) return '${d.inHours}h';
    return '${d.inMinutes}m';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final colour = switch (status) {
      ApplicationStatus.pending => AppColors.statusCooking,
      ApplicationStatus.approved => AppColors.statusReady,
      ApplicationStatus.rejected => AppColors.inkFaint,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint(colour),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colour,
        ),
      ),
    );
  }
}

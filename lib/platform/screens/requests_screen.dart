import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/upgrade_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../platform_store.dart';
import '../upgrade_queue.dart';
import 'merchant_sheet.dart';

/// The upgrade queue.
///
/// Every other screen in the console is you looking at merchants. This one is
/// merchants waiting on you, which is why it is the only screen with a badge:
/// a merchant who asked for a bigger plan on Tuesday and heard nothing by
/// Friday has already decided what kind of service this is.
///
/// Ordered by how long somebody has been waiting rather than by what they
/// would pay. The most valuable request in the list is not the one worth the
/// most money; it is the one that has been sitting there longest.
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlatformStore>();
    final requests = store.requests;
    final open = store.openRequests;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: 'Upgrade requests',
        subtitle: open.isEmpty
            ? 'Nobody is waiting'
            : '${open.length} waiting on you',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: store.loading ? null : store.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: requests.isEmpty
          ? const EmptyState(
              icon: Icons.mark_email_read_rounded,
              title: 'No requests',
              message: 'When a merchant asks for a bigger plan it lands here.',
            )
          : RefreshIndicator(
              onRefresh: store.load,
              child: PageWidth(
                maxWidth: 900,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    for (final request in requests) ...[
                      _RequestCard(request: request, store: store),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.store});

  final UpgradeTicket request;
  final PlatformStore store;

  Future<void> _act(
    BuildContext context,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      if (context.mounted) showToast(context, done);
    } on StateError catch (error) {
      if (context.mounted) showToast(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final open = request.isOpen;
    final merchant = store.merchants
        .where((m) => m.id == request.restaurantId)
        .firstOrNull;

    return AppCard(
      borderColor: open ? AppColors.brand : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(request.logo,
                    style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.merchant, style: AppType.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      '${request.slug}  ·  ${_waited(request)}',
                      style: AppType.label,
                    ),
                  ],
                ),
              ),
              _StatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.fromPlan.label} → ${request.toPlan.label}',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                // A downgrade is a request worth reading rather than granting
                // on autopilot, so the sign is never hidden.
                '${request.monthlyDelta >= 0 ? '+' : '−'}'
                '${money.format(request.monthlyDelta.abs())} / mo',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: request.monthlyDelta >= 0
                      ? AppColors.statusReady
                      : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Reason(reason: request.reason),
          if (request.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tint(AppColors.note),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                request.note,
                style: const TextStyle(fontSize: 14.5, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (request.phone.trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _call(context, request.phone),
                  icon: const Icon(Icons.call_rounded, size: 17),
                  label: Text(request.phone),
                ),
              if (merchant != null)
                OutlinedButton.icon(
                  onPressed: () => showMerchantSheet(context, merchant),
                  icon: const Icon(Icons.storefront_rounded, size: 17),
                  label: const Text('Open merchant'),
                ),
              if (open) ...[
                // The one-tap answer: put them on the plan they asked for. The
                // request closes itself when the plan changes, so there is no
                // second step to forget.
                FilledButton.icon(
                  onPressed: merchant == null
                      ? null
                      : () => _act(
                            context,
                            () => store.setPlan(merchant, request.toPlan),
                            '${request.merchant} is on '
                            '${request.toPlan.label}',
                          ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('Move to ${request.toPlan.label}'),
                ),
                if (request.status == UpgradeStatus.pending)
                  TextButton(
                    onPressed: () => _act(
                      context,
                      () => store.resolveRequest(
                          request, UpgradeStatus.contacted),
                      'Marked as contacted',
                    ),
                    child: const Text('Mark contacted'),
                  ),
                TextButton(
                  onPressed: () => _act(
                    context,
                    () =>
                        store.resolveRequest(request, UpgradeStatus.declined),
                    'Request closed',
                  ),
                  child: const Text('Close',
                      style: TextStyle(color: AppColors.inkSoft)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _waited(UpgradeTicket request) {
    final asked = DateFormat('d MMM').format(request.createdAt);
    if (!request.isOpen) return 'asked $asked';
    final days = DateTime.now().difference(request.createdAt).inDays;
    return switch (days) {
      0 => 'asked today',
      1 => 'waiting since yesterday',
      _ => 'waiting $days days',
    };
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      showToast(context, 'No dialler on this device — $phone', error: true);
    }
  }
}

/// Why they asked. A merchant blocked at a cap right now is a different
/// conversation from one who was reading the pricing screen.
class _Reason extends StatelessWidget {
  const _Reason({required this.reason});

  final UpgradeReason reason;

  @override
  Widget build(BuildContext context) {
    final (label, icon, blocked) = switch (reason) {
      UpgradeReason.staffCap => ('Blocked adding staff', Icons.person_off_rounded, true),
      UpgradeReason.tableCap => ('Blocked adding a table', Icons.table_bar_rounded, true),
      UpgradeReason.manual => ('Asked from the pricing screen', Icons.list_alt_rounded, false),
    };
    final color = blocked ? AppColors.danger : AppColors.inkSoft;
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final UpgradeStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      UpgradeStatus.pending => ('New', AppColors.statusNew),
      UpgradeStatus.contacted => ('Contacted', AppColors.statusCooking),
      UpgradeStatus.done => ('Done', AppColors.statusReady),
      UpgradeStatus.declined => ('Closed', AppColors.statusCompleted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tint(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

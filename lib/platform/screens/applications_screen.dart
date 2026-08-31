import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../platform_store.dart';
import '../signup_queue.dart';

/// Restaurants asking to join.
///
/// Split by what you still have to do about them. Waiting is a job; approved
/// and turned down are a record, and mixing the three means the job is
/// something you have to find rather than something you are shown.
///
/// The other queue in this console is merchants who already pay you wanting
/// something. This one is people deciding whether to become merchants at all,
/// and they are the more perishable of the two: somebody who signed up on
/// Tuesday and heard nothing by Friday has found another way to take orders.
class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlatformStore>();
    final all = store.applications;

    List<SignUpApplication> of(ApplicationStatus s) =>
        all.where((a) => a.status == s).toList();

    final waiting = of(ApplicationStatus.pending);
    final approved = of(ApplicationStatus.approved);
    final refused = of(ApplicationStatus.rejected);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: appTopBar(
          title: 'Sign-up requests',
          subtitle: waiting.isEmpty
              ? 'Nobody is waiting'
              : '${waiting.length} waiting on you',
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: store.loading ? null : store.load,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 6),
          ],
          bottom: TabBar(
            labelColor: AppColors.brand,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.brand,
            tabs: [
              // The count is on the one that is a job. The other two are
              // history, and numbering history invites reading it.
              Tab(text: 'Waiting (${waiting.length})'),
              const Tab(text: 'Approved'),
              const Tab(text: 'Turned down'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _List(
              applications: waiting,
              empty: 'Nothing waiting',
              emptyBody: 'When a restaurant asks to join, it lands here.',
              onRefresh: store.load,
            ),
            _List(
              applications: approved,
              empty: 'None yet',
              emptyBody: 'Restaurants you have let in appear here.',
              onRefresh: store.load,
            ),
            _List(
              applications: refused,
              empty: 'None yet',
              emptyBody: 'Requests you have turned down appear here, with the '
                  'reason you gave.',
              onRefresh: store.load,
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.applications,
    required this.empty,
    required this.emptyBody,
    required this.onRefresh,
  });

  final List<SignUpApplication> applications;
  final String empty;
  final String emptyBody;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_rounded,
        title: empty,
        message: emptyBody,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: PageWidth(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            for (final application in applications) ...[
              _ApplicationCard(application: application),
              const SizedBox(height: 12),
            ],
          ],
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
      message: 'This creates the restaurant at ${a.slug}, makes ${a.email} its '
          'owner, and gives it five tables. The web address goes into their '
          'printed QR codes and cannot be changed afterwards.',
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
                decoration:
                    appInput(hint: 'We could not find this restaurant.'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.inkSoft)),
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
    final stamp = DateFormat('d MMM yyyy, HH:mm');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(a.restaurantName, style: AppType.cardTitle),
              ),
              _StatusChip(status: a.status),
            ],
          ),
          const SizedBox(height: 14),

          // Everything they typed, laid out rather than summarised. This is
          // the whole basis for the decision — there is nowhere else to look
          // and no way to ask them a question.
          _Field(label: 'Owner', value: a.ownerName.isEmpty ? '—' : a.ownerName),
          _Field(label: 'Email', value: a.email, selectable: true),
          _Field(
            label: 'Web address',
            value: '/order/${a.slug}/table/01',
            // The one thing approval makes permanent: it goes into their
            // printed QR codes.
            note: 'Permanent once approved',
            selectable: true,
          ),
          _Field(
            label: 'Asked',
            value: '${stamp.format(a.askedAt.toLocal())}'
                '${open ? '  ·  ${_ago(a.waited)} ago' : ''}',
          ),
          if (a.reviewedAt != null)
            _Field(
                label: 'Answered',
                value: stamp.format(a.reviewedAt!.toLocal())),
          if (!open && a.note.trim().isNotEmpty)
            _Field(label: 'Reason given', value: a.note),

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
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 46)),
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

/// One labelled line of what somebody typed.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.note,
    this.selectable = false,
  });

  final String label;
  final String value;

  /// A word about what this field means, where the value alone would not say.
  final String? note;

  /// True for the things an operator copies out — an address to write to, an
  /// address to check.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: AppType.label),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                selectable
                    ? SelectableText(value,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w500))
                    : Text(value,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w500)),
                if (note != null)
                  Text(note!,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.inkFaint)),
              ],
            ),
          ),
        ],
      ),
    );
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
            fontSize: 12, fontWeight: FontWeight.w700, color: colour),
      ),
    );
  }
}

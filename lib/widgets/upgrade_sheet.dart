import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_store.dart';
import '../models/plan.dart';
import '../models/upgrade_request.dart';
import '../screens/admin/pricing_screen.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';
import 'upgrade_request_card.dart';

/// What to do when a merchant runs out of plan.
///
/// The old behaviour was a red toast: "The Basic plan allows 5 staff accounts.
/// Upgrade to add more." That is a merchant standing at the counter with money
/// in their hand and nobody behind the till — told no, at the exact moment
/// they were trying to spend.
///
/// This is the till. It says what is blocked, what fixes it, and then gives
/// three ways to act: send a request, message, or call. The request is the
/// primary one because it is the only one that costs nothing to press — it
/// already knows who they are.
Future<void> showUpgradeSheet(
  BuildContext context, {
  required UpgradeReason reason,
  Plan? toPlan,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => UpgradeSheet(reason: reason, toPlan: toPlan),
  );
}

class UpgradeSheet extends StatefulWidget {
  const UpgradeSheet({super.key, required this.reason, this.toPlan});

  final UpgradeReason reason;

  /// Which plan to ask for. Defaults to the next one up, which is what a
  /// merchant who has just hit a wall wants.
  final Plan? toPlan;

  @override
  State<UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends State<UpgradeSheet> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _busy = false;
  bool _seeded = false;

  @override
  void dispose() {
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final current = store.settings.plan;
    final target = widget.toPlan ?? current.next;
    final request = store.upgradeRequest;

    // Seeded once, from the request if there is one and the restaurant's own
    // number otherwise. Nobody should have to type a number the app already
    // knows, and re-seeding on every rebuild would fight the owner's typing.
    if (!_seeded) {
      _seeded = true;
      _phone.text = (request?.contactPhone.isNotEmpty ?? false)
          ? request!.contactPhone
          : store.settings.phone;
      _note.text = request?.note ?? '';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: sheetMaxHeight(context, fraction: 0.9)),
          child: PageWidth(
            maxWidth: 560,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Grip(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.brandTint,
                          borderRadius:
                              BorderRadius.circular(AppRadius.small),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded,
                            size: 21, color: AppColors.brandDark),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          request != null && request.isOpen
                              ? t.upgradeRequestPending
                              : t.upgradeNeeded,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (request != null && request.isOpen)
                    UpgradeRequestCard(request: request, store: store)
                  else ...[
                    Text(_blocked(store), style: AppType.body),
                    const SizedBox(height: 14),
                    if (target == null)
                      Text(t.alreadyOnTopPlan, style: AppType.body)
                    else
                      _Offer(plan: target, store: store),
                    const SizedBox(height: 18),
                    Text(t.contactPhoneLabel, style: AppType.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: appInput(hint: store.settings.phone),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _note,
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      decoration: appInput(hint: t.upgradeNoteHint),
                    ),
                    const SizedBox(height: 16),
                    if (target != null)
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _send(store, target),
                        icon: const Icon(Icons.send_rounded, size: 19),
                        label: Text(t.sendRequest),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  _Channels(store: store, target: target),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The sentence that names the wall they hit. Written from what the plan
  /// actually allows rather than a generic "limit reached", because a merchant
  /// who cannot see the number cannot tell how much bigger they need to go.
  String _blocked(AppStore store) {
    final t = store.text;
    final plan = store.settings.plan;
    final label = planLabel(plan, t);
    return switch (widget.reason) {
      UpgradeReason.staffCap => t.staffCapHit(label, plan.maxStaff ?? 0),
      UpgradeReason.tableCap => t.tableCapHit(label, plan.maxTables ?? 0),
      UpgradeReason.manual => t.howToUpgrade,
    };
  }

  Future<void> _send(AppStore store, Plan target) async {
    setState(() => _busy = true);
    try {
      await store.requestUpgrade(
        toPlan: target,
        reason: widget.reason,
        contactName: store.currentUser?.name ?? '',
        contactPhone: _phone.text,
        note: _note.text,
      );
      if (mounted) showToast(context, store.text.requestSent);
    } on StateError catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// What the plan they are being offered actually buys, in the same words the
/// pricing screen uses.
class _Offer extends StatelessWidget {
  const _Offer({required this.plan, required this.store});

  final Plan plan;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    return AppCard(
      color: AppColors.surface,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.upgradeGives(planLabel(plan, t)),
                    style: AppType.cardTitle),
              ),
              Text(
                plan.monthlyPrice == 0
                    ? t.freeForever
                    : t.perMonth('\$${plan.monthlyPrice.toStringAsFixed(2)}'),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Perk(
            text: plan.hasUnlimitedTables
                ? t.tablesUnlimited
                : t.tablesLimit(plan.maxTables!),
          ),
          _Perk(text: t.staffLimit(plan.maxStaff!)),
          _Perk(text: t.ordersUnlimited),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded,
              size: 16, color: AppColors.statusReady),
          const SizedBox(width: 7),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Telegram and the phone. Both carry the restaurant's name and the plan they
/// are after, so you never have to open with "who is this?".
class _Channels extends StatelessWidget {
  const _Channels({required this.store, required this.target});

  final AppStore store;
  final Plan? target;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final support = store.support;
    if (!support.hasPhone && !support.hasTelegram) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            if (support.hasTelegram)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open(context, _telegramLink(support.telegram)),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(t.messageTelegram),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            if (support.hasTelegram && support.hasPhone)
              const SizedBox(width: 10),
            if (support.hasPhone)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open(
                      context, Uri.parse('tel:${_dialable(support.phone)}')),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text(t.callUs),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
          ],
        ),
        if (support.hours.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(support.hours, style: AppType.label),
        ],
      ],
    );
  }

  /// Telegram takes the opening message in the link, so the conversation
  /// starts with the restaurant's name and what they want rather than with you
  /// asking who is writing.
  Uri _telegramLink(String base) {
    final t = store.text;
    final plan = target == null ? '' : ' → ${planLabel(target!, t)}';
    final message = '${store.settings.name}$plan';
    final uri = Uri.parse(base);
    return uri.replace(queryParameters: {...uri.queryParameters, 'text': message});
  }

  /// A dialler wants digits and a leading +, not the spaces a human reads by.
  static String _dialable(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _open(BuildContext context, Uri uri) async {
    final t = store.text;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    // A phone with no dialler, or a desktop browser with no Telegram: say so
    // rather than letting the button do nothing at all.
    if (!opened && context.mounted) {
      showToast(context, t.couldNotOpenLink, error: true);
    }
  }
}

class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.borderStrong,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../merchant.dart';
import '../platform_store.dart';
import 'merchant_sheet.dart';
import 'new_merchant_sheet.dart';

/// Every restaurant on the platform.
///
/// Ordered and filtered around one question — which of these needs something
/// from me today — rather than around who is biggest. A list of forty healthy
/// restaurants is not worth reading; the three that cannot take an order are.
class MerchantsScreen extends StatefulWidget {
  const MerchantsScreen({super.key});

  @override
  State<MerchantsScreen> createState() => _MerchantsScreenState();
}

class _MerchantsScreenState extends State<MerchantsScreen> {
  final _search = TextEditingController();
  MerchantHealth? _health;
  bool _onlyAttention = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlatformStore>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlatformStore>();
    final money = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final list = store.visible(
      health: _health,
      onlyNeedingAttention: _onlyAttention,
      query: _search.text,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        automaticallyImplyLeading: false,
        title: 'Merchants',
        subtitle: store.signedInAs,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: store.loading ? null : store.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: store.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-merchant',
        onPressed: () => showNewMerchantSheet(context),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('New merchant'),
      ),
      body: store.error != null
          ? EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load merchants',
              message: store.error!,
              action: FilledButton(
                onPressed: store.load,
                child: const Text('Try again'),
              ),
            )
          : store.loading && store.merchants.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: store.load,
                  child: PageWidth(
                    maxWidth: 1000,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [
                        _Headline(store: store, money: money),
                        const SizedBox(height: 18),
                        _Filters(
                          store: store,
                          search: _search,
                          health: _health,
                          onlyAttention: _onlyAttention,
                          onHealth: (h) => setState(() {
                            _health = h;
                            _onlyAttention = false;
                          }),
                          onAttention: (v) => setState(() {
                            _onlyAttention = v;
                            _health = null;
                          }),
                          onSearch: () => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        if (list.isEmpty)
                          EmptyState(
                            icon: store.merchants.isEmpty
                                ? Icons.storefront_rounded
                                : Icons.search_off_rounded,
                            title: store.merchants.isEmpty
                                ? 'No merchants yet'
                                : 'Nothing matches',
                            message: store.merchants.isEmpty
                                ? 'Add the first one with the button below.'
                                : 'Try a different filter or search.',
                          )
                        else
                          for (final m in list) ...[
                            _MerchantCard(
                              merchant: m,
                              money: money,
                              onOpen: () => showMerchantSheet(context, m),
                            ),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
                ),
    );
  }
}

/// What to do today, then how the business is doing. In that order — the first
/// is actionable and the second is just interesting.
class _Headline extends StatelessWidget {
  const _Headline({required this.store, required this.money});

  final PlatformStore store;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final needs = store.needsAttentionCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          color: needs == 0 ? AppColors.card : tint(AppColors.statusCooking),
          borderColor:
              needs == 0 ? AppColors.border : AppColors.statusCooking,
          child: Row(
            children: [
              Icon(
                needs == 0
                    ? Icons.check_circle_rounded
                    : Icons.flag_rounded,
                size: 22,
                color: needs == 0
                    ? AppColors.statusReady
                    : AppColors.statusCooking,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needs == 0
                          ? 'Everything looks healthy'
                          : '$needs ${needs == 1 ? "merchant needs" : "merchants need"} attention',
                      style: const TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      needs == 0
                          ? 'Every merchant is set up and taking orders.'
                          : _summarise(store),
                      style: AppType.label,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 620 ? 4 : 2;
            final scale = MediaQuery.textScalerOf(context)
                .scale(1.0)
                .clamp(1.0, 1.3)
                .toDouble();
            final tiles = <(String, String, IconData, Color)>[
              ('Monthly recurring', money.format(store.monthlyRecurring),
                  Icons.trending_up_rounded, AppColors.statusReady),
              ('Merchants', '${store.merchantCount}',
                  Icons.storefront_rounded, AppColors.statusNew),
              ('Orders today', '${store.ordersToday}',
                  Icons.receipt_long_rounded, AppColors.statusPaid),
              ('Taken today', money.format(store.revenueToday),
                  Icons.payments_rounded, AppColors.brand),
            ];
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: (columns == 4 ? 1.5 : 1.7) / scale,
              children: [
                for (final tile in tiles)
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(tile.$3, size: 17, color: tile.$4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                tile.$2,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                            Text(tile.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.label),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _summarise(PlatformStore store) {
    final parts = <String>[
      if (store.countOf(MerchantHealth.notSetUp) > 0)
        '${store.countOf(MerchantHealth.notSetUp)} cannot take orders yet',
      if (store.countOf(MerchantHealth.neverOrdered) > 0)
        '${store.countOf(MerchantHealth.neverOrdered)} never started',
      if (store.quietCount > 0) '${store.quietCount} gone quiet',
      if (store.atLimitCount > 0) '${store.atLimitCount} at a plan limit',
      if (store.suspendedCount > 0) '${store.suspendedCount} suspended',
    ];
    return parts.join('  ·  ');
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.store,
    required this.search,
    required this.health,
    required this.onlyAttention,
    required this.onHealth,
    required this.onAttention,
    required this.onSearch,
  });

  final PlatformStore store;
  final TextEditingController search;
  final MerchantHealth? health;
  final bool onlyAttention;
  final ValueChanged<MerchantHealth?> onHealth;
  final ValueChanged<bool> onAttention;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: search,
          onChanged: (_) => onSearch(),
          decoration: appInput(hint: 'Search by name, slug or phone').copyWith(
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      search.clear();
                      onSearch();
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              label: 'All (${store.merchantCount})',
              selected: health == null && !onlyAttention,
              onTap: () => onHealth(null),
            ),
            _Chip(
              label: 'Needs attention (${store.needsAttentionCount})',
              selected: onlyAttention,
              color: AppColors.statusCooking,
              onTap: () => onAttention(true),
            ),
            for (final h in MerchantHealth.values)
              if (store.countOf(h) > 0)
                _Chip(
                  label: '${healthLabel(h)} (${store.countOf(h)})',
                  selected: health == h,
                  color: healthColor(h),
                  onTap: () => onHealth(h),
                ),
          ],
        ),
      ],
    );
  }
}

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({
    required this.merchant,
    required this.money,
    required this.onOpen,
  });

  final Merchant merchant;
  final NumberFormat money;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final m = merchant;
    final colour = healthColor(m.health);

    return AppCard(
      onTap: onOpen,
      borderColor: m.needsAttention ? colour : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint(colour),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(m.logo, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Badge(label: healthLabel(m.health), color: colour),
                        _Badge(
                            label: m.plan.label, color: AppColors.brandDark),
                        if (m.atAnyLimit)
                          const _Badge(
                              label: 'At limit',
                              color: AppColors.statusCooking),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money.format(m.revenueTotal),
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w800),
                  ),
                  const Text('all time', style: AppType.label),
                ],
              ),
            ],
          ),
          // A merchant who cannot trade gets the reason on the card, not
          // buried a tap away — this is the whole point of the list.
          if (m.setupGaps.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tint(AppColors.statusCooking),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Cannot take orders — ${m.setupGaps.join(', ')}. '
                'Signed up ${m.daysSinceSignUp} days ago.',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.statusCooking,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '/${m.slug}   ·   ${m.tablesUsed} tables   ·   '
                  '${m.menuItems} dishes   ·   ${m.ordersTotal} orders',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label,
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.inkFaint),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.brand,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? color : AppColors.inkSoft;
    return Material(
      color: selected ? tint(color) : AppColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 64,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: ink),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- health words

String healthLabel(MerchantHealth health) => switch (health) {
      MerchantHealth.suspended => 'Suspended',
      MerchantHealth.notSetUp => 'Not set up',
      MerchantHealth.neverOrdered => 'Never ordered',
      MerchantHealth.quiet => 'Gone quiet',
      MerchantHealth.active => 'Active',
    };

Color healthColor(MerchantHealth health) => switch (health) {
      MerchantHealth.suspended => AppColors.danger,
      MerchantHealth.notSetUp => AppColors.statusCooking,
      MerchantHealth.neverOrdered => AppColors.statusCooking,
      MerchantHealth.quiet => AppColors.statusPaid,
      MerchantHealth.active => AppColors.statusReady,
    };

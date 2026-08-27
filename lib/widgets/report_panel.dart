import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../data/file_delivery.dart';
import '../data/order_export.dart';
import '../l10n/app_text.dart';
import '../models/date_range.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';
import 'card_grid.dart';
import 'order_ticket.dart';

/// Takings and orders over a chosen window, with a spreadsheet on the way out.
///
/// Shared by the owner's dashboard and the till rather than written twice: a
/// cashier closing up asks exactly the same question an owner does, and two
/// copies of a figure are two chances for them to disagree.
class ReportPanel extends StatefulWidget {
  const ReportPanel({super.key, this.header});

  /// Rendered above the range picker — the dashboard puts today's headline
  /// there, the till puts nothing.
  final Widget? header;

  @override
  State<ReportPanel> createState() => _ReportPanelState();
}

class _ReportPanelState extends State<ReportPanel> {
  ReportRange _range = const ReportRange.today();
  bool _exporting = false;

  Future<void> _pickDates(AppStore store) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      currentDate: now,
      initialDateRange: _range.from != null && _range.to != null
          ? DateTimeRange(start: _range.from!, end: _range.to!)
          : null,
      helpText: store.text.pickDates,
    );
    if (picked == null) return;
    setState(() => _range = ReportRange(
          ReportPreset.custom,
          from: picked.start,
          to: picked.end,
        ));
  }

  Future<void> _export(AppStore store) async {
    final t = store.text;
    final orders = store.ordersIn(_range);
    if (orders.isEmpty) {
      showToast(context, t.nothingToExport, error: true);
      return;
    }

    setState(() => _exporting = true);
    final name = OrderExport.filename(store.settings.name, DateTime.now());
    try {
      final sent = await FileDelivery.send(
        bytes: OrderExport.bytes(orders, t),
        filename: name,
        mimeType: 'text/csv',
        subject: '${store.settings.name} — ${_rangeLabel(t)}',
        origin: FileDelivery.originOf(context),
      );
      if (!mounted) return;
      // Dismissing the share sheet is not a failure; saying "Saved" then would
      // be a lie.
      if (sent) showToast(context, t.exported(name));
    } catch (_) {
      if (mounted) showToast(context, t.exportFailed, error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _rangeLabel(AppText t) => switch (_range.preset) {
        ReportPreset.today => t.rangeToday,
        ReportPreset.week => t.rangeWeek,
        ReportPreset.month => t.rangeMonth,
        ReportPreset.all => t.rangeAll,
        ReportPreset.custom => _customLabel(t),
      };

  String _customLabel(AppText t) {
    if (_range.from == null || _range.to == null) {
      return t.rangeCustom;
    }
    final f = DateFormat('d MMM');
    return '${f.format(_range.from!)} – ${f.format(_range.to!)}';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final summary = store.summaryFor(_range);
    final orders = store.ordersIn(_range);
    final best = store.topDishes(_range, limit: 5);

    return PageWidth(
      maxWidth: 900,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          if (widget.header != null) widget.header!,
          SectionLabel(t.report),
          _RangeBar(
            range: _range,
            label: _customLabel(t),
            onPreset: (preset) => setState(
                () => _range = ReportRange(preset)),
            onCustom: () => _pickDates(store),
          ),
          const SizedBox(height: 14),
          _Figures(store: store, summary: summary),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _exporting ? null : () => _export(store),
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.table_view_rounded, size: 19),
            // Khmer at 1.3x is wider than the button; let the label ellipsise
            // rather than push the row past the edge of the screen.
            label: Text(
              '${t.exportCsv}  ·  ${t.itemsCount(orders.length)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          if (best.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionLabel(t.topDishes),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < best.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _DishRow(
                      rank: i + 1,
                      name: best[i].name,
                      detail: t.soldCount(best[i].quantity),
                      amount: store.money(best[i].revenue),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SectionLabel('${t.orders}  ·  ${_rangeLabel(t)}'),
          if (orders.isEmpty)
            EmptyState(
              icon: Icons.receipt_long_rounded,
              title: t.noOrdersHere,
              message: t.noOrdersHereBody,
            )
          else ...[
            // Say when the list is cut short. A silent truncation reads as
            // "that is all of them", and the export is the way to get the
            // rest.
            if (orders.length > _listLimit)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 4),
                child: Text(
                  t.showingFirst(_listLimit, orders.length),
                  style: AppType.label,
                ),
              ),
            CardGrid(
              minTileWidth: 380,
              padding: EdgeInsets.zero,
              children: [
                for (final order in orders.take(_listLimit))
                  OrderTicket(
                    order: order,
                    store: store,
                    trailingInfo:
                        DateFormat('d MMM, h:mm a').format(order.createdAt),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Enough to scan; the export carries everything. Rendering a year of
  /// tickets as cards would be a scroll nobody finishes.
  static const int _listLimit = 30;
}

/// Today / week / month / all, plus a date picker for anything else.
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.range,
    required this.label,
    required this.onPreset,
    required this.onCustom,
  });

  final ReportRange range;
  final String label;
  final ValueChanged<ReportPreset> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppStore>().text;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in <(ReportPreset, String)>[
          (ReportPreset.today, t.rangeToday),
          (ReportPreset.week, t.rangeWeek),
          (ReportPreset.month, t.rangeMonth),
          (ReportPreset.all, t.rangeAll),
        ])
          _Chip(
            label: entry.$2,
            selected: range.preset == entry.$1,
            onTap: () => onPreset(entry.$1),
          ),
        _Chip(
          label: label,
          icon: Icons.date_range_rounded,
          selected: range.preset == ReportPreset.custom,
          onTap: onCustom,
        ),
      ],
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.store, required this.summary});

  final AppStore store;
  final ({
    int orders,
    double revenue,
    int pending,
    int completed,
    int cancelled,
    int dishes,
    double average,
  }) summary;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final tiles = <(String, String, IconData, Color)>[
      (t.revenue, store.money(summary.revenue), Icons.payments_rounded,
          AppColors.statusReady),
      (t.orders, '${summary.orders}', Icons.receipt_long_rounded,
          AppColors.statusNew),
      (t.averageOrder, store.money(summary.average),
          Icons.trending_up_rounded, AppColors.statusPaid),
      (t.dishesSold, '${summary.dishes}', Icons.restaurant_rounded,
          AppColors.statusCooking),
      (t.pending, '${summary.pending}', Icons.hourglass_bottom_rounded,
          AppColors.statusCooking),
      (t.cancelledCount, '${summary.cancelled}', Icons.cancel_rounded,
          AppColors.danger),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 620 ? 3 : 2;
        // A fixed height rather than a ratio: these hold a label and a number
        // at any text size, and a ratio clips the number when text is turned
        // up.
        final scale = MediaQuery.textScalerOf(context)
            .scale(1.0)
            .clamp(1.0, 1.3)
            .toDouble();
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: (columns == 3 ? 1.55 : 1.7) / scale,
          children: [
            for (final tile in tiles)
              _Tile(
                label: tile.$1,
                value: tile.$2,
                icon: tile.$3,
                color: tile.$4,
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 19, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.label,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.rank,
    required this.name,
    required this.detail,
    required this.amount,
  });

  final int rank;
  final String name;
  final String detail;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.brandDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.cardTitle),
                Text(detail, style: AppType.label),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandDark : AppColors.inkSoft;
    return Material(
      color: selected ? AppColors.brandTint : AppColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          // A Wrap hands its children unbounded width, so a long label — a
          // Khmer date range at 1.3x text, say — would run off the screen
          // rather than wrapping to the next line.
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 64,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

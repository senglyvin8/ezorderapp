import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import '../../data/app_store.dart';
import '../../models/restaurant_table.dart';
import '../../models/upgrade_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/upgrade_sheet.dart';
import 'qr_screen.dart';

/// Tables and their QR codes. Rule 2 — each table gets its own identifier.
class AdminTablesScreen extends StatelessWidget {
  const AdminTablesScreen({super.key});

  Future<void> _rename(
    BuildContext context,
    AppStore store,
    RestaurantTable table,
  ) async {
    final t = store.text;
    final controller = TextEditingController(text: table.name);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text(t.renameTable,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: appInput(hint: t.tableNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel,
                style: const TextStyle(color: AppColors.inkSoft)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.save),
          ),
        ],
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (saved == true && name.isNotEmpty) {
      store.renameTable(table.id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final tables = store.tables;
    final occupied = tables.where((t) => store.isTableOccupied(t.id)).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: t.tablesAndQr,
        subtitle: t.tablesSummary(tables.length, occupied),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-tables-fab',
        onPressed: () async {
          // The button stays live at the cap and opens the upgrade sheet
          // instead of the failure. A greyed-out button with no explanation
          // is the worst of the options: it says no and nothing else.
          if (store.atTableLimit) {
            await showUpgradeSheet(context, reason: UpgradeReason.tableCap);
            return;
          }
          try {
            final table = await store.addTable();
            if (context.mounted) showToast(context, t.tableAdded(table.name));
          } on StateError catch (error) {
            // The database has the last word on the cap, so a client that
            // raced past the check above still lands on the sheet rather than
            // on a raw Postgres sentence.
            if (!context.mounted) return;
            if (store.atTableLimit) {
              await showUpgradeSheet(context, reason: UpgradeReason.tableCap);
            } else {
              showToast(context, error.message, error: true);
            }
          }
        },
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(t.addTable),
      ),
      body: tables.isEmpty
          ? EmptyState(
              icon: Icons.table_bar_rounded,
              title: t.noTables,
              message: t.noTablesBody,
            )
          : PageWidth(
              maxWidth: 820,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < tables.length; i++) ...[
                          if (i > 0) const Divider(),
                          _TableRow(
                            table: tables[i],
                            occupied: store.isTableOccupied(tables[i].id),
                            onRename: () => _rename(context, store, tables[i]),
                            onDelete: () async {
                              final confirmed = await confirmDialog(
                                context,
                                title: t.deleteTableTitle(tables[i].name),
                                message: t.deleteTableBody,
                                confirmLabel: t.delete,
                                cancelLabel: t.cancel,
                                destructive: true,
                              );
                              if (!context.mounted || !confirmed) return;
                              try {
                                store.deleteTable(tables[i].id);
                              } on StateError catch (_) {
                                if (context.mounted) {
                                  showToast(context, t.tableBusy, error: true);
                                }
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.table,
    required this.occupied,
    required this.onRename,
    required this.onDelete,
  });

  final RestaurantTable table;
  final bool occupied;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppStore>().text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.qr_code_2_rounded,
                size: 22, color: AppColors.brandDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  table.name,
                  style: const TextStyle(
                      fontSize: 16.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  table.qrId,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkFaint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InfoChip(
            occupied ? t.occupied : t.available,
            color: occupied ? AppColors.statusCooking : AppColors.statusReady,
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => QrScreen(tableId: table.id),
              ),
            ),
            child: Text(t.viewQr),
          ),
          PopupMenuButton<String>(
            tooltip: t.edit,
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkSoft),
            onSelected: (value) {
              if (value == 'rename') onRename();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'rename', child: Text(t.rename)),
              PopupMenuItem(value: 'delete', child: Text(t.delete)),
            ],
          ),
        ],
      ),
    );
  }
}

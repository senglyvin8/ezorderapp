import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import 'scanner_screen.dart';

/// Stand-in for pointing a phone camera at the sticker on the table.
///
/// A real diner never sees this screen: their camera opens
/// `/order/demo/table/05` directly. It exists so the prototype can be
/// demonstrated on any device.
class QrEntryScreen extends StatelessWidget {
  const QrEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final tables = store.tables;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: PageWidth(
          maxWidth: 620,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.brandTint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(store.settings.logo,
                        style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.restaurantDisplayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          store.settings.address,
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded,
                            color: AppColors.brand),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.scanTitle,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.scanBlurb,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ScannerScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: Text(t.openScanner),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Someone ordering to take away has no table to scan.
                    OutlinedButton.icon(
                      onPressed: store.startTakeaway,
                      icon: const Icon(Icons.shopping_bag_rounded, size: 19),
                      label: Text(t.startTakeaway),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SectionLabel(t.orTapTable),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 420 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tables.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      // A fixed height rather than a ratio: the tile has to
                      // hold two lines of text at any column count, and at up
                      // to 1.3x text scaling.
                      mainAxisExtent: 148,
                    ),
                    itemBuilder: (context, index) {
                      final table = tables[index];
                      final occupied = store.isTableOccupied(table.id);
                      return AppCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () => store.openTable(table.id),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.qr_code_2_rounded,
                                size: 26, color: AppColors.brand),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.table(table.number),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  occupied ? t.occupied : t.available,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: occupied
                                        ? AppColors.statusCooking
                                        : AppColors.statusReady,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

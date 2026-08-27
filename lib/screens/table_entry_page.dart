import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

/// Landing page for a scanned table QR code.
///
/// It opens the table for ordering and hands over to the customer menu, which
/// is what a diner sees a second after pointing their camera at the sticker.
class TableEntryPage extends StatefulWidget {
  const TableEntryPage({super.key, required this.tableNumber});

  final String tableNumber;

  @override
  State<TableEntryPage> createState() => _TableEntryPageState();
}

class _TableEntryPageState extends State<TableEntryPage> {
  bool _unknownTable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  void _open() {
    // Post-frame callbacks still run if the route was replaced in the
    // meantime — a fast back-navigation off a deep link does exactly that.
    if (!mounted) return;
    final store = context.read<AppStore>();
    final padded = widget.tableNumber.padLeft(2, '0');
    final table =
        store.tableByNumber(padded) ?? store.tableByNumber(widget.tableNumber);

    if (table == null) {
      setState(() => _unknownTable = true);
      return;
    }
    store.setMode(AppMode.customer);
    store.openTable(table.id);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const AppShell(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_unknownTable) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final t = context.watch<AppStore>().text;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: EmptyState(
        icon: Icons.qr_code_2_rounded,
        title: t.tableNotFound(widget.tableNumber),
        message: t.tableNotFoundBlurb,
        action: FilledButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/'),
              builder: (_) => const AppShell(),
            ),
          ),
          child: Text(t.goToDemo),
        ),
      ),
    );
  }
}

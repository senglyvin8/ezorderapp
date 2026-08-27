import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/report_panel.dart';

/// The owner's dashboard.
///
/// It is the report, over whatever window they choose. There used to be a
/// separate hard-coded "today" summary and a recent-orders list above it;
/// both said less than the report does and could disagree with it, so the
/// report simply took over.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        automaticallyImplyLeading: false,
        title: store.restaurantDisplayName,
        subtitle: DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
      ),
      body: const ReportPanel(),
    );
  }
}

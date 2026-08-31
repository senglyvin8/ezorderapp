import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// Reads the restaurant again, now.
///
/// Everything after the first load arrives over a websocket, and a websocket on
/// a phone in a kitchen does not stay up — it sleeps in a pocket, moves between
/// access points, and comes back without mentioning that it went. When that
/// happens the board is quietly showing an old shift, which is worse than
/// showing nothing: nobody doubts a board that looks fine.
///
/// This is the way out that does not involve force-quitting the app. Hidden on
/// the demo, where there is nothing to re-read and nothing to be stale about.
class RefreshButton extends StatefulWidget {
  const RefreshButton({super.key});

  @override
  State<RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<RefreshButton> {
  bool _busy = false;

  Future<void> _refresh(AppStore store) async {
    setState(() => _busy = true);
    try {
      await store.refresh();
    } on StateError catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (store.isDemo) return const SizedBox.shrink();

    return IconButton(
      tooltip: store.text.refresh,
      onPressed: _busy ? null : () => _refresh(store),
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.inkSoft,
              ),
            )
          : const Icon(Icons.refresh_rounded),
    );
  }
}

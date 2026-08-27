import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// Says out loud that work has arrived.
///
/// A kitchen screen is mounted on a wall and nobody is looking at it. A ticket
/// that only appears silently is a ticket that gets cooked late, so this makes
/// a noise and puts a banner over the board until somebody acknowledges it.
///
/// It watches a *count* rather than listening for events, which matters: the
/// count comes from [AppStore], which is refreshed by realtime, so this fires
/// for an order placed on a diner's phone across the room exactly as it does
/// for one keyed in at the till. And because it compares against the previous
/// count, the state the screen opened with is the baseline — signing in to
/// four waiting tickets does not set off an alarm about four tickets that have
/// been sitting there all morning.
class WorkAlert extends StatefulWidget {
  const WorkAlert({
    super.key,
    required this.count,
    required this.message,
    required this.child,
    this.color = AppColors.statusNew,
    this.icon = Icons.notifications_active_rounded,
  });

  /// How many things currently need attention. An increase is the alert.
  final int count;

  /// What to say. Built by the caller so it can name the number.
  final String message;

  final Widget child;
  final Color color;
  final IconData icon;

  @override
  State<WorkAlert> createState() => _WorkAlertState();
}

class _WorkAlertState extends State<WorkAlert> {
  static final AudioPlayer _player = AudioPlayer();

  int? _seen;
  bool _showing = false;
  Timer? _hide;

  @override
  void didUpdateWidget(WorkAlert old) {
    super.didUpdateWidget(old);
    final previous = _seen ?? old.count;
    _seen = widget.count;
    if (widget.count > previous) _ring();
  }

  @override
  void initState() {
    super.initState();
    // The opening count is the baseline, never an alert.
    _seen = widget.count;
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  Future<void> _ring() async {
    setState(() => _showing = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _showing = false);
    });

    // Belt and braces: a chime for the room, a buzz for whoever is holding
    // the device. Neither is available everywhere, and a failure to make a
    // noise must never take the board down with it.
    try {
      await _player.play(AssetSource('sound/new-order.wav'));
    } catch (error) {
      debugPrint('EZ Order: could not play the alert. $error');
    }
    if (!kIsWeb) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showing)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _Banner(
              message: widget.message,
              color: widget.color,
              icon: widget.icon,
              onDismiss: () => setState(() => _showing = false),
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismiss,
  });

  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -1, end: 0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, slide, child) => FractionalTranslation(
        translation: Offset(0, slide),
        child: child,
      ),
      child: Material(
        color: color,
        elevation: 8,
        child: SafeArea(
          bottom: false,
          child: InkWell(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: PageWidth(
                maxWidth: 900,
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

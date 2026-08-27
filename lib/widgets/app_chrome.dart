import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared app bar. Styled explicitly rather than through `appBarTheme` so the
/// chrome looks the same on every Flutter version.
AppBar appTopBar({
  required String title,
  String? subtitle,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    backgroundColor: AppColors.card,
    surfaceTintColor: Colors.transparent,
    foregroundColor: AppColors.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleSpacing: 16,
    toolbarHeight: 60,
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    title: subtitle == null
        ? Text(title, style: AppType.screenTitle)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.screenTitle),
              const SizedBox(height: 1),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.screenSubtitle),
            ],
          ),
    actions: actions,
    bottom: bottom ??
        const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
  );
}

/// White surface with a hairline border and a whisper of elevation — the base
/// of every panel in the app.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.color,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;

  /// Nested panels set this to false so shadows do not stack up.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: elevated ? AppShadows.card : null,
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return content;
    // The ink well wraps the content rather than overlaying it, so buttons
    // inside the card still receive their own taps.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: content,
      ),
    );
  }
}

/// Quiet label that introduces a group of cards.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Centres page content and stops it stretching on tablet and desktop.
///
/// `heightFactor: 1` matters: without it the [Align] expands to the tallest
/// height it is offered, which silently eats the whole screen when this is
/// used inside a `bottomNavigationBar` and collapses the body to nothing.
/// Scrolling children still fill the space, because a viewport sizes itself to
/// the biggest height it is given.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.maxWidth = 560});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Friendly placeholder for an empty list.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 26, color: AppColors.inkFaint),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppType.body,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 22),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Consistent decoration for the handful of forms in the admin area.
InputDecoration appInput({
  String? label,
  String? hint,
  String? prefixText,
  Widget? suffixIcon,
}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
    borderSide: BorderSide(color: AppColors.borderStrong),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.card,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
    labelStyle: const TextStyle(
      color: AppColors.inkSoft,
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: const TextStyle(
      color: AppColors.brandDark,
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: const TextStyle(color: AppColors.inkFaint, fontSize: 14.5),
    border: border,
    enabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
      borderSide: BorderSide(color: AppColors.brand, width: 1.5),
    ),
  );
}

/// How tall a bottom sheet may be, given whatever the keyboard is covering.
///
/// A sheet that lifts itself by `viewInsets.bottom` and *then* asks for a
/// fraction of the *whole* screen ends up taller than the room it has left. The
/// overflow goes off the top — which is exactly where the field being typed
/// into usually is, so the keyboard appears and the text box vanishes.
///
/// Measure the space that is actually free instead.
double sheetMaxHeight(BuildContext context, {double fraction = 0.9}) {
  final media = MediaQuery.of(context);
  final free = media.size.height - media.viewInsets.bottom;
  // Never collapse to nothing on a small screen with a tall keyboard.
  return (free * fraction).clamp(220.0, media.size.height);
}

/// Rounded confirmation dialog used before any irreversible action.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
      content: Text(message, style: AppType.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel,
              style: const TextStyle(color: AppColors.inkSoft)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 42),
            backgroundColor: destructive ? AppColors.danger : AppColors.brand,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single place for the toast used across roles.
void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.ink,
        duration: const Duration(seconds: 2),
      ),
    );
}

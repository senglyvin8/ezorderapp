import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../l10n/app_text.dart';
import '../screens/auth/sign_in_screen.dart';
import '../theme/app_theme.dart';
import 'language_toggle.dart';

/// The bar above every screen: who you are, which view you are in, and the
/// language switch.
///
/// Signed out it offers the customer experience and a way in for staff.
/// Signed in it names the account, lets an owner flip between the customer
/// view and their workspace, and signs out.
class SessionBar extends StatelessWidget {
  const SessionBar({super.key});

  static const _bar = Color(0xFF0D1017);
  static const _track = Color(0xFF1C212B);
  static const _idle = Color(0xFF98A1B2);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final user = store.currentUser;
    final wide = MediaQuery.sizeOf(context).width >= 560;

    return Material(
      color: _bar,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 10, 9),
          child: Row(
            children: [
              if (user == null) ...[
                const Icon(Icons.storefront_rounded, size: 17, color: _idle),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.browsingAsCustomer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _idle,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _DarkButton(
                  icon: Icons.lock_open_rounded,
                  label: t.staffSignIn,
                  showLabel: wide,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SignInScreen(),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: roleColor(user.role),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(roleIcon(user.role), size: 15, color: Colors.white),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        roleLabel(user.role, t),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _idle,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _ModeToggle(store: store, t: t, compact: !wide),
                const SizedBox(width: 8),
                _DarkButton(
                  icon: Icons.logout_rounded,
                  label: t.signOut,
                  showLabel: false,
                  onTap: store.signOut,
                ),
              ],
              const SizedBox(width: 8),
              LanguageToggle(
                key: languageToggleKey,
                language: store.language,
                onTap: store.toggleLanguage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.store,
    required this.t,
    required this.compact,
  });

  final AppStore store;
  final AppText t;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: SessionBar._track,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeChip(
            icon: Icons.badge_rounded,
            label: t.myWorkspace,
            showLabel: !compact,
            selected: store.mode == AppMode.staff,
            onTap: () => store.setMode(AppMode.staff),
          ),
          _ModeChip(
            icon: Icons.storefront_rounded,
            label: t.customerView,
            showLabel: !compact,
            selected: store.mode == AppMode.customer,
            onTap: () => store.setMode(AppMode.customer),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.showLabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool showLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : SessionBar._idle;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: showLabel ? 12 : 10,
                vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                if (showLabel) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  const _DarkButton({
    required this.icon,
    required this.label,
    required this.showLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: SessionBar._track,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: showLabel ? 12 : 10, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: Colors.white),
                if (showLabel) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


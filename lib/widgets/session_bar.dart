import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../l10n/app_text.dart';
import '../screens/auth/sign_in_screen.dart';
import '../theme/app_theme.dart';

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

  /// The language mark: a black disc, so it reads as its own thing rather
  /// than another pill in the row.
  static const _mark = Color(0xFF000000);
  static const _markEdge = Color(0xFF2C3342);

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
              _LanguageToggle(
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

/// Handle for the language mark, so tests reach it by identity rather than by
/// whichever glyph the design happens to use.
const Key languageToggleKey = Key('session-bar-language');

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({
    super.key,
    required this.language,
    required this.onTap,
  });

  final AppLanguage language;
  final VoidCallback onTap;

  /// Diameter of the mark. With the bar's padding around it this clears the
  /// 44pt minimum tap target.
  static const double _size = 38;

  @override
  Widget build(BuildContext context) {
    // A black disc carrying the language's own two characters. It reads as a
    // mark rather than one more pill in the row, and it says which language
    // you are in as well as offering the switch — a bare globe would only do
    // the second.
    return Semantics(
      button: true,
      label: '${language.label} — tap to switch',
      child: Tooltip(
        message: language.label,
        child: Material(
          color: SessionBar._mark,
          shape: const CircleBorder(
            side: BorderSide(color: SessionBar._markEdge),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: _size,
              height: _size,
              child: Center(
                child: Text(
                  language.short,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  // Khmer is one letter against English's two, and its glyph
                  // carries more detail — it needs the larger size to weigh
                  // the same inside the disc.
                  style: TextStyle(
                    fontSize: language == AppLanguage.km ? 18 : 13.5,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

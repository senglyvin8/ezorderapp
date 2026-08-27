import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/demo_data.dart';
import '../../data/merchant_binding.dart';
import '../../l10n/app_text.dart';
import '../../models/staff_account.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';

/// Staff sign-in.
///
/// Kitchen and cashier staff tap their name and key in a PIN — fast on a
/// shared tablet. The owner uses a username and password.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  StaffAccount? _picked;
  String _pin = '';
  String? _error;
  bool _adminMode = false;
  bool _busy = false;

  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _press(String digit) {
    if (_busy || _pin.length >= StaffAccount.pinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    // Six digits is the whole PIN, so there is nothing left to confirm.
    if (_pin.length == StaffAccount.pinLength) _tryPin();
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _tryPin() async {
    final store = context.read<AppStore>();
    final account = _picked;
    if (account == null) return;

    setState(() => _busy = true);
    final ok = await store.signInWithPin(account.id, _pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = account.active ? store.text.wrongPin : store.text.accountDisabled;
      _pin = '';
    });
  }

  Future<void> _tryPassword() async {
    final store = context.read<AppStore>();
    setState(() => _busy = true);
    final ok = await store.signInWithPassword(_username.text, _password.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = store.text.wrongPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: t.staffSignIn,
        subtitle: store.restaurantDisplayName,
      ),
      body: PageWidth(
        maxWidth: 460,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            if (_adminMode)
              _AdminForm(
                t: t,
                username: _username,
                password: _password,
                error: _error,
                busy: _busy,
                onSubmit: _tryPassword,
                onBack: () => setState(() {
                  _adminMode = false;
                  _error = null;
                }),
              )
            else if (_picked == null)
              _StaffPicker(
                t: t,
                accounts: store.pinAccounts,
                onPick: (account) => setState(() {
                  _picked = account;
                  _pin = '';
                  _error = null;
                }),
                onAdmin: () => setState(() {
                  _adminMode = true;
                  _error = null;
                }),
              )
            else
              _PinPad(
                t: t,
                account: _picked!,
                pin: _pin,
                error: _error,
                busy: _busy,
                onDigit: _press,
                onBackspace: _backspace,
                onBack: () => setState(() {
                  _picked = null;
                  _pin = '';
                  _error = null;
                }),
              ),
            const SizedBox(height: 26),
            // Which of the two this build is, and — when it is the demo by
            // accident — exactly which define was left out.
            if (store.isDemo)
              _DemoCredentials(t: t)
            else
              _ConnectedTo(store: store),
          ],
        ),
      ),
    );
  }
}

class _StaffPicker extends StatelessWidget {
  const _StaffPicker({
    required this.t,
    required this.accounts,
    required this.onPick,
    required this.onAdmin,
  });

  final AppText t;
  final List<StaffAccount> accounts;
  final ValueChanged<StaffAccount> onPick;
  final VoidCallback onAdmin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(t.chooseYourName),
        if (accounts.isEmpty)
          AppCard(
            child: Text(t.staffSubtitle, style: AppType.body),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < accounts.length; i++) ...[
                  if (i > 0) const Divider(),
                  _AccountRow(account: accounts[i], onTap: () => onPick(accounts[i])),
                ],
              ],
            ),
          ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onAdmin,
          icon: const Icon(Icons.shield_outlined, size: 19),
          label: Text(t.adminSignIn),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.onTap});

  final StaffAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppStore>().text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint(roleColor(account.role)),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(roleIcon(account.role),
                  size: 20, color: roleColor(account.role)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name, style: AppType.cardTitle),
                  const SizedBox(height: 2),
                  Text(roleLabel(account.role, t), style: AppType.label),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.t,
    required this.account,
    required this.pin,
    required this.error,
    required this.busy,
    required this.onDigit,
    required this.onBackspace,
    required this.onBack,
  });

  final AppText t;
  final StaffAccount account;
  final String pin;
  final String? error;
  final bool busy;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppColors.inkSoft,
            ),
            Expanded(
              child: Text(
                account.name,
                textAlign: TextAlign.center,
                style: AppType.cardTitle,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 6),
        Text(t.enterPin, style: AppType.label),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < StaffAccount.pinLength; i++)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: i < pin.length ? AppColors.brand : AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i < pin.length
                        ? AppColors.brand
                        : AppColors.borderStrong,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 20,
          child: busy
              ? Text(t.checking, style: AppType.label)
              : (error == null
                  ? null
                  : Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    )),
        ),
        const SizedBox(height: 10),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: key.isEmpty
                          ? const SizedBox(height: 58)
                          : _Key(
                              label: key,
                              onTap: () =>
                                  key == '<' ? onBackspace() : onDigit(key),
                            ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBackspace = label == '<';
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppColors.border),
          ),
          child: isBackspace
              ? const Icon(Icons.backspace_outlined, size: 20)
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

class _AdminForm extends StatelessWidget {
  const _AdminForm({
    required this.t,
    required this.username,
    required this.password,
    required this.error,
    required this.busy,
    required this.onSubmit,
    required this.onBack,
  });

  final AppText t;
  final TextEditingController username;
  final TextEditingController password;
  final String? error;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppColors.inkSoft,
            ),
            Expanded(
              child: Text(t.adminSignIn,
                  textAlign: TextAlign.center, style: AppType.cardTitle),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: username,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.emailAddress,
          // Labelled as an address because that is what a new owner has. An
          // owner still signing in with the username they were given years
          // ago types it here and it works exactly as before.
          decoration: appInput(label: t.emailOrUsername),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: true,
          onSubmitted: (_) => onSubmit(),
          decoration: appInput(label: t.password),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: Text(busy ? t.checking : t.signIn),
        ),
      ],
    );
  }
}

/// Shown instead of the demo logins once the app is talking to a real
/// database, so nobody wonders why `admin / admin1234` stopped working.
/// Which restaurant this device is serving, and — on a build where that is a
/// device setting rather than a compile-time one — how to change it.
///
/// This is where somebody re-purposing a tablet will look, which is why the
/// way out lives here rather than behind an admin screen a cashier cannot
/// reach.
class _ConnectedTo extends StatelessWidget {
  const _ConnectedTo({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final rebind = context.read<RebindDevice?>();
    final name = store.settings.name;
    final code = store.settings.code;

    return AppCard(
      color: AppColors.surface,
      elevated: false,
      child: Row(
        children: [
          const Icon(Icons.cloud_done_rounded,
              size: 17, color: AppColors.statusReady),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              code.isEmpty
                  ? t.deviceSetUpFor(name)
                  : '${t.deviceSetUpFor(name)} · $code',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          if (rebind != null)
            TextButton(
              onPressed: () async {
                final confirmed = await confirmDialog(
                  context,
                  title: t.changeRestaurant,
                  message: t.bindBlurb,
                  confirmLabel: t.changeRestaurant,
                  cancelLabel: t.cancel,
                );
                if (confirmed) await rebind();
              },
              child: Text(t.changeRestaurant),
            ),
        ],
      ),
    );
  }
}

class _DemoCredentials extends StatelessWidget {
  const _DemoCredentials({required this.t});

  final AppText t;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surface,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 17, color: AppColors.inkFaint),
              const SizedBox(width: 7),
              Text(t.demoCredentials,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Owner    ${DemoData.adminEmail} / ${DemoData.adminPassword}\n'
            'Kitchen  ${DemoData.kitchenName} · PIN ${DemoData.kitchenPin}\n'
            'Cashier  ${DemoData.cashierName} · PIN ${DemoData.cashierPin}',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.inkFaint,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared role presentation, used by sign-in and by staff management.
Color roleColor(StaffRole role) => switch (role) {
      StaffRole.admin => AppColors.statusPaid,
      StaffRole.kitchen => AppColors.statusCooking,
      StaffRole.cashier => AppColors.statusReady,
    };

IconData roleIcon(StaffRole role) => switch (role) {
      StaffRole.admin => Icons.shield_rounded,
      StaffRole.kitchen => Icons.soup_kitchen_rounded,
      StaffRole.cashier => Icons.point_of_sale_rounded,
    };

String roleLabel(StaffRole role, AppText t) => switch (role) {
      StaffRole.admin => t.roleAdmin,
      StaffRole.kitchen => t.roleKitchen,
      StaffRole.cashier => t.roleCashier,
    };

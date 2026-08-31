import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/email_address.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';

/// Asks for the address to send a recovery link to.
///
/// Owners only. Kitchen and cashier staff sign in with a PIN and have no
/// address to send anything to; theirs is reset by the owner from the staff
/// screen, which the sheet says rather than leaving them to wonder.
Future<void> showPasswordResetSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PasswordResetSheet(),
  );
}

class _PasswordResetSheet extends StatefulWidget {
  const _PasswordResetSheet();

  @override
  State<_PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<_PasswordResetSheet> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send(AppStore store) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await store.sendPasswordReset(_email.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final valid = EmailAddress.isValid(_email.text);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: PageWidth(
          maxWidth: 460,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.resetPasswordTitle,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  // Once the link is away, the address is no longer the point.
                  _sent ? t.resetLinkSent : t.resetPasswordBlurb,
                  style: AppType.body,
                ),
                const SizedBox(height: 18),
                if (!_sent) ...[
                  TextField(
                    controller: _email,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted:
                        valid && !_busy ? (_) => _send(store) : null,
                    decoration: appInput(label: t.emailAddress),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: valid && !_busy ? () => _send(store) : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: Text(_busy ? t.checking : t.sendResetLink),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.inkFaint),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(t.staffAskYourOwner, style: AppType.label),
                      ),
                    ],
                  ),
                ] else
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: Text(t.done),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when a recovery link has been followed.
///
/// The link is what authorises this — following it opens a session that can do
/// exactly one useful thing — so there is no old password to confirm and no
/// way back to the rest of the app until a new one is set.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key, this.onDone});

  /// Called once the new password is saved, so the shell can stop showing
  /// this and go back to whatever it would otherwise have shown.
  final VoidCallback? onDone;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save(AppStore store) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await store.setNewPassword(_password.text);
      if (!mounted) return;
      showToast(context, store.text.newPasswordSaved);
      // Reached two ways: pushed, and shown by the shell after a recovery
      // link. Only one of them has something to pop back to.
      widget.onDone?.call();
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final longEnough = _password.text.trim().length >= 8;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(title: t.chooseNewPassword),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 460,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _password,
                  autofocus: true,
                  obscureText: true,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: appInput(
                    label: t.newPassword,
                    hint: t.passwordRule,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.danger)),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: longEnough && !_busy ? () => _save(store) : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: Text(_busy ? t.checking : t.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

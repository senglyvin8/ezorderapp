import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/email_address.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// The address the owner signs in with, and a way to change it.
///
/// Owners created before real addresses existed have a manufactured one —
/// `admin@sunrise.staff.ezorder.app` — which they never chose, cannot receive
/// anything at, and would struggle to read out. This is how they stop having
/// it, without anyone having to touch the database on their behalf.
///
/// Only shown to an owner. Kitchen and cashier staff sign in with a PIN and
/// have no address to change.
class SignInEmailCard extends StatefulWidget {
  const SignInEmailCard({super.key, required this.store});

  final AppStore store;

  @override
  State<SignInEmailCard> createState() => _SignInEmailCardState();
}

class _SignInEmailCardState extends State<SignInEmailCard> {
  final TextEditingController _email = TextEditingController();
  bool _editing = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = widget.store.text;
    if (!EmailAddress.isValid(_email.text)) {
      setState(() => _error = t.emailMalformed);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.setMyLoginEmail(_email.text);
      if (!mounted) return;
      setState(() => _editing = false);
      showToast(context, t.emailSaved);
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final t = store.text;
    final me = store.currentUser;
    if (me == null || !me.usesPassword) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alternate_email_rounded,
                  size: 18, color: AppColors.inkFaint),
              const SizedBox(width: 8),
              Expanded(child: Text(t.signInEmail, style: AppType.label)),
              if (!_editing)
                TextButton(
                  onPressed: () => setState(() {
                    _editing = true;
                    _email.text = me.email;
                    _error = null;
                  }),
                  child: Text(me.email.isEmpty ? t.add : t.edit),
                ),
            ],
          ),
          const SizedBox(height: 2),
          if (!_editing) ...[
            Text(
              // A legacy owner has no address, so show what they actually type
              // rather than a blank line that looks like a bug.
              me.email.isEmpty ? me.username : me.email,
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(t.signInEmailBlurb, style: AppType.body),
          ] else ...[
            const SizedBox(height: 6),
            TextField(
              controller: _email,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: _busy ? null : (_) => _save(),
              decoration: appInput(label: t.emailAddress),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _editing = false;
                              _error = null;
                            }),
                    child: Text(t.cancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(t.save),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

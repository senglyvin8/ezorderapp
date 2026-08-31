import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/backend/backend.dart';
import '../../models/email_address.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';

/// Asking to put a restaurant on the service.
///
/// One form, not a wizard: there is no code to wait for, so splitting five
/// fields across three screens would be ceremony without a reason. It ends in a
/// request rather than a restaurant — somebody with console access says yes,
/// and until they do the account exists and can do nothing.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.onCancel});

  /// Back to signing in. Null when there is nowhere to go back to.
  final VoidCallback? onCancel;

  /// Mirrors slugify() in 0015 closely enough to show something sensible while
  /// typing. The database has the final say on what is stored.
  static String slugify(String name) {
    // Apostrophes come out rather than becoming separators, so "Sengly's
    // Kitchen" is senglys-kitchen. Both the straight one and the curly one a
    // phone keyboard produces.
    final lower = name.toLowerCase().replaceAll(RegExp("['’`]"), '');
    final dashed = lower.replaceAll(RegExp('[^a-z0-9]+'), '-');
    final trimmed = dashed.replaceAll(RegExp(r'^-+|-+$'), '');
    return trimmed.length <= 40
        ? trimmed
        : trimmed.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
  }

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _restaurant = TextEditingController();
  final _owner = TextEditingController();
  final _slug = TextEditingController();

  bool _busy = false;
  bool _sent = false;
  String? _error;

  /// Null while unknown — the label says nothing rather than guessing, because
  /// "taken" on a free address is worse than silence.
  bool? _slugFree;

  /// Once the applicant edits the address themselves their spelling wins and
  /// the restaurant name stops overwriting it.
  bool _slugEdited = false;

  @override
  void initState() {
    super.initState();
    _restaurant.addListener(_suggestSlug);
  }

  @override
  void dispose() {
    _restaurant.removeListener(_suggestSlug);
    for (final c in [_email, _password, _restaurant, _owner, _slug]) {
      c.dispose();
    }
    super.dispose();
  }

  void _suggestSlug() {
    if (_slugEdited) return;
    final next = SignUpScreen.slugify(_restaurant.text);
    if (next == _slug.text) return;
    _slug.text = next;
    _checkSlug();
  }

  Future<void> _checkSlug() async {
    final value = _slug.text.trim();
    setState(() => _slugFree = null);
    if (value.length < 3) return;
    final free = await context.read<AppStore>().slugAvailable(value);
    if (!mounted || _slug.text.trim() != value) return;
    setState(() => _slugFree = free);
  }

  Future<void> _submit(AppStore store) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await store.requestSignUp(
        email: _email.text,
        password: _password.text,
        restaurantName: _restaurant.text,
        slug: _slug.text,
        ownerName: _owner.text,
      );
      if (mounted) setState(() => _sent = true);
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _ready =>
      EmailAddress.isValid(_email.text) &&
      _password.text.trim().length >= 8 &&
      _restaurant.text.trim().isNotEmpty &&
      _slugFree == true &&
      !_busy;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: t.createRestaurant,
        automaticallyImplyLeading: false,
        actions: [
          if (widget.onCancel != null && !_sent)
            TextButton(
              onPressed: widget.onCancel,
              child: Text(t.signIn,
                  style: const TextStyle(color: AppColors.inkSoft)),
            ),
        ],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 460,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _sent ? _thanks(t) : _form(store, t),
          ),
        ),
      ),
    );
  }

  Widget _thanks(t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.mark_email_read_rounded,
              size: 44, color: AppColors.statusReady),
          const SizedBox(height: 16),
          Text(t.requestSentTitle,
              style:
                  const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(t.requestSentBody, style: AppType.body),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.onCancel,
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
            child: Text(t.done),
          ),
        ],
      );

  Widget _form(AppStore store, t) {
    final shortPassword =
        _password.text.isNotEmpty && _password.text.trim().length < 8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.signUpBlurb, style: AppType.body),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          onChanged: (_) => setState(() => _error = null),
          decoration: appInput(label: t.emailAddress),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          onChanged: (_) => setState(() => _error = null),
          decoration: appInput(label: t.password, hint: t.passwordRule),
        ),
        if (shortPassword)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(t.passwordRule,
                style: const TextStyle(fontSize: 13, color: AppColors.danger)),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _restaurant,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _error = null),
          decoration: appInput(label: t.restaurantName),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _owner,
          textCapitalization: TextCapitalization.words,
          decoration: appInput(label: t.yourName),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _slug,
          autocorrect: false,
          onChanged: (_) {
            _slugEdited = true;
            setState(() => _error = null);
            _checkSlug();
          },
          decoration: appInput(label: t.webAddress),
        ),
        const SizedBox(height: 6),
        Text(
          _slug.text.trim().length < 3
              ? t.webAddressBlurb
              : (_slugFree == null
                  ? t.checking
                  : (_slugFree! ? t.addressFree : t.addressTaken)),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: _slugFree == null ? FontWeight.w500 : FontWeight.w600,
            color: _slugFree == false
                ? AppColors.danger
                : (_slugFree == true
                    ? AppColors.statusReady
                    : AppColors.inkSoft),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(fontSize: 14, color: AppColors.danger)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _ready ? () => _submit(store) : null,
          style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52)),
          child: Text(_busy ? t.checking : t.askToJoin),
        ),
        if (widget.onCancel != null) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkSoft,
              minimumSize: const Size(double.infinity, 44),
            ),
            child: Text(t.alreadyHaveAccount),
          ),
        ],
      ],
    );
  }
}

/// Shown to somebody who signed in while their request is still unanswered.
///
/// Their account is real and it runs nothing: no staff row means every guarded
/// function in the database refuses it. Without this screen the app would be a
/// series of empty tabs that error on touch, and they would reasonably conclude
/// it was broken rather than pending.
class AwaitingApprovalScreen extends StatelessWidget {
  const AwaitingApprovalScreen({
    super.key,
    required this.request,
    required this.onSignOut,
  });

  final SignUpRequest request;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppStore>().text;
    final refused = request.status == SignUpStatus.rejected;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: PageWidth(
          maxWidth: 460,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  refused ? Icons.info_outline_rounded : Icons.hourglass_top_rounded,
                  size: 44,
                  color: refused ? AppColors.danger : AppColors.statusCooking,
                ),
                const SizedBox(height: 16),
                Text(
                  refused ? t.requestRefused : t.awaitingApproval,
                  style:
                      const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  // A refusal shows the reason it was given, because "no" with
                  // no reason is the least useful answer there is.
                  refused && request.note.trim().isNotEmpty
                      ? request.note
                      : (refused ? t.requestRefused : t.awaitingApprovalBody),
                  style: AppType.body,
                ),
                const SizedBox(height: 18),
                Text(request.restaurantName, style: AppType.cardTitle),
                Text(request.slug, style: AppType.label),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: onSignOut,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: Text(t.signOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

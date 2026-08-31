import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/email_address.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';

/// Setting up a restaurant without asking anybody's permission.
///
/// Three steps, one at a time, because asking for an address, a code, a
/// restaurant name and a web address on one screen is how people give up
/// halfway. Each step is the only thing on screen and each one is short.
///
/// The code is what makes this safe to leave open: an account exists after the
/// first step and can do nothing at all until the address behind it is proved.
enum _Step { address, code, restaurant }

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.onCancel});

  /// Back to signing in. Null when there is nowhere to go back to.
  final VoidCallback? onCancel;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _restaurant = TextEditingController();
  final _owner = TextEditingController();
  final _slug = TextEditingController();

  _Step _step = _Step.address;
  bool _busy = false;
  String? _error;

  /// Null while unknown or unchecked — the label says nothing rather than
  /// guessing, because "taken" on a free address is worse than silence.
  bool? _slugFree;

  /// True once the owner edits the address themselves, after which their
  /// spelling wins and the restaurant name stops overwriting it.
  bool _slugEdited = false;

  @override
  void initState() {
    super.initState();
    _restaurant.addListener(_suggestSlug);
  }

  @override
  void dispose() {
    _restaurant.removeListener(_suggestSlug);
    for (final c in [_email, _code, _restaurant, _owner, _slug]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Mirrors slugify() in 0015 closely enough to show something sensible while
  /// typing. The database has the final say on the value that is stored.
  static String _slugify(String name) {
    // Apostrophes come out rather than becoming separators, so "Sengly's
    // Kitchen" is senglys-kitchen. Both the straight one and the curly one a
    // phone keyboard actually produces.
    final lower =
        name.toLowerCase().replaceAll(RegExp("['\u2019`]"), '');
    final dashed = lower.replaceAll(RegExp('[^a-z0-9]+'), '-');
    final trimmed = dashed.replaceAll(RegExp('^-+|-+\$'), '');
    return trimmed.length <= 40
        ? trimmed
        : trimmed.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
  }

  void _suggestSlug() {
    if (_slugEdited) return;
    final next = _slugify(_restaurant.text);
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

  Future<void> _run(Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode(AppStore store) => _run(() async {
        await store.sendSignUpCode(_email.text);
        if (mounted) setState(() => _step = _Step.code);
      });

  Future<void> _verify(AppStore store) => _run(() async {
        final ok = await store.verifySignUpCode(_email.text, _code.text);
        if (!mounted) return;
        if (ok) {
          setState(() => _step = _Step.restaurant);
        } else {
          setState(() {
            _error = store.text.wrongCode;
            _code.clear();
          });
        }
      });

  Future<void> _claim(AppStore store) => _run(() async {
        await store.claimRestaurant(
          restaurantName: _restaurant.text,
          slug: _slug.text,
          ownerName: _owner.text,
        );
        // Nothing to pop to: the shell rebuilds now that this account runs a
        // restaurant, and lands on the owner's workspace.
      });

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
          if (widget.onCancel != null && _step == _Step.address)
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...switch (_step) {
                  _Step.address => _addressStep(store, t),
                  _Step.code => _codeStep(store, t),
                  _Step.restaurant => _restaurantStep(store, t),
                },
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.danger)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _addressStep(AppStore store, t) {
    final valid = EmailAddress.isValid(_email.text);
    return [
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
      const SizedBox(height: 18),
      FilledButton(
        onPressed: valid && !_busy ? () => _sendCode(store) : null,
        style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52)),
        child: Text(_busy ? t.checking : t.sendTheCode),
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
    ];
  }

  List<Widget> _codeStep(AppStore store, t) {
    final ready = _code.text.trim().length >= 6;
    return [
      Text(t.codeSentTo(_email.text.trim()), style: AppType.body),
      const SizedBox(height: 20),
      TextField(
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        style: const TextStyle(fontSize: 26, letterSpacing: 8),
        textAlign: TextAlign.center,
        onChanged: (_) => setState(() => _error = null),
        decoration: appInput(label: t.theCode),
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: ready && !_busy ? () => _verify(store) : null,
        style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52)),
        child: Text(_busy ? t.checking : t.done),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _busy ? null : () => _sendCode(store),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.inkSoft,
          minimumSize: const Size(double.infinity, 44),
        ),
        child: Text(t.resendTheCode),
      ),
    ];
  }

  List<Widget> _restaurantStep(AppStore store, t) {
    final named = _restaurant.text.trim().isNotEmpty;
    final ready = named && _slugFree == true && !_busy;
    return [
      TextField(
        controller: _restaurant,
        autofocus: true,
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
              : (_slugFree == true ? AppColors.statusReady : AppColors.inkSoft),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: ready ? () => _claim(store) : null,
        style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52)),
        child: Text(_busy ? t.checking : t.openMyRestaurant),
      ),
    ];
  }
}

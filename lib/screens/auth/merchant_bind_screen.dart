import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../data/merchant_binding.dart';
import '../../l10n/app_text.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';

/// Pointing a device at a restaurant, once.
///
/// This is the screen that replaced `--dart-define=RESTAURANT_SLUG`, and there
/// is exactly one way through it: the owner signs in. Their address says who
/// they are, their staff row says where they work, and the device is bound to
/// whatever that turns out to be. Nothing to read off somebody else's screen,
/// nothing to type that another person invented.
///
/// Setting up a kitchen tablet is therefore the owner signing in on it once and
/// signing out again. The binding stays behind; the staff who use it from then
/// on tap their name and key in a PIN, and never see this screen at all.
///
/// A visitor with no account gets the other thing on the page: the demo.
///
/// It runs before there is an [AppStore] — there is no restaurant to have a
/// store *of* yet — so the strings are handed in rather than read from one.
class MerchantBindScreen extends StatefulWidget {
  const MerchantBindScreen({
    super.key,
    required this.text,
    required this.signIn,
    required this.onBound,
    this.byCode,
    this.onGuest,
    this.current,
  });

  final AppText text;

  /// Signs an owner in and reports which restaurant they run.
  final MerchantSignIn signIn;

  /// Finds a restaurant from its merchant ID.
  ///
  /// The staff door. A cashier has a PIN and no password, and no business
  /// knowing the owner's, so signing in as the owner cannot be how they set
  /// their own phone up. Null on a build where there is nothing to look up.
  final MerchantByCode? byCode;

  final void Function(MerchantBinding binding) onBound;

  /// Opens the on-device demo instead, for somebody who has just downloaded the
  /// app and has no account at all.
  final VoidCallback? onGuest;

  /// What this device is bound to now, when it is being re-pointed rather than
  /// set up. Shown so somebody re-purposing a tablet can see what they are
  /// about to replace.
  final MerchantBinding? current;

  @override
  State<MerchantBindScreen> createState() => _MerchantBindScreenState();
}

class _MerchantBindScreenState extends State<MerchantBindScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Which door is showing. Staff outnumber owners on any given day, but the
  /// owner is the one setting a device up for the first time, so that is what
  /// opens.
  bool _staffDoor = false;

  @override
  void dispose() {
    _code.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _byCode() async {
    final lookUp = widget.byCode;
    if (lookUp == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final found = await lookUp(_code.text);
      if (!mounted) return;
      if (found == null) {
        setState(() {
          _busy = false;
          _error = widget.text.noSuchMerchant;
        });
        return;
      }
      widget.onBound(found);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _signIn() async {
    final t = widget.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final found = await widget.signIn(_email.text, _password.text);
      if (!mounted) return;
      // Straight in, with nothing to confirm: the credentials proved who they
      // are and their staff row says where they work, so there is no wrong
      // restaurant to land on.
      if (found != null) {
        widget.onBound(found);
        return;
      }
      setState(() => _error = t.wrongPassword);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error =
          error is StateError ? error.message : t.cannotReachRestaurant);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: PageWidth(
          maxWidth: 460,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
            children: [
              Center(
                child: Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(Brand.logo, style: TextStyle(fontSize: 30)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t.whichRestaurant,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(_staffDoor ? t.staffSetUpBlurb : t.ownerSignInBlurb,
                  textAlign: TextAlign.center, style: AppType.body),
              const SizedBox(height: 22),
              if (_staffDoor)
                TextField(
                  controller: _code,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: _busy ? null : (_) => _byCode(),
                  decoration: appInput(
                    label: t.merchantId,
                    hint: 'EZ-4K7Q2M',
                  ),
                )
              else ...[
                TextField(
                  controller: _email,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: appInput(label: t.emailAddress),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: _busy ? null : (_) => _signIn(),
                  decoration: appInput(label: t.password),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    _busy ? null : (_staffDoor ? _byCode : _signIn),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(_staffDoor ? t.findRestaurant : t.signIn),
              ),
              // The other door. Staff have a PIN and no password; an owner
              // setting up their own phone has both and no need for the ID.
              if (widget.byCode != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _staffDoor = !_staffDoor;
                            _error = null;
                          }),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: Text(
                      _staffDoor ? t.imTheOwner : t.imStaffWithAnId),
                ),
              ],
              // Neither an account nor a restaurant: somebody deciding whether
              // the product is any good. Turning them away at the door is a
              // strange way to sell anything.
              if (widget.onGuest != null) ...[
                const Divider(height: 34),
                Text(t.tryAsGuestBlurb,
                    textAlign: TextAlign.center, style: AppType.label),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : widget.onGuest,
                  icon: const Icon(Icons.explore_rounded, size: 19),
                  label: Text(t.tryAsGuest),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ],
              if (widget.current != null) ...[
                const SizedBox(height: 24),
                Text(
                  t.deviceSetUpFor(widget.current!.name),
                  textAlign: TextAlign.center,
                  style: AppType.label,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

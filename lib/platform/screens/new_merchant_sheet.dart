import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/email_address.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../platform_store.dart';

/// Signing up a restaurant.
///
/// Creates the restaurant and its first owner account in one call. Until this
/// existed it was a line of SQL pasted into the dashboard, which is a poor way
/// to onboard a paying customer.
Future<void> showNewMerchantSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _NewMerchantSheet(),
  );
}

class _NewMerchantSheet extends StatefulWidget {
  const _NewMerchantSheet();

  @override
  State<_NewMerchantSheet> createState() => _NewMerchantSheetState();
}

class _NewMerchantSheetState extends State<_NewMerchantSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _slugEdited = false;

  @override
  void initState() {
    super.initState();
    // Suggest a slug from the name until somebody types one themselves.
    _name.addListener(() {
      if (_slugEdited) return;
      final suggested = _name.text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      if (_slug.text != suggested) _slug.text = suggested;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create(PlatformStore store) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await store.createMerchant(
        slug: _slug.text,
        name: _name.text,
        adminEmail: _email.text,
        adminPassword: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, '${_name.text.trim()} created');
    } on StateError catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(context, error.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlatformStore>();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: sheetMaxHeight(context)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: PageWidth(
              maxWidth: 460,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'New merchant',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: appInput(label: 'Restaurant name'),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Give the restaurant a name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _slug,
                      autocorrect: false,
                      onChanged: (_) => _slugEdited = true,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[a-z0-9-]')),
                      ],
                      decoration: appInput(
                        label: 'Slug',
                        hint: 'appears in every table QR link',
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        // Matches the CHECK constraint on restaurants.slug, so
                        // a bad one is caught here rather than as a database
                        // error after the owner account has been created.
                        if (!RegExp(r'^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$')
                            .hasMatch(s)) {
                          return '3–40 characters: lowercase, digits, hyphens';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Permanent — it is printed into every QR code and the '
                      'database refuses to change it later.',
                      style: TextStyle(fontSize: 13, color: AppColors.inkFaint),
                    ),
                    const SizedBox(height: 16),
                    const SectionLabel("The owner's account"),
                    TextFormField(
                      controller: _email,
                      autocorrect: false,
                      keyboardType: TextInputType.emailAddress,
                      decoration: appInput(
                        label: 'Owner email',
                        hint: 'what they will sign in with',
                      ),
                      // The owner's own address, so they can be handed the app
                      // and sign in without being told a username somebody
                      // else invented for them.
                      validator: (v) => EmailAddress.isValid(v ?? '')
                          ? null
                          : 'That does not look like an email address',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: appInput(
                        label: 'Password',
                        hint: 'at least 8 characters',
                      ),
                      validator: (v) => (v ?? '').trim().length < 8
                          ? 'At least 8 characters'
                          : null,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Write this down before you submit — it is stored hashed '
                      'and cannot be read back. You can reset it later from '
                      'the database.',
                      style: TextStyle(fontSize: 13, color: AppColors.inkFaint),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : () => _create(store),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      child: Text(_busy ? 'Creating…' : 'Create merchant'),
                    ),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../platform_store.dart';

/// Sign-in for whoever runs the service.
///
/// Email and password, not a PIN pad: these are your own people on their own
/// laptops, not staff tapping a name on a shared tablet in a kitchen. There is
/// no list of accounts to pick from and no hint about who exists.
class PlatformSignInScreen extends StatefulWidget {
  const PlatformSignInScreen({super.key});

  @override
  State<PlatformSignInScreen> createState() => _PlatformSignInScreenState();
}

class _PlatformSignInScreenState extends State<PlatformSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(PlatformStore store) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await store.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure;
    });
    if (failure == null) unawaited(store.load());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlatformStore>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: PageWidth(
            maxWidth: 400,
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.hub_rounded,
                            size: 21, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EZ Order',
                                style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1)),
                            Text('Platform console', style: AppType.label),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _email,
                    autocorrect: false,
                    keyboardType: TextInputType.emailAddress,
                    decoration: appInput(label: 'Email'),
                    onSubmitted: (_) => _submit(store),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: appInput(label: 'Password'),
                    onSubmitted: (_) => _submit(store),
                  ),
                  SizedBox(
                    height: 26,
                    child: _error == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: _busy ? null : () => _submit(store),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(_busy ? 'Checking…' : 'Sign in'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Only accounts listed as platform administrators can get '
                    'in here. Membership is granted in the database, never '
                    'from an app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.inkFaint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

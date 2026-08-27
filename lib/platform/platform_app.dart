import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import 'platform_store.dart';
import 'screens/merchants_screen.dart';
import 'screens/platform_sign_in_screen.dart';

/// The operator console.
///
/// Same visual language as the restaurant app on purpose — it is the same
/// product seen from the other side, and there is no reason for the person
/// running it to learn a second set of conventions.
class PlatformApp extends StatelessWidget {
  const PlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${Brand.appTitle} — Platform',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler
                .clamp(minScaleFactor: 1.0, maxScaleFactor: Style.maxTextScale),
          ),
          child: child!,
        );
      },
      home: const _Gate(),
    );
  }
}

/// Signed in and on the list, or not in at all. There is no third state: the
/// console has nothing useful to show somebody who is neither.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlatformStore>();
    return store.isSignedIn
        ? const MerchantsScreen()
        : const PlatformSignInScreen();
  }
}

/// Shown while the console cannot reach the database at all.
class PlatformUnavailable extends StatelessWidget {
  const PlatformUnavailable({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${Brand.appTitle} — Platform',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: PageWidth(
            maxWidth: 440,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 52, color: AppColors.inkFaint),
                  const SizedBox(height: 16),
                  const Text(
                    'The console is not configured',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(message,
                      textAlign: TextAlign.center, style: AppType.body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

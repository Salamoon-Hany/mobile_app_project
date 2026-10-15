import '../l10n/app_language.dart';

import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/verification_service.dart';
import 'security_verification.dart';
import 'welcome.dart';

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AuthAppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SanadBrand(),
                  const SizedBox(height: 24),
                  const AppText(
                    'Your services. Your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const AppText(
                    'Log in to your account or create a new one. Sign in with email and password. Confirm your email with a verification link.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmailAuthScreen(
                            action: AccountAction.login,
                          ),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFd7ff00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(18),
                      ),
                      child: const AppText('Log in'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmailAuthScreen(
                            action: AccountAction.signup,
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(18),
                      ),
                      child: const AppText('Sign up'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const AppText(
                    'A verified account is required to access services.',
                    textAlign: TextAlign.center,
                  ),
                  if (!VerificationService.configured) ...[
                    const SizedBox(height: 16),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: AppText(
                          'Account verification is awaiting setup. Access stays locked until Firebase email verification is configured.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

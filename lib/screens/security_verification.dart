import '../l10n/app_language.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/marketplace_service.dart';
import '../services/verification_service.dart';
import 'auth_gate.dart';
import '../models/profile_completion.dart';
import '../services/phone_verification_service.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({
    super.key,
    this.action = AccountAction.login,
    this.service,
    this.onVerified,
    this.phoneService,
  });
  final AccountAction action;
  final VerificationService? service;
  final PhoneVerificationService? phoneService;
  final Future<void> Function()? onVerified;
  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _phone = TextEditingController();
  final _nationalId = TextEditingController();
  late final VerificationService _service;
  String _role = 'customer';
  bool _busy = false;
  bool _showPassword = false;
  bool _showConfirmation = false;
  bool _pending = false;
  bool _completed = false;
  String? _error;
  String? _notice;
  int _seconds = 0;
  Timer? _timer;
  bool get _signup => widget.action == AccountAction.signup;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? VerificationService();
    AccountService.authenticationInProgress = true;
  }

  void _cooldown() {
    _timer?.cancel();
    _seconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _seconds--);
      if (_seconds <= 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    await _service.sendVerification();
    if (!mounted) return;
    setState(() {
      _notice = 'Verification email sent. Check your inbox and spam folder.';
      _cooldown();
    });
  }

  Future<void> _finish() async {
    if (widget.onVerified != null) {
      await widget.onVerified!();
    } else {
      await AccountService.finish(
        widget.action,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
    }
    if (!mounted) return;
    _completed = true;
    AccountService.authenticationInProgress = false;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_signup) {
        await _service.signUp(_email.text, _password.text, _name.text);
        final uid = _service.currentUser?.uid;
        if (uid != null) {
          await Marketplace.rememberRole(
            uid,
            _role,
            name: _name.text.trim(),
            phone: _phone.text.trim().isEmpty
                ? ''
                : normalizePhone(_phone.text),
            nationalId: _role == 'worker'
                ? normalizeNationalId(_nationalId.text)
                : null,
          );
        }
      } else {
        await _service.logIn(_email.text, _password.text);
      }
      if (!mounted) {
        await _service.signOut();
        return;
      }
      _password.clear();
      _confirm.clear();
      if (_service.currentUser?.emailVerified == true) {
        await _finish();
      } else {
        // Keep the created identity if mail delivery fails: retry sending,
        // rather than creating the same account a second time.
        setState(() => _pending = true);
        await _send();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _pending = _service.currentUser != null;
          _error = VerificationService.message(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (await _service.refreshVerification()) {
        await _finish();
      } else if (mounted) {
        setState(
          () => _error =
              'Your email is not verified yet. Open the link in your email, then try again.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = VerificationService.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _send();
    } catch (error) {
      if (mounted) setState(() => _error = VerificationService.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await _service.resetPassword(_email.text);
      if (mounted) {
        setState(
          () => _notice =
              'If an account exists for this email, a password reset link has been sent. Check inbox and spam.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = VerificationService.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _anotherAccount() async {
    setState(() => _busy = true);
    try {
      await _service.signOut();
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _pending = false;
          _busy = false;
          _seconds = 0;
          _error = null;
          _notice = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = VerificationService.message(error);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _phone.dispose();
    _nationalId.dispose();
    // Cancellation cannot leave an unfinished session available to the gate.
    if (!_completed && _service.currentUser != null) {
      unawaited(_service.signOut().catchError((Object _) {}));
    }
    AccountService.authenticationInProgress = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: AuthAppBar(
        title: AppText(
          _pending
              ? 'Verify your email'
              : _signup
              ? 'Sign up'
              : 'Log in',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_service.available)
                      const AppText(
                        'Email verification is not set up yet. Services stay locked until Firebase is configured.',
                      ),
                    if (_pending) ...[
                      const Icon(Icons.mark_email_unread_outlined, size: 64),
                      const SizedBox(height: 20),
                      AppText(
                        'Open the verification link sent to ${_service.currentUser?.email ?? _email.text}. Then return here to continue.',
                        textAlign: TextAlign.center,
                      ),
                      if ((_service.currentUser?.displayName?.trim().length ??
                              0) <
                          2) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _name,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: tr('Full name'),
                          ),
                          validator: (v) =>
                              (v?.trim().length ?? 0) < 2 ||
                                  (v?.trim().length ?? 0) > 80
                              ? tr('Enter 2–80 characters.')
                              : null,
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _check,
                        child: const AppText('I verified my email'),
                      ),
                      TextButton(
                        onPressed: _busy || _seconds > 0 ? null : _resend,
                        child: AppText(
                          _seconds > 0
                              ? 'Resend in ${_seconds}s'
                              : 'Resend verification email',
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _anotherAccount,
                        child: const AppText('Use another account'),
                      ),
                    ] else ...[
                      if (_signup) ...[
                        const AppText('Account type'),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'customer',
                              label: AppText('Customer'),
                              icon: Icon(Icons.home_repair_service),
                            ),
                            ButtonSegment(
                              value: 'worker',
                              label: AppText('Worker'),
                              icon: Icon(Icons.handyman),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged: _busy
                              ? null
                              : (v) => setState(() => _role = v.first),
                        ),
                        const SizedBox(height: 16),
                      ],
                      AppText(
                        _signup
                            ? 'Email and password'
                            : 'Email or mobile number',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppText(
                        _signup
                            ? 'Create your account, then confirm your email using the link Firebase sends you.'
                            : 'Use your email, or the mobile number verified in Profile, with the same password.',
                      ),
                      const SizedBox(height: 20),
                      if (_signup) ...[
                        TextFormField(
                          controller: _name,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: tr('Full name'),
                          ),
                          validator: (v) =>
                              (v?.trim().length ?? 0) < 2 ||
                                  (v?.trim().length ?? 0) > 80
                              ? tr('Enter 2–80 characters.')
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: _signup
                            ? TextInputType.emailAddress
                            : TextInputType.text,
                        autofillHints: [
                          _signup
                              ? AutofillHints.email
                              : AutofillHints.username,
                        ],
                        decoration: InputDecoration(
                          labelText: tr(
                            _signup
                                ? 'Email address'
                                : 'Email or verified mobile number',
                          ),
                        ),
                        validator: (v) {
                          try {
                            if (_signup) {
                              normalizeEmail(v ?? '');
                            } else {
                              normalizeLoginIdentifier(v ?? '');
                            }
                            return null;
                          } on FormatException catch (e) {
                            return tr(e.message);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: !_showPassword,
                        autofillHints: [
                          _signup
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: tr('Password'),
                          suffixIcon: IconButton(
                            key: const Key('toggle-password'),
                            tooltip: tr(
                              _showPassword ? 'Hide password' : 'Show password',
                            ),
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                          helperText: _signup
                              ? tr('At least 8 characters')
                              : null,
                        ),
                        validator: (v) => (v?.length ?? 0) < (_signup ? 8 : 1)
                            ? (_signup
                                  ? tr('Use at least 8 characters.')
                                  : tr('Enter your password.'))
                            : null,
                      ),
                      if (_signup) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirm,
                          enabled: !_busy,
                          obscureText: !_showConfirmation,
                          decoration: InputDecoration(
                            labelText: tr('Confirm password'),
                            suffixIcon: IconButton(
                              key: const Key('toggle-confirm-password'),
                              tooltip: tr(
                                _showConfirmation
                                    ? 'Hide password'
                                    : 'Show password',
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _showConfirmation =
                                          !_showConfirmation,
                                    ),
                              icon: Icon(
                                _showConfirmation
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (v) => v != _password.text
                              ? tr('Passwords do not match.')
                              : null,
                        ),
                      ],
                      if (_signup) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('signup-phone'),
                          controller: _phone,
                          enabled: !_busy,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: tr('Mobile number (optional)'),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            try {
                              normalizePhone(v);
                              return null;
                            } on FormatException catch (e) {
                              return tr(e.message);
                            }
                          },
                        ),
                        if (_role == 'worker') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('signup-national-id'),
                            controller: _nationalId,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: tr('National ID (optional)'),
                              helperText: tr(
                                'You can add this later in My Profile.',
                              ),
                              helperMaxLines: 3,
                            ),
                            validator: (v) =>
                                trNullable(nationalIdError(v ?? '')),
                          ),
                          const AppText(
                            'Only the last 4 digits are saved. Format checked; identity not verified.',
                            style: TextStyle(fontSize: 12),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(_nationalId.clear),
                            child: const AppText('Not now'),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy || !_service.available
                            ? null
                            : _submit,
                        child: AppText(_signup ? 'Create account' : 'Log in'),
                      ),
                      if (!_signup)
                        TextButton(
                          onPressed: _busy || !_service.available
                              ? null
                              : _reset,
                          child: const AppText('Forgot password?'),
                        ),
                    ],
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: AppText(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_notice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: AppText(_notice!),
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

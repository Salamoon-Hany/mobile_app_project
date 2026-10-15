import '../l10n/app_language.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/phone_verification_service.dart';

enum PhoneStepResult { linked, skipped }

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key, this.service});
  final PhoneVerificationService? service;
  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  late final PhoneVerificationService _service;
  bool _busy = false;
  bool _sent = false;
  String? _error;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PhoneVerificationService();
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
      if (_seconds == 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    try {
      final phone = normalizePhone(_phone.text);
      setState(() {
        _phone.text = phone;
        _busy = true;
        _error = null;
        _code.clear();
        _sent = false;
        _cooldown();
      });
      final linked = await _service.send(phone);
      if (!mounted) return;
      if (linked) {
        _done(PhoneStepResult.linked);
      } else {
        setState(() => _sent = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = PhoneVerificationService.message(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.confirm(_code.text);
      if (mounted) _done(PhoneStepResult.linked);
    } catch (error) {
      if (mounted) {
        setState(() => _error = PhoneVerificationService.message(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _done(PhoneStepResult result) {
    setState(() => _busy = false);
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _service.cancel();
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const AppText('Verify mobile number')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.phonelink_lock,
                size: 56,
                color: Color(0xFF00ACC1),
              ),
              const SizedBox(height: 16),
              const AppText(
                'Add your mobile',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const AppText(
                'Your email is verified. Add a mobile number to the same account by confirming the code sent by SMS. This step is optional.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phone,
                readOnly: _sent || _busy,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(
                  labelText: tr('Mobile number'),
                  hintText: tr('01012345678 or +201012345678'),
                  border: OutlineInputBorder(),
                ),
              ),
              if (_sent) ...[
                const SizedBox(height: 16),
                AppText(
                  'SMS requested for ${_phone.text}. Enter the code when it arrives.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: tr('SMS code'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _confirm,
                  child: const AppText('Verify mobile'),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: AppText(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    semanticsLabel: 'Error: $_error',
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _busy || _seconds > 0 ? null : _send,
                child: AppText(
                  _seconds > 0
                      ? 'Retry SMS in ${_seconds}s'
                      : _sent
                      ? 'Resend SMS'
                      : 'Send SMS code',
                ),
              ),
              if (_sent)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _service.cancel();
                          setState(() {
                            _sent = false;
                            _code.clear();
                            _error = null;
                          });
                        },
                  child: const AppText('Change number'),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              TextButton(
                onPressed: _busy ? null : () => _done(PhoneStepResult.skipped),
                child: const AppText('Continue with email only'),
              ),
              const SizedBox(height: 12),
              const AppText(
                'By sending a code, you agree that Google may store and use your number for spam and abuse prevention. Firebase SMS limits and charges apply.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

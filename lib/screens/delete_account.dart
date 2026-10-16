import '../services/secure_api.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_language.dart';
import '../services/account_service.dart';
import '../services/local_account_store.dart';
import 'dashboard.dart';
import 'auth_gate.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _busy = false, _confirmed = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy || !_confirmed || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    AccountService.deletionInProgress = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw const FormatException('Sign in again to continue.');
      }
      final uid = user.uid;
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: _password.text,
        ),
      );
      _password.clear();
      final token = await user.getIdToken(true);
      const base = String.fromEnvironment('MARKETPLACE_API_URL');
      final response = await http
          .post(
            secureEndpoint(
              Uri.parse(
                '${base.isEmpty ? Uri.base.origin : base}/api/marketplace/account/delete',
              ),
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'confirm': true}),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        final code = (jsonDecode(response.body) as Map)['error'];
        throw FormatException(
          code == 'DELETE_ACTIVE_WORK'
              ? 'Finish or cancel active orders and pending withdrawals before deleting your account.'
              : code == 'REAUTH_REQUIRED'
              ? 'Enter your password again to continue.'
              : 'Account deletion is pending. Retry deleting your account.',
        );
      }
      AppState.clearAccount();
      await LocalAccountStore.erase(uid);
      await FirebaseAuth.instance.signOut();
      AccountService.deletionInProgress = false;
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : e is FirebaseAuthException
              ? 'Check your password and connection, then retry.'
              : 'Could not delete your account. Check your connection and retry.',
        );
      }
    } finally {
      AccountService.deletionInProgress = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const AppText('Delete Account')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_remove_outlined,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 20),
                  const AppText(
                    'Delete your account permanently?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const AppText(
                    'Your profile, photo, contact details and feedback will be removed. Anonymous transaction records may remain in order histories. This cannot be undone.',
                  ),
                  const SizedBox(height: 12),
                  const AppText(
                    'Any remaining balance will be lost. Finish or cancel active orders and pending withdrawals first.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: tr('Password'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _confirmed,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _confirmed = v == true),
                    title: const AppText(
                      'I understand and want to delete my account.',
                    ),
                  ),
                  if (_error != null)
                    AppText(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _busy || !_confirmed || _password.text.isEmpty
                        ? null
                        : _delete,
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppText('Delete Account'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const AppText('Back'),
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

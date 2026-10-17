import '../l10n/app_language.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/account_service.dart';
import '../services/verification_service.dart';
import 'auth_landing.dart';
import 'dashboard.dart';
import 'worker_home.dart';
import 'delete_account.dart';
import 'admin_dashboard.dart';
import '../services/marketplace_service.dart';

// This gate remains under all protected routes and removes them on sign-out.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _auth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  User? _user;
  bool _loading = true;
  bool _registered = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (!VerificationService.configured) {
      AppState.clearAccount();
      _loading = false;
      return;
    }
    _auth = FirebaseAuth.instance.userChanges().listen(
      _loadUser,
      onError: (_) => _fail(),
    );
  }

  void _closeProtectedRoutes() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  void _fail([String? message]) {
    if (!mounted) return;
    _closeProtectedRoutes();
    AppState.clearAccount();
    setState(() {
      _registered = false;
      _loading = false;
      _error =
          message ??
          'Could not load your account. Check your connection and retry.';
    });
  }

  Future<void> _loadUser(User? user) async {
    if (AccountService.deletionInProgress) return;
    final generation = ++_generation;
    await _profile?.cancel();
    if (!mounted || generation != _generation) return;
    final hadAccount = _registered;
    _user = user;
    if (!hasVerifiedContact(user) || AccountService.authenticationInProgress) {
      AppState.clearAccount();
      if (hadAccount) _closeProtectedRoutes();
      setState(() {
        _registered = false;
        _loading = false;
        _error = null;
      });
      return;
    }
    if (AccountService.activeUid != user!.uid) {
      if (hadAccount) _closeProtectedRoutes();
      AppState.clearAccount();
    }
    setState(() {
      _registered = false;
      _loading = true;
      _error = null;
    });
    if (Marketplace.enabled) {
      try {
        final admin = await Marketplace.shared.identify(user);
        if (!mounted || generation != _generation) return;
        if (admin) {
          setState(() {
            _registered = true;
            _loading = false;
          });
          return;
        }
      } catch (e) {
        if (generation == _generation) {
          _fail(e is FormatException ? e.message : null);
        }
        return;
      }
    }
    _profile = AccountService.profile(user.uid).snapshots().listen(
      (snapshot) async {
        if (!mounted ||
            generation != _generation ||
            AccountService.deletionInProgress) {
          return;
        }
        final data = snapshot.data();
        final registered = data != null && data['uid'] == user.uid;
        if (registered) {
          AppState.loadAccount(user, data);
          if (Marketplace.enabled) {
            try {
              await Marketplace.shared.attach(user);
            } catch (e) {
              if (generation == _generation) {
                _fail(e is FormatException ? e.message : null);
              }
              return;
            }
            if (!mounted || generation != _generation) return;
          }
        } else {
          if (_registered) _closeProtectedRoutes();
          AppState.clearAccount();
        }
        setState(() {
          _registered = registered;
          _loading = false;
        });
      },
      onError: (_) {
        if (generation == _generation) _fail();
      },
    );
  }

  @override
  void dispose() {
    _generation++;
    _auth?.cancel();
    _profile?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(_error!, textAlign: TextAlign.center),
                if (_error ==
                    'Account deletion is pending. Retry deleting your account.')
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeleteAccountScreen(),
                      ),
                    ),
                    child: const AppText('Delete Account'),
                  ),
                FilledButton(
                  onPressed: () => _loadUser(_user),
                  child: const AppText('Retry'),
                ),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const AppText('Log out'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _registered ? const AccountHome() : const AuthLandingScreen();
  }
}

class AccountHome extends StatelessWidget {
  const AccountHome({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Marketplace.shared,
    builder: (_, __) => Marketplace.shared.isAdmin
        ? const AdminScreen()
        : Marketplace.shared.isWorker
        ? const WorkerHome()
        : const MyHomePage(),
  );
}

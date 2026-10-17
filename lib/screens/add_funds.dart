import '../l10n/app_language.dart';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../services/checkout_link.dart';
import '../services/marketplace_service.dart';
import 'worker_wallet.dart';

class AddFundsScreen extends StatefulWidget {
  const AddFundsScreen({super.key, this.service});
  final WalletService? service;
  @override
  State<AddFundsScreen> createState() => _AddFundsScreenState();
}

class _AddFundsScreenState extends State<AddFundsScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late final WalletService _service;
  DepositMethod? _method;
  DepositQuote? _quote;
  DepositSession? _session;
  DepositReceipt? _receipt;
  String? _error;
  String? _notice;
  String? _requestId;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? WalletService();
    if (!_service.isDemo) {
      _busy = true;
      _loadBalance();
    }
  }

  Future<void> _loadBalance() async {
    try {
      await _service.refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load your balance. Check the payment service and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  void _edited(String _) {
    setState(() {
      _error = null;
      _notice = null;
      _requestId = null;
      try {
        _quote = DepositQuote.parse(_amount.text);
      } catch (_) {
        _quote = null;
      }
    });
  }

  Future<void> _deposit() async {
    if (_busy || _session != null) return;
    if (!_form.currentState!.validate()) return;
    final quote = DepositQuote.parse(_amount.text);
    if (_service.isDemo) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('Confirm deposit'),
          content: AppText(
            '${tr('Wallet credit')}: ${egp(quote.amountPiasters)}\n${tr('Payment method')}: ${tr(_method!.label)}\n${tr('Service fee (2%)')}: ${egp(quote.feePiasters)}\n${tr('Total to pay')}: ${egp(quote.totalPiasters)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Confirm deposit'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    _requestId ??= List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    try {
      final session = await _service.begin(quote, _method!, _requestId!);
      if (mounted) {
        setState(() {
          _quote = quote;
          _session = session;
          _receipt = session.receipt;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Could not start the deposit. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await _service.check(_session!, _quote!, _method!);
      if (!mounted) return;
      setState(() {
        if (result == null || result.receipt == null) {
          if (result != null) _session = result;
          _notice = _session!.status == 'RECONCILIATION_REQUIRED'
              ? 'The payment provider did not confirm checkout creation. Your balance has not changed. Keep this reference and contact support before starting another deposit.'
              : 'Payment is still pending. Complete payment first, then check again.';
        } else {
          _session = result;
          _receipt = result.receipt;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Could not check payment status. Retry before starting another deposit.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _summaryRow(String label, int amount, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(label),
        AppText(
          egp(amount),
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const AppText('Add funds')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFF9FB700),
                size: 48,
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _service.state,
                builder: (_, _) => AppText(
                  'Balance: ${egp(_service.state.balancePiasters)}',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (Marketplace.enabled)
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WorkerWalletScreen(),
                          ),
                        ),
                  icon: const Icon(Icons.north_east),
                  label: const AppText('Withdraw funds'),
                ),
              const SizedBox(height: 20),
              if (_receipt == null && _session == null)
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      DropdownButtonFormField<DepositMethod>(
                        initialValue: _method,
                        decoration: InputDecoration(
                          labelText: tr('Payment method'),
                          border: OutlineInputBorder(),
                        ),
                        items: DepositMethod.values
                            .map(
                              (method) => DropdownMenuItem(
                                value: method,
                                child: AppText(method.label),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                _method = value;
                                _requestId = null;
                                _error = null;
                              }),
                        validator: (value) => value == null
                            ? tr('Choose a payment method.')
                            : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        key: const Key('deposit-amount'),
                        controller: _amount,
                        enabled: !_busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: _edited,
                        decoration: InputDecoration(
                          labelText: tr('Amount'),
                          hintText: tr('minimum 10 pounds'),
                          suffixText: tr('EGP'),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          try {
                            DepositQuote.parse(value ?? '');
                            return null;
                          } on FormatException catch (error) {
                            return tr(error.message);
                          }
                        },
                      ),
                      const SizedBox(height: 18),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _summaryRow(
                                'Wallet credit',
                                _quote?.amountPiasters ?? 0,
                              ),
                              _summaryRow(
                                'Service fee (2%)',
                                _quote?.feePiasters ?? 0,
                              ),
                              const Divider(),
                              _summaryRow(
                                'Total to pay',
                                _quote?.totalPiasters ?? 0,
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _deposit,
                          child: AppText(
                            _service.isDemo
                                ? 'Add funds'
                                : 'Continue to secure payment',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_session != null && _receipt == null) ...[
                SelectableText(tr('Reference: ${_session!.id}')),
                if (_session!.status == 'RECONCILIATION_REQUIRED')
                  const AppText(
                    'Checkout creation is uncertain. Do not start another deposit. Keep this reference for support and check payment status.',
                  ),
                const AppText(
                  'Complete payment in the secure checkout. Your balance updates after payment is confirmed. Fawry reference creation alone does not add funds.',
                ),
                const SizedBox(height: 16),
                if (_session!.checkoutUrl != null) ...[
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => openCheckoutLink(_session!.checkoutUrl!),
                    child: const AppText('Open secure checkout'),
                  ),
                  TextButton(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: _session!.checkoutUrl!),
                    ),
                    child: const AppText('Copy checkout link'),
                  ),
                ],
                OutlinedButton(
                  onPressed: _busy ? null : _check,
                  child: const AppText('Check payment status'),
                ),
              ],
              if (_receipt != null) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 44),
                const SizedBox(height: 12),
                AppText(
                  _receipt!.demo ? 'Deposit added' : 'Deposit confirmed',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                AppText(
                  '${egp(_receipt!.quote.amountPiasters)} added to your balance.',
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(_receipt!.text),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const AppText('Done'),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: AppText(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: AppText(_notice!),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

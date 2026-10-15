import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../widgets/sanad_ui.dart';
import '../models/wallet.dart';
import '../models/phone_number.dart';
import '../services/marketplace_service.dart';

class WorkerWalletScreen extends StatefulWidget {
  const WorkerWalletScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<WorkerWalletScreen> createState() => _WorkerWalletScreenState();
}

class _WorkerWalletScreenState extends State<WorkerWalletScreen> {
  final _amount = TextEditingController(),
      _destination = TextEditingController();
  String _method = 'mobile_wallet';
  String? _error, _notice;
  bool _busy = false;
  String? _requestId;
  String? _payload;
  @override
  void dispose() {
    _amount.dispose();
    _destination.dispose();
    super.dispose();
  }

  int? get _gross {
    try {
      return DepositQuote.parse(_amount.text).amountPiasters;
    } on FormatException {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final amount = _gross;
    if (amount == null || amount < 1000) {
      setState(() => _error = 'Enter an amount of at least EGP 10.');
      return;
    }
    String destination = _destination.text.trim();
    try {
      if (_method == 'mobile_wallet')
        destination = normalizePhone(destination);
      else if (!RegExp(
        r'^[A-Za-z0-9._-]{3,80}@instapay$',
      ).hasMatch(destination))
        throw const FormatException(
          'Enter a valid InstaPay address ending in @instapay.',
        );
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() => _busy = true);
    final fee = withdrawalFee(amount);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const AppText('Confirm withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${tr('Amount')}: ${egp(amount)}'),
            Text('${tr('Withdrawal fee (5%)')}: ${egp(fee)}'),
            Text('${tr('You receive')}: ${egp(amount - fee)}'),
            Text(destination),
            const SizedBox(height: 12),
            const AppText(
              'The amount will be reserved while your withdrawal is pending.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const AppText('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const AppText('Confirm'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) {
      setState(() => _busy = false);
      return;
    }
    final payload = '$amount|$_method|$destination';
    if (payload != _payload) {
      _requestId = Marketplace.id();
      _payload = payload;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await Marketplace.shared.withdraw({
        'requestId': _requestId,
        'amount': amount,
        'method': _method,
        'destination': destination,
      });
      if (mounted)
        setState(() {
          _notice = 'Withdrawal request submitted';
          _amount.clear();
          _destination.clear();
          _requestId = null;
          _payload = null;
        });
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'Could not submit your withdrawal. Please retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const AppText('Cancel withdrawal?'),
        content: const AppText(
          'The full reserved amount, including the fee, will return to your balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const AppText('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const AppText('Confirm'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) {
      setState(() => _busy = false);
      return;
    }
    setState(() => _busy = true);
    try {
      await Marketplace.shared.cancelWithdrawal(id);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'Could not sync your account. Check your connection and retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: SanadUi.canvas(context),
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          title: const AppText('Wallet'),
        ),
        body: AnimatedBuilder(
          animation: Marketplace.shared,
          builder: (c, _) {
            final m = Marketplace.shared,
                a = _gross ?? 0,
                fee = withdrawalFee(a);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    SanadPanel(
                      padding: EdgeInsets.zero,
                      color: SanadUi.lime,
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(color: SanadUi.ink),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText('Available earnings'),
                              Text(
                                egp(m.account?['balance'] as int? ?? 0),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const AppText(
                      'Withdraw',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('withdraw-amount'),
                      controller: _amount,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: tr('Amount (EGP)'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _method,
                      decoration: InputDecoration(
                        labelText: tr('Withdrawal method'),
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'mobile_wallet',
                          child: AppText('Mobile wallet'),
                        ),
                        DropdownMenuItem(
                          value: 'instapay',
                          child: Text('InstaPay'),
                        ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _method = v!),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('withdraw-destination'),
                      controller: _destination,
                      enabled: !_busy,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: tr(
                          _method == 'mobile_wallet'
                              ? 'Wallet mobile number'
                              : 'InstaPay address',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SanadPanel(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: AppText('Withdrawal fee (5%)'),
                              ),
                              Text(egp(fee)),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Expanded(
                                child: AppText(
                                  'You receive',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                egp(a - fee),
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      AppText(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (_notice != null) AppText(_notice!),
                    if (m.error != null) AppText(m.error!),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const AppText('Request withdrawal'),
                    ),

                    const SizedBox(height: 28),
                    const AppText(
                      'Earnings history',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (!m.assignedOrders.any(
                      (o) => o['status'] == 'completed',
                    ))
                      const SanadPanel(
                        child: AppText('Your completed jobs will appear here.'),
                      ),
                    for (final o in m.assignedOrders.where(
                      (o) => o['status'] == 'completed',
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SanadPanel(
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFE5FAC3),
                                child: Icon(
                                  Icons.arrow_downward,
                                  color: Color(0xFF187B34),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const AppText(
                                      'Completed job',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      o['customer_name'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: SanadUi.muted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '+' + egp(o['amount'] as int),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF187B34),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                    const AppText(
                      'Withdrawal history',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (m.withdrawals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: AppText('No withdrawals yet.'),
                      ),
                    for (final w in m.withdrawals)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      egp(w['amount'] as int),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SanadStatus(w['status'] as String),
                                ],
                              ),
                              Text(
                                '${tr('Withdrawal fee (5%)')}: ${egp(w['fee'] as int)}',
                              ),
                              Text(
                                '${tr('You receive')}: ${egp(w['net'] as int)}',
                              ),
                              Text(w['destination'] as String),
                              if (w['review_state'] != null)
                                AppText(w['review_state'] as String),
                              if ((w['review_note'] as String? ?? '')
                                  .isNotEmpty)
                                Text(w['review_note'] as String),
                              Text(
                                DateTime.fromMillisecondsSinceEpoch(
                                  w['created_at'] as int,
                                ).toLocal().toString().split('.').first,
                              ),
                              if (w['status'] == 'pending')
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _cancel(w['id'] as String),
                                  child: const AppText('Cancel withdrawal'),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

int withdrawalFee(int amount) => (amount * 5 + 50) ~/ 100;

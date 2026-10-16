import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../models/wallet.dart';
import '../services/marketplace_service.dart';
import '../widgets/sanad_ui.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminState();
}

class _AdminState extends State<AdminScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false, _loading = false, _demo = true;
  static const _tabs = [
    'Overview',
    'Platform wallet',
    'Applications',
    'Withdrawals',
    'Orders',
    'Accounts',
    'Complaints',
    'Activity log',
  ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !Marketplace.shared.isAdmin) return;
    _loading = true;
    try {
      final d = await Marketplace.shared.request('admin');
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      _loading = false;
    }
  }

  String _message(Object e) => e is FormatException
      ? e.message
      : 'Could not load administration. Please retry.';
  String _date(dynamic v) => v is num && v > 0
      ? DateTime.fromMillisecondsSinceEpoch(
          v.toInt(),
        ).toLocal().toString().substring(0, 16)
      : tr('Not recorded');
  int _value(Map m, String key) => (m[key] as num?)?.toInt() ?? 0;
  List<Map<String, dynamic>> _rows(String key) => [
    for (final r in _data?[key] as List? ?? [])
      Map<String, dynamic>.from(r as Map),
  ];
  Future<void> _decision(
    String kind,
    Map<String, dynamic> row,
    String action,
  ) async {
    if (_busy) return;
    final input = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: AppText(action == 'paid' ? 'Complete demo payout?' : action),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action == 'paid')
              const AppText(
                'This completes a demo withdrawal. No real money is transferred.',
              ),
            TextField(
              controller: input,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: tr('Support note')),
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
    final note = input.text;
    input.dispose();
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final d = await Marketplace.shared.request(
        'admin/decision',
        body: {
          'kind': kind,
          'id': kind == 'application'
              ? row['uid']
              : kind == 'withdrawal'
              ? row['request_id']
              : row['id'],
          'uid': row['uid'],
          'decision': action,
          'note': note,
        },
      );
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
      await Marketplace.shared.refresh();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _stat(String title, String value, {String? note}) => SanadPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(title, style: TextStyle(color: SanadUi.muted(context))),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        if (note != null)
          AppText(
            note,
            style: TextStyle(fontSize: 12, color: SanadUi.muted(context)),
          ),
      ],
    ),
  );
  Widget _grid(List<Widget> cards) => LayoutBuilder(
    builder: (c, b) {
      final columns = b.maxWidth < 600
          ? 2
          : b.maxWidth < 900
          ? 3
          : 4;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final card in cards)
            SizedBox(
              width: (b.maxWidth - (columns - 1) * 12) / columns,
              child: card,
            ),
        ],
      );
    },
  );
  Widget _list(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(20), children: children);
  Widget _panel(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: SanadPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
  Widget _heading(String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: AppText(
      value,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
    ),
  );
  Widget _overview() {
    final summary = Map<String, dynamic>.from(_data?['summary'] as Map? ?? {}),
        jobs = Map<String, dynamic>.from(_data?['jobs'] as Map? ?? {}),
        p = Map<String, dynamic>.from(_data?['platform'] as Map? ?? {});
    return _list([
      _heading('Administration overview'),
      _grid([
        _stat('Total accounts', '${_value(summary, 'accounts')}'),
        _stat('Customers', '${_value(summary, 'customers')}'),
        _stat('Workers', '${_value(summary, 'workers')}'),
        _stat(
          'Registered this month',
          '${_value(summary, 'registeredThisMonth')}',
        ),
        _stat(
          'Active customers (30 days)',
          '${_value(summary, 'activeCustomers')}',
        ),
        _stat(
          'Active workers (30 days)',
          '${_value(summary, 'activeWorkers')}',
        ),
        _stat('Available workers', '${_value(summary, 'availableWorkers')}'),
        _stat(
          'Pending applications',
          '${_value(summary, 'pendingApplications')}',
        ),
        _stat('Total jobs', '${_value(jobs, 'total')}'),
        _stat('Pending jobs', '${_value(jobs, 'pending')}'),
        _stat('Jobs in progress', '${_value(jobs, 'accepted')}'),
        _stat('Completed jobs', '${_value(jobs, 'completed')}'),
        _stat('Completed this month', '${_value(jobs, 'completedThisMonth')}'),
        _stat(
          'Pending withdrawals',
          '${_value(summary, 'pendingWithdrawals')}',
        ),
        _stat('Platform balance', egp(_value(p, 'balance'))),
        _stat('Demo platform balance', egp(_value(p, 'demoBalance'))),
      ]),
      _heading('Monthly registrations'),
      for (final r in _rows('registrations'))
        ListTile(
          title: Text(r['month'] as String),
          trailing: Text('${r['total']}'),
        ),
      const AppText(
        'Counts cover accounts registered in SANAD. Activity means a successful authenticated visit in the last 30 days.',
      ),
    ]);
  }

  Widget _wallet() {
    final p = Map<String, dynamic>.from(_data?['platform'] as Map? ?? {});
    final ledger = _rows(
      'ledger',
    ).where((r) => r['mode'] == (_demo ? 'demo' : 'live')).toList();
    return _list([
      _heading('Platform wallet'),
      _grid([
        _stat('Platform balance', egp(_value(p, 'balance'))),
        _stat('Demo platform balance', egp(_value(p, 'demoBalance'))),
        _stat('Earnings this month', egp(_value(p, 'monthlyEarnings'))),
        _stat(
          'Demo earnings this month',
          egp(_value(p, 'monthlyDemoEarnings')),
        ),
      ]),
      const SizedBox(height: 16),
      const AppText(
        'Demo earnings are accounting examples and cannot be withdrawn as real money.',
      ),
      const SizedBox(height: 10),
      AppText(
        '${tr('Fees awaiting settlement')}: ${egp(_value(p, 'pendingFees'))}',
      ),
      const AppText(
        'Pending and cancelled withdrawals are not included in earnings.',
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        children: [
          ChoiceChip(
            label: const AppText('Demo'),
            selected: _demo,
            onSelected: (_) => setState(() => _demo = true),
          ),
          ChoiceChip(
            label: const AppText('Real payments'),
            selected: !_demo,
            onSelected: (_) => setState(() => _demo = false),
          ),
        ],
      ),
      _heading('Fee transactions'),
      if (ledger.isEmpty) const AppText('No fee transactions yet.'),
      for (final r in ledger)
        _panel([
          Row(
            children: [
              Expanded(
                child: AppText(
                  r['source_type'] == 'deposit'
                      ? 'Customer deposit'
                      : r['role'] == 'worker'
                      ? 'Worker withdrawal'
                      : 'Customer withdrawal',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '+${egp(r['fee'] as int)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF187B34),
                ),
              ),
            ],
          ),
          Text(r['name'] as String),
          Text('${tr('Amount')}: ${egp(r['amount'] as int)}'),
          SelectableText('${tr('Reference')}: ${r['request_id']}'),
          Text(_date(r['created_at'])),
        ]),
      const AppText(
        'Showing the latest 100 transactions. Balances include the full ledger.',
      ),
    ]);
  }

  Widget _applications() => _list([
    _heading('Worker applications'),
    if (_rows('applications').isEmpty) const AppText('Nothing to review yet'),
    for (final r in _rows('applications'))
      _panel([
        Text(
          r['full_name'] as String,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(r['email'] as String),
        Text(r['phone'] as String),
        Text(r['work_types'] as String),
        AppText(r['status'] as String),
        if (r['status'] == 'pending')
          Wrap(
            spacing: 12,
            children: [
              for (final a in ['approved', 'rejected'])
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _decision('application', r, a),
                  child: AppText(a),
                ),
            ],
          ),
      ]),
  ]);
  Widget _withdrawals() => _list([
    _heading('Withdrawal requests'),
    const AppText('Review reserves the request; it does not send money.'),
    if (_rows('withdrawals').isEmpty) const AppText('Nothing to review yet'),
    for (final r in _rows('withdrawals'))
      _panel([
        Text(
          r['name'] as String,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        AppText(r['role'] == 'worker' ? 'Worker' : 'Customer'),
        Text('${tr('Amount')}: ${egp(r['amount'] as int)}'),
        Text(
          '${tr('Service fee')}: ${egp(r['fee'] as int)} (${(r['fee_bps'] as int) ~/ 100}%)',
        ),
        Text('${tr('You receive')}: ${egp(r['net'] as int)}'),
        SelectableText(r['destination'] as String),
        AppText(r['mode'] == 'demo' ? 'Demo' : 'Real payments'),
        AppText(r['status'] as String),
        AppText(r['review_state'] as String),
        if ((r['note'] as String).isNotEmpty) Text(r['note'] as String),
        if (r['status'] == 'pending')
          Wrap(
            spacing: 8,
            children: [
              if (r['review_state'] == 'pending')
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _decision('withdrawal', r, 'reviewed'),
                  child: const AppText('Mark reviewed'),
                ),
              if (r['mode'] == 'demo')
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _decision('withdrawal', r, 'paid'),
                  child: const AppText('Complete demo payout'),
                ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _decision('withdrawal', r, 'rejected'),
                child: const AppText('Reject & refund'),
              ),
            ],
          ),
      ]),
  ]);
  Widget _orders() => _list([
    _heading('Latest orders'),
    for (final r in _rows('orders'))
      _panel([
        Text(
          '${r['customer_name']} → ${r['worker_name']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(egp(r['amount'] as int)),
        AppText(r['status'] as String),
        SelectableText(r['id'] as String),
        Text(_date(r['created_at'])),
      ]),
    const AppText('Showing the latest 100 records.'),
  ]);
  Widget _accounts() => _list([
    _heading('Latest accounts'),
    for (final r in _rows('accounts'))
      _panel([
        Text(
          r['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        SelectableText(r['email'] as String),
        AppText(r['role'] == 'worker' ? 'Worker' : 'Customer'),
        Text('${tr('Balance')}: ${egp(r['balance'] as int)}'),
        Text(
          '${tr('Registered')}: ${_date(r['auth_created_at'] ?? r['created_at'])}',
        ),
        Text('${tr('Last active')}: ${_date(r['last_seen_at'])}'),
      ]),
    const AppText('Showing the latest 100 records.'),
  ]);
  Future<void> _photo(String id) async {
    try {
      final data = await Marketplace.shared.request(
        'admin/photo',
        body: {'id': id},
      );
      final bytes = Marketplace.photoBytes(data['photo'] as String?);
      if (!mounted || bytes == null) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          content: Image.memory(bytes),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const AppText('Back'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Widget _complaints() => _list([
    _heading('Complaints'),
    if (_rows('complaints').isEmpty) const AppText('Nothing to review yet'),
    for (final r in _rows('complaints'))
      _panel([
        AppText(
          r['reason'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(r['body'] as String),
        AppText(r['status'] as String),
        Text(r['reply'] as String),
        if (r['has_photo'] == 1)
          TextButton(
            onPressed: () => _photo(r['id'] as String),
            child: const AppText('View Picture'),
          ),
        if (r['status'] == 'open')
          FilledButton(
            onPressed: _busy
                ? null
                : () => _decision('complaint', r, 'resolved'),
            child: const AppText('Reply & resolve'),
          ),
      ]),
  ]);
  Widget _audit() => _list([
    _heading('Activity log'),
    for (final r in _rows('audit'))
      ListTile(
        title: AppText(r['decision'] as String),
        subtitle: Text(
          '${r['kind']} • ${_date(r['created_at'])}\n${r['note']}',
        ),
      ),
  ]);
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    if (!Marketplace.shared.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const AppText('Admin panel')),
        body: const Center(child: AppText('Access denied')),
      );
    }
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('Admin panel'),
          actions: [
            IconButton(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: tr('Refresh'),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final label in _tabs) Tab(child: AppText(label))],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(child: AppText(_error!)),
                        TextButton(
                          onPressed: _load,
                          child: const AppText('Retry'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _data == null
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          children: [
                            _overview(),
                            _wallet(),
                            _applications(),
                            _withdrawals(),
                            _orders(),
                            _accounts(),
                            _complaints(),
                            _audit(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

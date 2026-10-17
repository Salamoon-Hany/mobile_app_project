import 'worker_wallet.dart';
import '../widgets/notification_badge.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_language.dart';
import '../widgets/sanad_ui.dart';
import '../models/wallet.dart';
import '../services/marketplace_service.dart';
import '../services/browser_alerts.dart' as alerts;
import 'admin_dashboard.dart';
import 'become_worker.dart';
export 'admin_dashboard.dart' show AdminScreen;

String friendlyError(Object e) => e is FormatException
    ? e.message
    : 'Could not sync your account. Check your connection and retry.';
String localTime(dynamic n) => n is num && n > 0
    ? DateTime.fromMillisecondsSinceEpoch(
        n.toInt(),
      ).toLocal().toString().substring(0, 16)
    : tr('As soon as possible');
Future<String?> pickServicePhoto() async {
  final f = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 700,
    maxHeight: 700,
    imageQuality: 65,
  );
  if (f == null) return null;
  final b = await f.readAsBytes();
  if (b.length > 220000) {
    throw const FormatException('Choose a smaller photo (up to 200 KB).');
  }
  return Marketplace.photoData(b);
}

Future<void> showServicePhoto(
  BuildContext context,
  String kind,
  String id, {
  bool admin = false,
}) async {
  try {
    final r = await Marketplace.shared.request(
      admin ? 'admin/photo' : 'attachment',
      body: admin ? {'id': id} : {'kind': kind, 'id': id},
    );
    final b = Marketplace.photoBytes(r['photo'] as String?);
    if (!context.mounted || b == null) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        content: Image.memory(b),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const AppText('Back'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(friendlyError(e))));
    }
  }
}

class ServiceTools extends StatelessWidget {
  const ServiceTools({super.key});
  void open(BuildContext c, Widget w) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => w));
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (Marketplace.shared.workerApplicationRequested &&
          Marketplace.shared.workerApplication == null)
        ListTile(
          leading: const Icon(Icons.assignment_ind_outlined),
          title: const AppText('Complete worker application'),
          subtitle: const AppText('Admin approval is required before working.'),
          onTap: () => open(context, const BecomeWorkerScreen()),
        ),
      ListTile(
        leading: const Icon(Icons.request_quote_outlined),
        title: const AppText('Price quotes'),
        onTap: () => open(context, const QuotesScreen()),
      ),
      ListTile(
        leading: NotificationBadge(
          count: Marketplace.shared.unreadCount,
          child: const Icon(Icons.notifications_outlined),
        ),
        title: const AppText('Activity & alerts'),
        onTap: () => open(context, const ActivityScreen()),
      ),
      if (Marketplace.shared.isWorker)
        ListTile(
          leading: const Icon(Icons.history),
          title: const AppText('Previous customer orders'),
          onTap: () => open(context, const CustomerHistoryScreen()),
        ),
      if (Marketplace.shared.isAdmin)
        ListTile(
          key: const Key('admin-panel'),
          leading: const Icon(Icons.admin_panel_settings_outlined),
          title: const AppText('Admin panel'),
          onTap: () => open(context, const AdminScreen()),
        ),
    ],
  );
}

class OrderActivityScreen extends StatefulWidget {
  const OrderActivityScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<OrderActivityScreen> createState() => _OrderActivityScreenState();
}

class _OrderActivityScreenState extends State<OrderActivityScreen> {
  Timer? _timer;
  Map<String, dynamic>? _data;
  String? _error, _photo;
  int _tab = 0, _stars = 0;
  bool _busy = false, _loading = false;
  String _reason = 'quality';
  final _message = TextEditingController(),
      _feedback = TextEditingController(),
      _complaint = TextEditingController(),
      _cost = TextEditingController(),
      _costNote = TextEditingController();
  final Map<String, String> _ids = {};
  final Map<String, String> _payloads = {};
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_message, _feedback, _complaint, _cost, _costNote]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _busy) return;
    _loading = true;
    try {
      final d = await Marketplace.shared.request(
        'orders/${widget.orderId}/experience',
      );
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      _loading = false;
    }
  }

  Future<void> _send(String action, Map<String, dynamic> body) async {
    if (_busy) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final payload = jsonEncode(body);
      if (_payloads[action] != payload) {
        _ids[action] = Marketplace.id();
        _payloads[action] = payload;
      }
      body['requestId'] = _ids.putIfAbsent(action, Marketplace.id);
      final d = await Marketplace.shared.request(
        'orders/${widget.orderId}/$action',
        body: body,
      );
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
          _ids.remove(action);
          _photo = null;
          if (action == 'message') _message.clear();
          if (action == 'complaint') _complaint.clear();
          if (action == 'extra') {
            _cost.clear();
            _costNote.clear();
          }
        });
      }
      await Marketplace.shared.refresh();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach() async {
    try {
      final p = await pickServicePhoto();
      if (p != null && mounted) {
        setState(() {
          _photo = p;
          _ids.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Widget _field(TextEditingController c, String label, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextField(
          controller: c,
          maxLength: number ? 10 : 2000,
          minLines: number ? 1 : 2,
          maxLines: number ? 1 : 5,
          keyboardType: number ? TextInputType.number : TextInputType.multiline,
          onChanged: (_) => _ids.clear(),
          decoration: InputDecoration(
            labelText: tr(label),
            alignLabelWithHint: true,
          ),
        ),
      );
  Widget _attachment() => Row(
    children: [
      TextButton.icon(
        onPressed: _busy ? null : _attach,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: AppText(_photo == null ? 'Attach photo' : 'Change photo'),
      ),
      if (_photo != null)
        IconButton(
          onPressed: () => setState(() => _photo = null),
          icon: const Icon(Icons.close),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: Marketplace.shared,
      builder: (c, _) {
        final o = Marketplace.shared.orders
            .where((o) => o['id'] == widget.orderId)
            .firstOrNull;
        final worker = Marketplace.shared.account?['uid'] == o?['worker_uid'];
        final active =
            o != null && ['pending', 'accepted'].contains(o['status']);
        return Scaffold(
          appBar: AppBar(title: const AppText('Order conversation')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.handshake_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            (worker
                                        ? (o?['customer_name'])
                                        : (o?['worker_name']))
                                    as String? ??
                                'SANAD',
                          ),
                        ),
                        if (o != null) SanadStatus(o['status'] as String),
                      ],
                    ),
                  ),
                  SanadTabs(
                    labels: const ['Chat', 'Costs', 'Review', 'Help'],
                    selected: _tab,
                    onSelect: (v) => setState(() {
                      _tab = v;
                      _photo = null;
                    }),
                  ),
                  if (_error != null)
                    MaterialBanner(
                      content: AppText(_error!),
                      actions: [
                        TextButton(
                          onPressed: _load,
                          child: const AppText('Retry'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: _data == null
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.all(18),
                            children: [
                              if (_tab == 0) ...[
                                if ((_data!['messages'] as List).isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(28),
                                    child: AppText(
                                      'Discuss the service details here.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                for (final m in _data!['messages'] as List)
                                  Align(
                                    alignment:
                                        m['sender_uid'] ==
                                            Marketplace.shared.account?['uid']
                                        ? AlignmentDirectional.centerEnd
                                        : AlignmentDirectional.centerStart,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 480,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color:
                                            m['sender_uid'] ==
                                                Marketplace
                                                    .shared
                                                    .account?['uid']
                                            ? SanadUi.lime.withValues(
                                                alpha: .25,
                                              )
                                            : SanadUi.surface(context),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(m['body'] as String),
                                          if (m['has_photo'] == 1)
                                            TextButton(
                                              onPressed: () => showServicePhoto(
                                                context,
                                                'message',
                                                m['id'] as String,
                                              ),
                                              child: const AppText(
                                                'View Picture',
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          Text(
                                            localTime(m['created_at']),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: SanadUi.muted(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (active) ...[
                                  _field(_message, 'Write a message'),
                                  _attachment(),
                                  FilledButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _send('message', {
                                            'text': _message.text,
                                            'photo': _photo,
                                          }),
                                    icon: const Icon(Icons.send_outlined),
                                    label: const AppText('Send'),
                                  ),
                                ] else
                                  const AppText(
                                    'This conversation is read-only after the order closes.',
                                  ),
                              ],
                              if (_tab == 1) ...[
                                const AppText(
                                  'Service amount',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  egp((o?['amount'] as int?) ?? 0),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                for (final e in _data!['extras'] as List)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: SanadPanel(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(e['note'] as String),
                                          Text(egp(e['amount'] as int)),
                                          AppText(e['status'] as String),
                                          if (!worker &&
                                              e['status'] == 'pending' &&
                                              o?['status'] == 'accepted')
                                            Wrap(
                                              spacing: 10,
                                              children: [
                                                for (final action in [
                                                  'approve',
                                                  'reject',
                                                ])
                                                  TextButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () async {
                                                            final confirmed = await showDialog<bool>(
                                                              context: context,
                                                              builder: (c) => AlertDialog(
                                                                title: AppText(
                                                                  action ==
                                                                          'approve'
                                                                      ? 'Approve additional cost?'
                                                                      : 'Reject additional cost?',
                                                                ),
                                                                content: Text(
                                                                  egp(
                                                                    e['amount']
                                                                        as int,
                                                                  ),
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                          c,
                                                                          false,
                                                                        ),
                                                                    child:
                                                                        const AppText(
                                                                          'Back',
                                                                        ),
                                                                  ),
                                                                  FilledButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                          c,
                                                                          true,
                                                                        ),
                                                                    child: const AppText(
                                                                      'Confirm',
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                            if (confirmed !=
                                                                true) {
                                                              return;
                                                            }
                                                            await _send(
                                                              'extras/${e['id']}',
                                                              {
                                                                'action':
                                                                    action,
                                                              },
                                                            );
                                                          },
                                                    child: AppText(
                                                      action == 'approve'
                                                          ? 'Approve & reserve'
                                                          : 'Reject',
                                                    ),
                                                  ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (worker && o?['status'] == 'accepted') ...[
                                  _field(
                                    _cost,
                                    'Additional amount (EGP)',
                                    number: true,
                                  ),
                                  _field(
                                    _costNote,
                                    'Reason for additional cost',
                                  ),
                                  FilledButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _send('extra', {
                                            'amount':
                                                ((double.tryParse(_cost.text) ??
                                                            0) *
                                                        100)
                                                    .round(),
                                            'note': _costNote.text,
                                          }),
                                    child: const AppText(
                                      'Request customer approval',
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                const AppText(
                                  'Additional costs are charged only after customer approval.',
                                ),
                              ],
                              if (_tab == 2) ...[
                                if (_data!['review'] != null)
                                  SanadPanel(
                                    child: Column(
                                      children: [
                                        Text(
                                          '${_data!['review']['stars']} / 5',
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                        Text(
                                          _data!['review']['comment'] as String,
                                        ),
                                        if (_data!['review']['has_photo'] == 1)
                                          TextButton(
                                            onPressed: () => showServicePhoto(
                                              context,
                                              'review',
                                              widget.orderId,
                                            ),
                                            child: const AppText(
                                              'View Picture',
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                else if (!worker &&
                                    o?['status'] == 'completed') ...[
                                  const AppText(
                                    'How was the worker?',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Wrap(
                                    children: [
                                      for (var i = 1; i <= 5; i++)
                                        IconButton(
                                          tooltip: '$i / 5',
                                          onPressed: () =>
                                              setState(() => _stars = i),
                                          icon: Icon(
                                            i <= _stars
                                                ? Icons.star
                                                : Icons.star_outline,
                                            color: Colors.amber,
                                            size: 36,
                                          ),
                                        ),
                                    ],
                                  ),
                                  _field(_feedback, 'Your feedback (optional)'),
                                  _attachment(),
                                  FilledButton(
                                    onPressed: _busy || _stars == 0
                                        ? null
                                        : () => _send('review', {
                                            'stars': _stars,
                                            'comment': _feedback.text,
                                            'photo': _photo,
                                          }),
                                    child: const AppText('Submit review'),
                                  ),
                                ] else
                                  const AppText(
                                    'Reviews are available after the customer confirms completed work.',
                                  ),
                              ],
                              if (_tab == 3) ...[
                                const AppText(
                                  'Report a problem',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  initialValue: _reason,
                                  decoration: InputDecoration(
                                    labelText: tr('Reason'),
                                  ),
                                  items: [
                                    for (final reason in [
                                      'no_show',
                                      'quality',
                                      'pricing',
                                      'safety',
                                      'other',
                                    ])
                                      DropdownMenuItem(
                                        value: reason,
                                        child: AppText(reason),
                                      ),
                                  ],
                                  onChanged: _busy
                                      ? null
                                      : (v) => setState(() => _reason = v!),
                                ),
                                _field(_complaint, 'Describe the problem'),
                                _attachment(),
                                FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _send('complaint', {
                                          'reason': _reason,
                                          'text': _complaint.text,
                                          'photo': _photo,
                                        }),
                                  child: const AppText('Submit complaint'),
                                ),
                                const SizedBox(height: 24),
                                for (final x in _data!['complaints'] as List)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: SanadPanel(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AppText(
                                            x['reason'] as String,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(x['body'] as String),
                                          AppText(x['status'] as String),
                                          if ((x['reply'] as String)
                                              .isNotEmpty) ...[
                                            const Divider(),
                                            const AppText('Support reply'),
                                            Text(x['reply'] as String),
                                          ],
                                          if (x['has_photo'] == 1)
                                            TextButton(
                                              onPressed: () => showServicePhoto(
                                                context,
                                                'complaint',
                                                x['id'] as String,
                                              ),
                                              child: const AppText(
                                                'View Picture',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class WorkerReviewsScreen extends StatefulWidget {
  const WorkerReviewsScreen({super.key, required this.uid, required this.name});
  final String uid, name;
  @override
  State<WorkerReviewsScreen> createState() => _WorkerReviewsState();
}

class _WorkerReviewsState extends State<WorkerReviewsScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = Marketplace.shared.request('workers/${widget.uid}/reviews');
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (c, s) {
          if (s.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(
                  () => _future = Marketplace.shared.request(
                    'workers/${widget.uid}/reviews',
                  ),
                ),
                child: const AppText('Retry'),
              ),
            );
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = s.data!['reviews'] as List;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AppText(
                'Customer reviews',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              if (rows.isEmpty) const AppText('No reviews yet'),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SanadPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('★ ${r['stars']} / 5'),
                        Text(r['comment'] as String),
                        Text(localTime(r['created_at'])),
                        if (r['has_photo'] == 1)
                          TextButton(
                            onPressed: () => showServicePhoto(
                              context,
                              'review',
                              r['order_id'] as String,
                            ),
                            child: const AppText('View Picture'),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});
  @override
  State<QuotesScreen> createState() => _QuotesState();
}

class _QuotesState extends State<QuotesScreen> {
  String? _error;
  bool _busy = false;
  final Map<String, String> _ids = {};
  Future<void> _act(Map q, String action) async {
    if (_busy) return;
    final m = Marketplace.shared;
    Map<String, dynamic> body = {};
    String path = 'quotes/${q['id']}/$action';
    if (action == 'offer') {
      final c = TextEditingController();
      final amount = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const AppText('Send price quote'),
          content: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('Amount (EGP)')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                ((double.tryParse(c.text) ?? 0) * 100).round(),
              ),
              child: const AppText('Send'),
            ),
          ],
        ),
      );
      c.dispose();
      if (amount == null || !mounted) return;
      body = {'amount': amount};
    }
    if (action == 'book') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const AppText('Approve quote & reserve?'),
          content: Text(egp(q['amount'] as int)),
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
      if (yes != true || !mounted) return;
      path = 'orders';
      String? quotePhoto;
      if (q['has_photo'] == true) {
        try {
          quotePhoto =
              (await m.request(
                    'attachment',
                    body: {'kind': 'quote', 'id': q['id']},
                  ))['photo']
                  as String?;
        } catch (e) {
          if (mounted) setState(() => _error = friendlyError(e));
          return;
        }
      }
      body = {
        'photo': quotePhoto,
        'requestId': _ids.putIfAbsent(q['id'] as String, Marketplace.id),
        'workerUid': q['worker_uid'],
        'services': q['services'],
        'details': q['details'],
        'location': q['location'],
        'scheduledAt': q['scheduled_at'],
        'quoteId': q['id'],
        'expectedQuoteAmount': q['amount'],
      };
    }
    setState(() => _busy = true);
    try {
      final d = await m.request(path, body: body);
      m.apply(d);
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: Marketplace.shared,
      builder: (c, _) {
        final m = Marketplace.shared;
        return Scaffold(
          appBar: AppBar(title: const AppText('Price quotes')),
          body: RefreshIndicator(
            onRefresh: m.refresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const AppText('Agree on the price before reserving funds.'),
                    if (_error != null) AppText(_error!),
                    if (_busy) const LinearProgressIndicator(),
                    if (m.quotes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(36),
                        child: AppText('No quote requests yet'),
                      ),
                    for (final q in m.quotes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: SanadPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (m.isWorker
                                        ? q['customer_name']
                                        : q['worker_name'])
                                    as String,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(q['details'] as String),
                              if (q['has_photo'] == true)
                                TextButton(
                                  onPressed: () => showServicePhoto(
                                    context,
                                    'quote',
                                    q['id'] as String,
                                  ),
                                  child: const AppText('View Picture'),
                                ),
                              Text((q['location'] as Map)['label'] as String),
                              Text(localTime(q['scheduled_at'])),
                              AppText(q['status'] as String),
                              if ((q['amount'] as int) > 0)
                                Text(
                                  egp(q['amount'] as int),
                                  style: const TextStyle(fontSize: 24),
                                ),
                              Wrap(
                                spacing: 12,
                                children: [
                                  if (m.isWorker &&
                                      [
                                        'requested',
                                        'offered',
                                      ].contains(q['status']))
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _act(q, 'offer'),
                                      child: const AppText('Send price quote'),
                                    ),
                                  if (!m.isWorker && q['status'] == 'offered')
                                    FilledButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _act(q, 'book'),
                                      child: const AppText('Approve & reserve'),
                                    ),
                                  if ([
                                    'requested',
                                    'offered',
                                  ].contains(q['status']))
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _act(q, 'cancel'),
                                      child: const AppText('Cancel'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: Marketplace.shared,
      builder: (c, _) {
        final m = Marketplace.shared;
        return Scaffold(
          appBar: AppBar(title: const AppText('Activity & alerts')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const AppText('Enable browser alerts'),
                subtitle: const AppText('Receive alerts while SANAD is open.'),
                onTap: () async {
                  final result = await alerts.enableAlerts();
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: AppText(result)));
                  }
                },
              ),
              if (m.error != null) AppText(m.error!),
              if (m.notices.isEmpty) const AppText('No Notifications'),
              for (final n in m.notices)
                Card(
                  child: ListTile(
                    leading: Icon(
                      n['kind'] == 'message'
                          ? Icons.chat_bubble_outline
                          : Icons.notifications_outlined,
                    ),
                    title: AppText(
                      n['kind'] == 'message'
                          ? 'New message'
                          : n['kind'] == 'quote'
                          ? 'Price quote'
                          : n['kind'] == 'withdrawal'
                          ? 'Withdrawal request'
                          : n['kind'] == 'complaint'
                          ? 'Support update'
                          : 'Order update',
                      style: TextStyle(
                        fontWeight: n['read'] == true
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(n['body'] as String),
                        Text(localTime(n['at'])),
                      ],
                    ),
                    onTap: () async {
                      try {
                        await m.request('notice/read', body: {'id': n['id']});
                        await m.refresh();
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => n['kind'] == 'withdrawal'
                                ? const WorkerWalletScreen()
                                : n['kind'] == 'quote'
                                ? const QuotesScreen()
                                : OrderActivityScreen(
                                    orderId: n['target'] as String,
                                  ),
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: AppText(friendlyError(e))),
                          );
                        }
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CustomerHistoryScreen extends StatelessWidget {
  const CustomerHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final m = Marketplace.shared;
    final rows = m.orders.where((o) => o['customer_uid'] == m.account?['uid']);
    return Scaffold(
      appBar: AppBar(title: const AppText('Previous customer orders')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          for (final o in rows)
            Card(
              child: ListTile(
                title: Text(o['worker_name'] as String),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o['details'] as String),
                    AppText(o['status'] as String),
                    Text(egp(o['amount'] as int)),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderActivityScreen(orderId: o['id'] as String),
                  ),
                ),
              ),
            ),
          for (final o in m.account?['legacy_orders'] as List? ?? [])
            Card(
              child: ListTile(
                title: Text(o['service'] as String? ?? ''),
                subtitle: Text(o['description'] as String? ?? ''),
                trailing: const AppText('Archived'),
              ),
            ),
        ],
      ),
    );
  }
}

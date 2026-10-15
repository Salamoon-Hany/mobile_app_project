import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../widgets/sanad_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_language.dart';
import '../models/wallet.dart';
import '../services/marketplace_service.dart';
import 'dashboard.dart';
import 'worker_wallet.dart';
import 'service_tools.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerHome extends StatefulWidget {
  const WorkerHome({super.key, this.saveAvailability});
  final Future<void> Function(bool)? saveAvailability;
  @override
  State<WorkerHome> createState() => _WorkerHomeState();
}

class _WorkerHomeState extends State<WorkerHome> {
  int _tab = 0, _filter = 0;
  String _query = "";
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _availabilityBusy = false;
  final Set<String> _busy = {};
  String? _notice;
  Future<void> _decision(String id, String action) async {
    if (_busy.contains(id)) return;
    setState(() {
      _busy.add(id);
      _notice = null;
    });
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: AppText(
            action == 'accept' ? 'Accept this order?' : 'Reject this order?',
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
      if (ok == true && mounted) await Marketplace.shared.decide(id, action);
    } catch (e) {
      if (mounted)
        setState(
          () => _notice = e is FormatException
              ? e.message
              : 'Could not sync your account. Check your connection and retry.',
        );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _skills() async {
    final selected = Set<String>.from(
      Marketplace.shared.account?['skills'] as List? ?? [],
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const AppText('Services I provide'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final j in jobCatalog)
                    CheckboxListTile(
                      title: AppText(j.name),
                      value: selected.contains(j.id),
                      onChanged: (v) => set(
                        () => v == true
                            ? selected.add(j.id)
                            : selected.remove(j.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const AppText('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const AppText('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await Marketplace.shared.saveProfile(
        name: AppState.getUserName(),
        skills: selected.toList(),
      );
    } catch (e) {
      if (mounted)
        setState(
          () => _notice = e is FormatException
              ? e.message
              : 'Could not sync your account. Check your connection and retry.',
        );
    }
  }

  void _jobs(int filter) => setState(() {
    _tab = 1;
    _filter = filter;
    _query = '';
    _search.clear();
  });
  Widget _avatar() => ValueListenableBuilder<Uint8List?>(
    valueListenable: AppState.profileImage,
    builder: (c, photo, _) => IconButton(
      key: const Key('worker-profile-shortcut'),
      tooltip: tr('My Profile'),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      icon: CircleAvatar(
        radius: 21,
        backgroundColor: Colors.white,
        backgroundImage: photo == null ? null : MemoryImage(photo),
        child: photo == null
            ? const Icon(Icons.person_outline, color: SanadUi.ink)
            : null,
      ),
    ),
  );
  Future<void> _availability(bool value) async {
    if (_availabilityBusy) return;
    setState(() {
      _availabilityBusy = true;
      _notice = null;
    });
    try {
      if (widget.saveAvailability != null) {
        await widget.saveAvailability!(value);
      } else {
        await Marketplace.shared.saveProfile(
          name: AppState.getUserName(),
          available: value,
        );
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _notice =
              'Could not sync your account. Check your connection and retry.',
        );
    } finally {
      if (mounted) setState(() => _availabilityBusy = false);
    }
  }

  void _details(Map<String, dynamic> o) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => WorkerRequestScreen(order: o)),
  );
  Widget _section(
    String title, {
    VoidCallback? action,
    String label = 'See all',
  }) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: AppText(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        if (action != null)
          TextButton(onPressed: action, child: AppText(label)),
      ],
    ),
  );
  Widget _metric(String label, int count, int filter) => Expanded(
    child: InkWell(
      onTap: () => _jobs(filter),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            AppText(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: SanadUi.muted(context)),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _serviceChips(Marketplace m) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final j in jobCatalog.where(
        (j) => (m.account?['skills'] as List? ?? []).contains(j.id),
      ))
        SanadPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                j.imagePath!,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              AppText(j.name, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
    ],
  );
  Widget _request(Map<String, dynamic> o, {bool compact = false}) =>
      WorkerRequestCard(
        order: o,
        compact: compact,
        busy: _busy.contains(o['id']),
        onDetails: () => _details(o),
        onDecision: (action) => _decision(o['id'] as String, action),
      );
  Widget _empty() => const SanadPanel(
    padding: EdgeInsets.symmetric(vertical: 38, horizontal: 20),
    child: Column(
      children: [
        Icon(Icons.inbox_outlined, size: 36),
        SizedBox(height: 12),
        AppText('No orders here yet.', textAlign: TextAlign.center),
      ],
    ),
  );
  Widget _home(
    Marketplace m,
    List<Map<String, dynamic>> pending,
    List<Map<String, dynamic>> active,
    List<Map<String, dynamic>> history,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        color: SanadUi.lime,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'Hello,',
                    style: TextStyle(color: SanadUi.ink, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppState.getUserName(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SanadUi.ink,
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Image.asset(
              'Pics & Icons/Working Man.png',
              height: 108,
              width: 100,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SanadPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const AppText(
                  'Available for jobs',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: (m.account?['available'] ?? 1) == 0
                    ? const AppText('New requests are paused')
                    : null,
                value: (m.account?['available'] ?? 1) == 1,
                onChanged: _availabilityBusy ? null : _availability,
              ),
            ),
            const SizedBox(height: 12),
            SanadPanel(
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Available earnings',
                          style: TextStyle(
                            fontSize: 12,
                            color: SanadUi.muted(context),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          egp(m.account?['balance'] as int? ?? 0),
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => setState(() => _tab = 2),
                    child: const AppText(
                      'View wallet',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SanadPanel(
              padding: const EdgeInsets.all(4),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _metric('Pending', pending.length, 0),
                    const VerticalDivider(width: 1, indent: 12, endIndent: 12),
                    _metric('Active', active.length, 1),
                    const VerticalDivider(width: 1, indent: 12, endIndent: 12),
                    _metric(
                      'Completed',
                      history.where((o) => o['status'] == 'completed').length,
                      2,
                    ),
                  ],
                ),
              ),
            ),
            _section('New requests', action: () => _jobs(0)),
            if (pending.isEmpty) _empty(),
            for (final o in pending.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _request(o, compact: true),
              ),
            _section('My services', action: _skills, label: 'Edit'),
            if ((m.account?['skills'] as List? ?? []).isEmpty)
              const AppText('Choose your services to appear to customers.'),
            _serviceChips(m),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ],
  );
  Widget _jobsPage(
    List<Map<String, dynamic>> pending,
    List<Map<String, dynamic>> active,
    List<Map<String, dynamic>> history,
  ) {
    final selected = [pending, active, history][_filter];
    final rows = selected
        .where(
          (o) => [
            requestServices(o),
            (o['services'] as List)
                .map(
                  (id) => tr(
                    jobCatalog.where((j) => j.id == id).firstOrNull?.name ?? '',
                  ),
                )
                .join(' '),
            o['details'],
            o['customer_name'],
            (o['location'] as Map?)?['label'],
          ].join(' ').toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('worker-job-search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: tr('Search jobs by service or location'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: SanadUi.surface(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(end: i < 2 ? 6 : 0),
                    child: TextButton(
                      key: Key('worker-filter-' + i.toString()),
                      onPressed: () => setState(() => _filter = i),
                      style: TextButton.styleFrom(
                        backgroundColor: _filter == i
                            ? SanadUi.lime
                            : SanadUi.surface(context),
                        foregroundColor: _filter == i
                            ? SanadUi.ink
                            : SanadUi.text(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        i == 2
                            ? tr('History')
                            : tr(i == 0 ? 'Pending' : 'Active') +
                                  ' (' +
                                  [
                                    pending.length,
                                    active.length,
                                  ][i].toString() +
                                  ')',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty) _empty(),
          for (final o in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _request(o),
            ),
        ],
      ),
    );
  }

  Widget _settings(Marketplace m) => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      children: [
        SanadPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const AppText('Balance'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      egp(m.account?['balance'] as int? ?? 0),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => setState(() => _tab = 2),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.language),
                title: const AppText('Language'),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: AppLanguage.code.value,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ar', child: Text('العربية')),
                    ],
                    onChanged: (v) {
                      if (v != null) AppLanguage.select(v);
                    },
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const AppText('Dark Mode'),
                value: AppState.darkMode.value,
                onChanged: AppState.setDarkMode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const ServiceTools(),
        SanadPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const AppText('Contact us'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const AppText('Contact us'),
                    content: const AppText(
                      'If you have any question\nwe are happy to help',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const AppText('Back'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const AppText('Logout'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: Marketplace.shared,
      builder: (c, _) {
        final m = Marketplace.shared;
        final pending = m.assignedOrders
                .where((o) => o['status'] == 'pending')
                .toList(),
            active = m.assignedOrders
                .where((o) => o['status'] == 'accepted')
                .toList(),
            history = m.assignedOrders
                .where((o) => !['pending', 'accepted'].contains(o['status']))
                .toList();
        return Scaffold(
          backgroundColor: SanadUi.canvas(context),
          appBar: _tab == 2
              ? null
              : AppBar(
                  backgroundColor: _tab == 0
                      ? SanadUi.lime
                      : SanadUi.canvas(context),
                  surfaceTintColor: Colors.transparent,
                  title: _tab == 0
                      ? Image.asset(
                          'Pics & Icons/Logo.png',
                          width: 90,
                          height: 38,
                          fit: BoxFit.contain,
                        )
                      : AppText(
                          _tab == 1 ? 'My jobs' : 'Settings',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  actions: [_avatar(), const SizedBox(width: 8)],
                ),
          body: _tab == 2
              ? const WorkerWalletScreen(embedded: true)
              : RefreshIndicator(
                  onRefresh: m.refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (m.error != null)
                                MaterialBanner(
                                  content: AppText(m.error!),
                                  actions: [
                                    TextButton(
                                      onPressed: m.refresh,
                                      child: const AppText('Retry'),
                                    ),
                                  ],
                                ),
                              if (_notice != null)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: AppText(_notice!),
                                ),
                              if (_tab == 0)
                                _home(m, pending, active, history)
                              else if (_tab == 1)
                                _jobsPage(pending, active, history)
                              else
                                _settings(m),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: NavigationBar(
            height: 72,
            selectedIndex: _tab,
            backgroundColor: SanadUi.surface(context),
            surfaceTintColor: Colors.transparent,
            indicatorColor: SanadUi.lime,
            onDestinationSelected: (v) => setState(() => _tab = v),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home, color: SanadUi.ink),
                label: tr('Home'),
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: pending.isNotEmpty,
                  label: Text(pending.length.toString()),
                  child: const Icon(Icons.assignment_outlined),
                ),
                selectedIcon: const Icon(
                  Icons.assignment_outlined,
                  color: SanadUi.ink,
                ),
                label: tr('Jobs'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: SanadUi.ink,
                ),
                label: tr('Wallet'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(
                  Icons.settings_outlined,
                  color: SanadUi.ink,
                ),
                label: tr('Settings'),
              ),
            ],
          ),
        );
      },
    );
  }
}

String requestServices(Map<String, dynamic> o) => (o['services'] as List)
    .map(
      (id) =>
          jobCatalog.where((j) => j.id == id).firstOrNull?.name ??
          id.toString(),
    )
    .join(', ');
String requestTime(Map<String, dynamic> o) {
  final d = DateTime.fromMillisecondsSinceEpoch(
    o['created_at'] as int,
  ).toLocal();
  return d.day.toString() +
      '/' +
      d.month.toString() +
      '/' +
      d.year.toString() +
      '  ' +
      d.hour.toString().padLeft(2, '0') +
      ':' +
      d.minute.toString().padLeft(2, '0');
}

class WorkerRequestCard extends StatelessWidget {
  const WorkerRequestCard({
    super.key,
    required this.order,
    required this.onDetails,
    required this.onDecision,
    this.compact = false,
    this.busy = false,
  });
  final Map<String, dynamic> order;
  final VoidCallback onDetails;
  final ValueChanged<String> onDecision;
  final bool compact, busy;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final j = jobCatalog
        .where((j) => (o['services'] as List).contains(j.id))
        .firstOrNull;
    return SanadPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (j != null) ...[
                Image.asset(
                  j.imagePath!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      requestServices(o),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      o['details'] as String,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: SanadUi.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SanadStatus(o['status'] as String),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  o['customer_name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (compact)
                Text(
                  egp(o['amount'] as int),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (o['location'] as Map?)?['label'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: SanadUi.muted(context)),
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    requestTime(o),
                    style: TextStyle(
                      fontSize: 12,
                      color: SanadUi.muted(context),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              egp(o['amount'] as int),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
          if (!compact && o['status'] == 'pending')
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => onDecision('accept'),
                    child: const AppText('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => onDecision('reject'),
                    child: const AppText('Reject'),
                  ),
                ),
              ],
            ),
          TextButton(
            key: Key('request-' + (o['id'] as String)),
            onPressed: onDetails,
            child: const AppText('View details'),
          ),
        ],
      ),
    );
  }
}

class WorkerRequestScreen extends StatefulWidget {
  const WorkerRequestScreen({super.key, required this.order});
  final Map<String, dynamic> order;
  @override
  State<WorkerRequestScreen> createState() => _WorkerRequestScreenState();
}

class _WorkerRequestScreenState extends State<WorkerRequestScreen> {
  bool _busy = false, _loadingPhoto = false;
  String? _error;
  Uint8List? _photo;
  @override
  void initState() {
    super.initState();
    if (widget.order['photo'] != null)
      _photo = Marketplace.photoBytes(widget.order['photo'] as String);
  }

  Future<void> _decision(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: AppText(
            action == 'accept' ? 'Accept this order?' : 'Reject this order?',
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
      if (ok != true) return;
      await Marketplace.shared.decide(widget.order['id'] as String, action);
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

  Future<void> _loadPhoto() async {
    setState(() => _loadingPhoto = true);
    try {
      final b = await Marketplace.shared.orderPhoto(
        widget.order['id'] as String,
      );
      if (mounted) setState(() => _photo = b);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the photo. Retry.');
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  Future<void> _map(Map loc) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': loc['latitude'].toString() + ',' + loc['longitude'].toString(),
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
        throw const FormatException();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the map.');
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: Marketplace.shared,
      builder: (c, _) {
        final o =
            Marketplace.shared.orders
                .where((v) => v['id'] == widget.order['id'])
                .firstOrNull ??
            widget.order;
        final loc = o['location'] as Map;
        final state = o['status'] as String;
        final j = jobCatalog
            .where((j) => (o['services'] as List).contains(j.id))
            .firstOrNull;
        return PopScope(
          canPop: !_busy,
          child: Scaffold(
            backgroundColor: SanadUi.canvas(context),
            appBar: AppBar(
              title: const AppText('Request details'),
              leading: IconButton(
                key: const Key('request-back'),
                tooltip: tr('Back'),
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const ReferenceIcon('back', mirror: true),
              ),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Row(
                      children: [
                        if (j != null) ...[
                          Image.asset(j.imagePath!, width: 60, height: 60),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: AppText(
                            requestServices(o),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SanadStatus(state),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SanadPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'Service details',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            o['details'] as String,
                            style: const TextStyle(height: 1.5),
                          ),
                          if (_photo != null) ...[
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _photo!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ] else if (o['has_photo'] == 1)
                            TextButton.icon(
                              onPressed: _loadingPhoto ? null : _loadPhoto,
                              icon: const Icon(Icons.image_outlined),
                              label: AppText(
                                _loadingPhoto ? 'Loading...' : 'View Picture',
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SanadPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'Customer',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const CircleAvatar(
                                child: Icon(Icons.person_outline),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  o['customer_name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if ((o['customer_phone'] as String? ?? '')
                              .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SelectableText(o['customer_phone'] as String),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SanadPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on_outlined),
                              SizedBox(width: 10),
                              AppText(
                                'Location',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (loc['redacted'] == true)
                            const AppText('Location removed')
                          else ...[
                            Text(
                              loc['label'] as String,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              loc['latitude'].toString() +
                                  ', ' +
                                  loc['longitude'].toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: SanadUi.muted(context),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _map(loc),
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const AppText('View location'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SanadPanel(
                      child: Row(
                        children: [
                          const Icon(Icons.schedule),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText(
                                  'Requested at',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 5),
                                Text(requestTime(o)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SanadPanel(
                      child: Row(
                        children: [
                          const Icon(Icons.payments_outlined),
                          const SizedBox(width: 12),
                          const Expanded(child: AppText('Service amount')),
                          Text(
                            egp(o['amount'] as int),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OrderActivityScreen(orderId: o['id'] as String),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const AppText('Chat, costs & help'),
                    ),
                    if ((o['scheduled_at'] as int? ?? 0) > 0)
                      ListTile(
                        leading: const Icon(Icons.event),
                        title: const AppText('Appointment'),
                        subtitle: Text(localTime(o['scheduled_at'])),
                      ),
                    if (state == 'accepted')
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: AppText(
                          'Waiting for the customer to confirm completed work.',
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: AppText(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: state == 'pending'
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _decision('accept'),
                              child: const AppText('Accept'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _decision('reject'),
                              child: const AppText('Reject'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../models/customer_settings.dart';
import '../models/phone_number.dart';
import '../models/profile_validation.dart';
import '../services/marketplace_service.dart';
import 'dashboard.dart';

class BecomeWorkerScreen extends StatelessWidget {
  const BecomeWorkerScreen({super.key, this.onNeedHelp});
  final VoidCallback? onNeedHelp;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final application = Marketplace.shared.workerApplication;
    return Scaffold(
      appBar: AppBar(title: const AppText('Become a worker')),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 240,
                    decoration: BoxDecoration(
                      color: const Color(0xFFe6f2b9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Image.asset(
                      'Pics & Icons/Working Man.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const AppText(
                    'BECOME A WORKER WITH US?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    'Join Our Workforce Today',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const _Benefit(
                    icon: Icons.work_outline,
                    title: 'More job opportunities',
                    description:
                        'Show your skills to customers looking for help.',
                  ),
                  const _Benefit(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Build your reputation',
                    description:
                        'Keep your profile and completed work together.',
                  ),
                  const _Benefit(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Manage your work',
                    description:
                        'Track requests, locations and earnings in one place.',
                  ),
                  if (application != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Chip(
                        label: AppText(
                          '${tr('Application status')}: ${tr(_status(application))}',
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: () async {
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkerApplicationScreen(
                            initialApplication: application,
                          ),
                        ),
                      );
                      if (saved == true && context.mounted)
                        Navigator.pop(context);
                    },
                    style: _actionStyle(context),
                    child: AppText(
                      application == null ? 'Register Now' : 'View application',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onNeedHelp ?? () => Navigator.pop(context),
                    child: const AppText('Need Help?'),
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

String _status(Map<String, dynamic> application) =>
    switch (application['status']) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFd7ff00),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.black),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              AppText(description),
            ],
          ),
        ),
      ],
    ),
  );
}

class WorkerApplicationScreen extends StatefulWidget {
  const WorkerApplicationScreen({
    super.key,
    this.initialApplication,
    this.initialName,
    this.initialPhone,
    this.initialEmail,
    this.onSubmit,
  });
  final Map<String, dynamic>? initialApplication;
  final String? initialName, initialPhone, initialEmail;
  final Future<void> Function(Map<String, dynamic>)? onSubmit;
  @override
  State<WorkerApplicationScreen> createState() =>
      _WorkerApplicationScreenState();
}

class _WorkerApplicationScreenState extends State<WorkerApplicationScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone, _email, _years;
  late Set<String> _types, _countries;
  bool _busy = false, _validate = false;
  String? _error;
  bool get _locked =>
      widget.initialApplication != null &&
      widget.initialApplication!['status'] != 'pending';
  @override
  void initState() {
    super.initState();
    final a = widget.initialApplication;
    _name = TextEditingController(
      text:
          a?['fullName'] as String? ??
          widget.initialName ??
          AppState.getUserName(),
    );
    _phone = TextEditingController(
      text:
          a?['phone'] as String? ??
          widget.initialPhone ??
          AppState.getPhoneNumber(),
    );
    _email = TextEditingController(
      text:
          a?['email'] as String? ??
          widget.initialEmail ??
          AppState.getUserEmail(),
    );
    _years = TextEditingController(
      text: a?['experienceYears']?.toString() ?? '',
    );
    _types = Set<String>.from(a?['workTypes'] as List? ?? []);
    _countries = Set<String>.from(a?['countries'] as List? ?? []);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _years.dispose();
    super.dispose();
  }

  Future<void> _choose({required bool country}) async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final values = Set<String>.from(country ? _countries : _types);
        return StatefulBuilder(
          builder: (c, update) => FractionallySizedBox(
            heightFactor: 0.78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: AppText(
                    country ? 'Select Experience Country' : 'Select work type',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: country
                        ? [
                            for (final entry in experienceCountries.entries)
                              CheckboxListTile(
                                value: values.contains(entry.key),
                                title: AppText(entry.value),
                                onChanged: (v) => update(
                                  () => v == true
                                      ? values.add(entry.key)
                                      : values.remove(entry.key),
                                ),
                              ),
                          ]
                        : [
                            for (final job in jobCatalog)
                              CheckboxListTile(
                                value: values.contains(job.id),
                                secondary: Container(
                                  width: 42,
                                  height: 42,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Image.asset(
                                    job.imagePath!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                title: AppText(job.name),
                                onChanged: (v) => update(
                                  () => v == true
                                      ? values.add(job.id)
                                      : values.remove(job.id),
                                ),
                              ),
                          ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(c, values),
                      child: const AppText('Ok'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted)
      setState(() {
        if (country) {
          _countries = selected;
        } else {
          _types = selected;
        }
      });
  }

  Widget _selection({required bool country}) {
    final values = country ? _countries : _types;
    final label = country ? 'Experience Country' : 'Work type';
    final names = values
        .map(
          (id) => tr(
            country
                ? experienceCountries[id]!
                : jobCatalog.firstWhere((j) => j.id == id).name,
          ),
        )
        .join(', ');
    return Semantics(
      button: true,
      label: tr(label),
      child: InkWell(
        key: Key(country ? 'application-countries' : 'application-work-types'),
        borderRadius: BorderRadius.circular(12),
        onTap: _busy || _locked ? null : () => _choose(country: country),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: tr(label),
            border: const OutlineInputBorder(),
            errorText: _validate && values.isEmpty
                ? tr(
                    country
                        ? 'Choose at least one country.'
                        : 'Choose at least one work type.',
                  )
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  names.isEmpty
                      ? tr(
                          country
                              ? 'Select Experience Country'
                              : 'Select work type',
                        )
                      : names,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _validate = true);
    if (!_form.currentState!.validate() ||
        _types.isEmpty ||
        _countries.isEmpty ||
        _busy ||
        _locked)
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    final payload = {
      'fullName': _name.text.trim(),
      'phone': normalizePhone(_phone.text),
      'workTypes': _types.toList(),
      'experienceYears': parseExperienceYears(_years.text),
      'countries': _countries.toList(),
    };
    try {
      if (widget.onSubmit != null) {
        await widget.onSubmit!(payload);
      } else {
        await Marketplace.shared.submitWorkerApplication(payload);
      }
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const CircleAvatar(
                radius: 43,
                backgroundColor: Color(0xFF10c96a),
                child: Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 49,
                ),
              ),
              const SizedBox(height: 28),
              AppText(
                widget.initialApplication == null
                    ? 'Registration Submitted'
                    : 'Application updated',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 22),
              const AppText(
                'Your application is saved. You can view its status in Settings.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(c),
                  child: const AppText('Ok'),
                ),
              ),
            ],
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'Could not save your application. Please retry.',
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
        appBar: AppBar(title: const AppText('Become a worker')),
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.initialApplication != null) ...[
                        Chip(
                          label: AppText(
                            '${tr('Application status')}: ${tr(_status(widget.initialApplication!))}',
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      TextFormField(
                        key: const Key('application-name'),
                        controller: _name,
                        enabled: !_busy && !_locked,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: tr('Full Name'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            trNullable(validateProfileName(v ?? '')),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        key: const Key('application-phone'),
                        controller: _phone,
                        enabled: !_busy && !_locked,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: tr('Phone Number'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          try {
                            normalizePhone(v ?? '');
                            return null;
                          } catch (_) {
                            return tr(
                              'Enter a valid phone number with country code.',
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        key: const Key('application-email'),
                        controller: _email,
                        readOnly: true,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: tr('Email Address'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _selection(country: false),
                      const SizedBox(height: 22),
                      TextFormField(
                        key: const Key('application-experience'),
                        controller: _years,
                        enabled: !_busy && !_locked,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tr('Years of experience'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => parseExperienceYears(v ?? '') == null
                            ? tr('Enter years of experience from 0 to 60.')
                            : null,
                      ),
                      const SizedBox(height: 22),
                      _selection(country: true),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        AppText(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!_locked)
                        FilledButton(
                          key: const Key('application-submit'),
                          onPressed: _busy ? null : _submit,
                          style: _actionStyle(context),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : AppText(
                                  widget.initialApplication == null
                                      ? 'Submit'
                                      : 'Save changes',
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _actionStyle(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return FilledButton.styleFrom(
    backgroundColor: dark ? const Color(0xFFd7ff00) : const Color(0xFF252525),
    foregroundColor: dark ? Colors.black : Colors.white,
    padding: const EdgeInsets.all(18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

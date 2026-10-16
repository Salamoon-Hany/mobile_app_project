import '../l10n/app_language.dart';
import '../services/marketplace_service.dart';
import '../services/camera_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../services/local_account_store.dart';
import '../services/phone_login_service.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/verification_service.dart';
import '../models/selected_location.dart';
import 'location_picker.dart';
import 'welcome.dart';
import '../widgets/sanad_ui.dart';
import 'become_worker.dart';
import 'app_rating.dart';
import 'service_tools.dart';
import 'auth_gate.dart';
import 'delete_account.dart';
import '../models/phone_number.dart';
import '../models/profile_completion.dart';
import 'add_funds.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../services/account_service.dart';
import '../models/booking.dart';
import '../models/profile_validation.dart';
export '../models/booking.dart';
part 'place_order.dart';
part 'profile.dart';
part 'orders.dart';
part 'notifications.dart';
part '../state/app_state.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static String _userPhoneNumber = '';
  static String _userName = '';
  static String _userEmail = '';
  static String _userGender = '';

  @override
  void initState() {
    super.initState();
    if (VerificationService.configured) {
      final user = FirebaseAuth.instance.currentUser;
      _userPhoneNumber = '';
      _userEmail = user?.email ?? '';
    }
  }

  static void setPhoneNumber(String phone) {
    _userPhoneNumber = phone;
  }

  static String getPhoneNumber() {
    return _userPhoneNumber;
  }

  static void setUserName(String name) {
    _userName = name;
  }

  static String getUserName() {
    return _userName;
  }

  static void setUserEmail(String email) {
    _userEmail = email;
  }

  static String getUserEmail() {
    return _userEmail;
  }

  static void setUserGender(String gender) {
    _userGender = gender;
  }

  static String getUserGender() {
    return _userGender;
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.code,
      builder: (context, language, child) => ValueListenableBuilder<bool>(
        valueListenable: AppState.darkMode,
        builder: (context, darkMode, child) => MaterialApp(
          title: 'سند | SANAD',
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) =>
              LanguageScope(child: DevicePreview.appBuilder(context, child)),
          theme: sanadTheme(Brightness.light),
          darkTheme: sanadTheme(Brightness.dark),
          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
          // Web launch is managed by web/sanad-intro.js while the engine loads.
          home: kIsWeb ? const AuthGate() : const SplashScreen(),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  bool _showMore = false;

  @override
  void initState() {
    super.initState();
    if (WalletService.backendConfigured) {
      final service = WalletService();
      unawaited(
        service
            .refresh()
            .catchError((Object _) {})
            .whenComplete(service.dispose),
      );
    }
  }

  final List<Service> services = [
    for (final job in jobCatalog.take(8)) Service.fromJob(job),
    Service(name: 'More', imagePath: null),
  ];
  final List<Service> moreServices = [
    for (final job in jobCatalog.skip(8)) Service.fromJob(job),
  ];

  List<Service> get _filteredServices {
    // Search the complete catalogue, including services under More.
    if (_searchQuery.isNotEmpty) {
      return jobCatalog
          .map(Service.fromJob)
          .where(
            (service) =>
                service.name.toLowerCase().contains(_searchQuery) ||
                tr(service.name).toLowerCase().contains(_searchQuery),
          )
          .toList();
    }
    List<Service> allServices = _showMore
        ? [
            ...services.where((s) => s.name != 'More'),
            ...moreServices,
            Service(name: 'Less', imagePath: null),
          ]
        : services;

    return allServices;
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return PopScope(
      child: Scaffold(
        backgroundColor: SanadUi.canvas(context),
        body: AnimatedBuilder(
          animation: Marketplace.shared,
          builder: (c, _) => Column(
            children: [
              if (Marketplace.shared.error != null)
                SafeArea(
                  bottom: false,
                  child: MaterialBanner(
                    content: AppText(Marketplace.shared.error!),
                    actions: [
                      TextButton(
                        onPressed: Marketplace.shared.refresh,
                        child: const AppText('Retry'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _selectedIndex == 0
                    ? _buildHomePage()
                    : _selectedIndex == 1
                    ? _buildOrdersPage()
                    : _selectedIndex == 2
                    ? _buildNotificationsPage()
                    : _buildSettingsPage(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: ReferenceIcon('home', muted: _selectedIndex != 0),
              label: tr('Home'),
            ),
            BottomNavigationBarItem(
              icon: const ReferenceIcon('orders', muted: true),
              activeIcon: const ReferenceIcon('orders-active'),
              label: tr('Orders'),
            ),
            BottomNavigationBarItem(
              icon: ReferenceIcon('bell', muted: _selectedIndex != 2),
              label: tr('Notifications'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: tr('Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage() => SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            Container(
              color: SanadUi.lime,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 24,
                16,
                44,
              ),
              child: Row(
                children: [
                  Image.asset(
                    'Pics & Icons/Logo.png',
                    width: 84,
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'Hi,',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppState.getUserName().isNotEmpty
                              ? AppState.getUserName()
                              : tr('Welcome'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: SanadUi.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<Uint8List?>(
                    valueListenable: AppState.profileImage,
                    builder: (c, photo, _) => IconButton(
                      key: const Key('profile-shortcut'),
                      tooltip: tr('My Profile'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                      icon: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        backgroundImage: photo == null
                            ? null
                            : MemoryImage(photo),
                        child: photo == null
                            ? const Icon(
                                Icons.person_outline,
                                color: Colors.black,
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -27),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  color: SanadUi.surface(context),
                  borderRadius: BorderRadius.circular(7),
                  elevation: 0,
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: tr('I want to hire a...'),
                      hintStyle: TextStyle(
                        fontSize: 17,
                        color: SanadUi.muted(context),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(14),
                        child: ReferenceIcon('search', muted: true),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 16,
                      ),
                      filled: true,
                      fillColor: SanadUi.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 18),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppText(
                  'Services',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: SanadUi.text(context),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 840
                      ? 5
                      : MediaQuery.sizeOf(context).width > 600
                      ? 4
                      : 3,
                  childAspectRatio: 1,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 16,
                ),
                itemCount: _filteredServices.length,
                itemBuilder: (c, i) => _buildServiceCard(_filteredServices[i]),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  Widget _buildServiceCard(Service service) => Material(
    color: SanadUi.surface(context),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (service.name == 'More' || service.name == 'Less') {
          setState(() => _showMore = !_showMore);
          return;
        }
        BookingState.reset();
        final job = jobCatalog.firstWhere((j) => j.id == service.jobId);
        BookingState.selectedJobs = [job];
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlaceOrderScreen(selectedJob: job)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: service.imagePath != null
                  ? Image.asset(service.imagePath!, fit: BoxFit.contain)
                  : Icon(
                      service.name == 'More'
                          ? Icons.more_horiz
                          : Icons.expand_less,
                      size: 38,
                      color: SanadUi.muted(context),
                    ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: AppText(
                service.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _buildOrdersPage() {
    return OrdersScreen();
  }

  Widget _buildNotificationsPage() {
    return const ActivityScreen();
  }

  Future<void> _chooseLanguage() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const AppText('Language'),
        children: [
          RadioGroup<String>(
            groupValue: AppLanguage.code.value,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'ar',
                  title: const Text('العربية'),
                ),
                RadioListTile<String>(
                  value: 'en',
                  title: const Text('English'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == null) return;
    try {
      await AppLanguage.select(selected);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(VerificationService.message(error))),
        );
      }
    }
  }

  Widget _buildSettingsPage() {
    return SafeArea(
      child: ListView(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppText(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: WalletState.shared,
            builder: (context, _) => ListTile(
              key: const Key('settings-balance'),
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const AppText('Balance'),
              subtitle: AppText(egp(WalletState.shared.balancePiasters)),
              trailing: IconButton(
                tooltip: tr('Add funds'),
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddFundsScreen()),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const AppText('Language'),
            subtitle: AppText(AppLanguage.isArabic ? 'Arabic' : 'English'),
            onTap: _chooseLanguage,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppState.darkMode,
            builder: (context, enabled, child) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const AppText('Dark mode'),
              value: enabled,
              onChanged: AppState.setDarkMode,
            ),
          ),
          if (!Marketplace.shared.isWorker) ...[
            ListTile(
              key: const Key('settings-become-worker'),
              leading: const Icon(Icons.engineering_outlined),
              title: const AppText('Become a worker'),
              subtitle: Marketplace.shared.workerApplication == null
                  ? null
                  : AppText(
                      '${tr('Application status')}: ${tr(switch (Marketplace.shared.workerApplication!['status']) {
                        'approved' => 'Approved',
                        'rejected' => 'Rejected',
                        _ => 'Pending',
                      })}',
                    ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BecomeWorkerScreen(
                    onNeedHelp: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _buildContactUsPage()),
                    ),
                  ),
                ),
              ),
            ),
            ListTile(
              key: const Key('settings-rate-app'),
              leading: const Icon(Icons.star_outline),
              title: const AppText('Rate the app'),
              subtitle: Marketplace.shared.rating == null
                  ? null
                  : AppText(
                      '${tr('Your rating')}: ${Marketplace.shared.rating!['stars']}/5',
                    ),
              onTap: () async {
                final saved = await showAppRating(context);
                if (saved == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: AppText('Thanks for your feedback!'),
                    ),
                  );
                }
              },
            ),
          ],
          const ServiceTools(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const AppText('Contact us'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _buildContactUsPage()),
            ),
          ),
          // Logout option
          InkWell(
            onTap: () async {
              if (VerificationService.configured) {
                await FirebaseAuth.instance.signOut();
              }
              AppState.clearAccount();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AuthGate()),
                (route) => false,
              );
            },
            hoverColor: Colors.red.withValues(alpha: 0.1),
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: AppText('Logout', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactUsPage() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            // Contact Us content
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppText(
                        'Contact Us',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppText(
                        'If you have any question\nwe are happy to help',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Phone button
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Color(0xFFd7ff00),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.phone, color: Colors.black, size: 30),
                      ),
                      const SizedBox(height: 12),
                      AppText(
                        '+20 123 456 7890',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Email button
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Color(0xFFd7ff00),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.email, color: Colors.black, size: 30),
                      ),
                      const SizedBox(height: 12),
                      AppText(
                        'Sandny.info@gmail.com',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Get Connected
                      AppText(
                        'Get Connected',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Social media icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialIcon(Icons.facebook),
                          const SizedBox(width: 16),
                          _buildSocialIcon(Icons.tag),
                          const SizedBox(width: 16),
                          _buildSocialIcon(Icons.telegram),
                          const SizedBox(width: 16),
                          _buildSocialIcon(Icons.chat),
                          const SizedBox(width: 16),
                          _buildSocialIcon(Icons.code),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
        size: 24,
      ),
    );
  }
}

class Service {
  final String name;
  final String? imagePath;
  final String? jobId;
  Service({required this.name, required this.imagePath, this.jobId});
  Service.fromJob(Job job)
    : name = job.name,
      imagePath = job.imagePath,
      jobId = job.id;
}

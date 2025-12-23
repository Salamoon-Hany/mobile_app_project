import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'welcome.dart';
import 'security_verification.dart';
part '../part4.dart';
part '../part5.dart';

// Public bridge so non-part files can access the shared app state without touching
// the private _MyAppState directly.
class AppState {
  static void setPhoneNumber(String phone) => _MyAppState.setPhoneNumber(phone);
  static String getPhoneNumber() => _MyAppState.getPhoneNumber();
  
  static void setUserName(String name) => _MyAppState.setUserName(name);
  static String getUserName() => _MyAppState.getUserName();
  
  static void setUserEmail(String email) => _MyAppState.setUserEmail(email);
  static String getUserEmail() => _MyAppState.getUserEmail();
  
  static void setUserGender(String gender) => _MyAppState.setUserGender(gender);
  static String getUserGender() => _MyAppState.getUserGender();
  
  static void setUserProfileImagePath(String path) => _MyAppState.setUserProfileImagePath(path);
  static String getUserProfileImagePath() => _MyAppState.getUserProfileImagePath();
  
  static void toggleDarkMode() => _MyAppState.toggleDarkMode();
}

// Global Notifications Manager
class NotificationManager {
  static final List<NotificationModel> _notifications = [];

  static List<NotificationModel> getNotifications() => _notifications;

  static void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
  }

  static void clear() {
    _notifications.clear();
  }
}

// Global Orders Manager
class OrdersManager {
  static final ValueNotifier<List<OrderModel>> _orders = ValueNotifier<List<OrderModel>>([]);

  static ValueNotifier<List<OrderModel>> get notifier => _orders;
  static List<OrderModel> getOrders() => _orders.value;

  static void clear() {
    _orders.value = [];
  }

  static void addOrder({
    required String service,
    required String description,
    required String icon,
  }) {
    final now = DateTime.now();
    final newOrder = OrderModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      service: service,
      description: description,
      status: 'pending',
      icon: icon,
      createdAt: now,
      statusChangedAt: now,
    );
    final updated = List<OrderModel>.from(_orders.value)..insert(0, newOrder);
    _orders.value = updated;

    // Determine behavior based on number of orders added so far
    final count = updated.length;
    if (count == 1) {
      // First invited worker: reject after 20s
      Future.delayed(const Duration(seconds: 20), () {
        final idx = _orders.value.indexWhere((o) => o.id == newOrder.id);
        if (idx != -1) {
          final current = _orders.value[idx];
          final changed = current.copyWith(
            status: 'rejected',
            statusChangedAt: DateTime.now(),
          );
          final list = List<OrderModel>.from(_orders.value);
          list[idx] = changed;
          _orders.value = list;

          NotificationManager.addNotification(
            NotificationModel(
              id: DateTime.now().toString(),
              title: 'Order Rejected',
              description: 'Your ${current.service} order has been rejected.',
              createdAt: DateTime.now(),
              icon: '❌',
              iconColor: Colors.red,
            ),
          );
        }
      });
    } else if (count == 2) {
      // Second invited worker: accept after 20s
      Future.delayed(const Duration(seconds: 20), () {
        final idx = _orders.value.indexWhere((o) => o.id == newOrder.id);
        if (idx != -1) {
          final current = _orders.value[idx];
          final changed = current.copyWith(
            status: 'accepted',
            statusChangedAt: DateTime.now(),
          );
          final list = List<OrderModel>.from(_orders.value);
          list[idx] = changed;
          _orders.value = list;

          NotificationManager.addNotification(
            NotificationModel(
              id: DateTime.now().toString(),
              title: 'Order Accepted',
              description: 'Your ${current.service} order has been accepted!',
              createdAt: DateTime.now(),
              icon: '✅',
              iconColor: Colors.green,
            ),
          );
        }
      });
    } else {
      // Third and subsequent: stay pending
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static bool _isDarkMode = false;
  static String _userPhoneNumber = '';
  static String _userName = '';
  static String _userEmail = '';
  static String _userGender = '';
  static String _userProfileImagePath = '';

  static void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
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

  static void setUserProfileImagePath(String path) {
    _userProfileImagePath = path;
  }

  static String getUserProfileImagePath() {
    return _userProfileImagePath;
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 1.25),
      child: MaterialApp(
        title: 'Service Booking',
        useInheritedMediaQuery: true,
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.yellow),
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.yellow,
            brightness: Brightness.dark,
          ),
          brightness: Brightness.dark,
        ),
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const LogoScreen();
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
  bool _isDarkMode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this page
    setState(() {});
  }

  final List<Service> services = [
    Service(name: 'Builder', imagePath: 'Pics & Icons/Builder.png'),
    Service(name: 'Electrician', imagePath: 'Pics & Icons/Electrician.png'),
    Service(name: 'Plumber', imagePath: 'Pics & Icons/plumber.png'),
    Service(name: 'Carpenter', imagePath: 'Pics & Icons/carpenter.png'),
    Service(name: 'Tiler', imagePath: 'Pics & Icons/tiler.png'),
    Service(name: 'Steel Fixer', imagePath: 'Pics & Icons/steel fixer.png'),
    Service(name: 'Plasterer', imagePath: 'Pics & Icons/plasterer.png'),
    Service(name: 'Repairing', imagePath: 'Pics & Icons/Repairing.png'),
    Service(name: 'More', imagePath: null),
  ];

  final List<Service> moreServices = [
    Service(name: 'Gardener', imagePath: 'Pics & Icons/Gardener.jpeg'),
    Service(name: 'Heavy Equipment', imagePath: 'Pics & Icons/Heavy Equipment Operator.png'),
    Service(name: 'Rubbish', imagePath: 'Pics & Icons/Rubbish Removal.png'),
  ];

  List<Service> get _filteredServices {
    List<Service> allServices = _showMore 
        ? [...services.where((s) => s.name != 'More'), ...moreServices, Service(name: 'Less', imagePath: null)]
        : services;
    
    if (_searchQuery.isEmpty) {
      return allServices;
    }
    return allServices
        .where((service) => service.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        setState(() {}); // Refresh when returning
        return true;
      },
      child: Scaffold(
        drawer: _buildDrawer(),
        body: _selectedIndex == 0
            ? _buildHomePage()
            : _selectedIndex == 1
                ? _buildOrdersPage()
                : _selectedIndex == 2
                    ? _buildNotificationsPage()
                    : _buildSettingsPage(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header with greeting (avatar left, greeting aligned, menu on right)
          Container(
            color: const Color(0xFFd7ff00),
            padding: EdgeInsets.only(
              left: 14,
              right: 12,
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 18,
            ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar slightly smaller
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'Pics & Icons/Working Man.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Greeting placed next to avatar
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hi,',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      AppState.getUserName().isNotEmpty ? AppState.getUserName() : 'there',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Menu icon aligned to top-right
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Builder(
                          builder: (context) => IconButton(
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                            },
                            icon: const Icon(Icons.menu, size: 26),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Search bar positioned between green header and white content
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      hintText: 'I want to hire a...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Icon(Icons.search, color: Colors.grey[600]),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // Services label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Services',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            // Services grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 16,
                ),
                itemCount: _filteredServices.length,
                itemBuilder: (context, index) {
                  return _buildServiceCard(_filteredServices[index]);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
  }

  Widget _buildServiceCard(Service service) {
    return GestureDetector(
      onTap: () {
        if (service.name == 'More' || service.name == 'Less') {
          setState(() {
            _showMore = !_showMore;
          });
        } else {
          // Reset booking state and navigate to place order with selected job
          BookingState.reset();
          final selectedJob = Job(
            id: service.name.toLowerCase(),
            name: service.name,
            imagePath: service.imagePath,
            price: 75.0,
          );
          BookingState.selectedJobs = [selectedJob];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaceOrderScreen(selectedJob: selectedJob),
            ),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: service.imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      service.imagePath!,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    service.name == 'More' ? Icons.more_horiz : Icons.expand_less,
                    size: 40,
                    color: Colors.grey[700],
                  ),
          ),
          const SizedBox(height: 8),
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: service.name == 'Heavy Equipment' ? 1.0 : 1.25,
            ),
            child: Text(
              service.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersPage() {
    return OrdersScreen();
  }

  Widget _buildNotificationsPage() {
    return NotificationsScreen();
  }

  Widget _buildSettingsPage() {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          Divider(),
          // Logout option
          InkWell(
            onTap: () {
              // Navigate back to phone verification screen
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const PhoneVerificationScreen()),
                (route) => false, // Remove all previous routes
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            hoverColor: Colors.red.withOpacity(0.1),
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: TextStyle(color: Colors.red)),
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
                      Text(
                        'Contact Us',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'If you have any question\nwe are happy to help',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
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
                        child: Icon(
                          Icons.phone,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
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
                        child: Icon(
                          Icons.email,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'El.Ostaz.Company@Gmail.com',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Get Connected
                      Text(
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

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Menu header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Divider(),
            // Balance section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Balance :',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '\$${BookingState.userBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9FB700),
                    ),
                  ),
                ],
              ),
            ),
            Divider(),
            // My Profile option
            ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('My Profile'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      phoneNumber: AppState.getPhoneNumber(),
                    ),
                  ),
                );
              },
            ),
            // Contact us option
            ListTile(
              leading: Icon(Icons.phone_outlined),
              title: Text('Contact us'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => _buildContactUsPage()),
                );
              },
            ),
            Spacer(),
            // Dark mode toggle at bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dark mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Switch(
                    value: _isDarkMode,
                    onChanged: (value) {
                      setState(() {
                        _isDarkMode = value;
                        AppState.toggleDarkMode();
                      });
                      // Force rebuild of MyApp
                      (context.findAncestorStateOfType<_MyAppState>())?.setState(() {});
                    },
                    activeThumbColor: Color(0xFFd7ff00),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderModel {
  final String id;
  final String service;
  final String description;
  final String status; // pending, confirmed, completed, cancelled, assigned, accepted
  final String icon;
  final DateTime createdAt;
  final DateTime statusChangedAt;

  OrderModel({
    required this.id,
    required this.service,
    required this.description,
    required this.status,
    required this.icon,
    required this.createdAt,
    required this.statusChangedAt,
  });

  OrderModel copyWith({
    String? status,
    DateTime? statusChangedAt,
  }) => OrderModel(
        id: id,
        service: service,
        description: description,
        status: status ?? this.status,
        icon: icon,
        createdAt: createdAt,
        statusChangedAt: statusChangedAt ?? this.statusChangedAt,
      );
}

class NotificationModel {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final String icon;
  final Color iconColor;

  NotificationModel({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.icon,
    required this.iconColor,
  });

  String get timeAgo => _formatNotificationTime(createdAt);

  static String _formatNotificationTime(DateTime from) {
    final diff = DateTime.now().difference(from);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedTab = 0; // 0 = Pending, 1 = History
  late List<OrderModel> orders;

  @override
  void initState() {
    super.initState();
    orders = OrdersManager.getOrders();
    OrdersManager.notifier.addListener(() {
      if (mounted) {
        setState(() {
          orders = OrdersManager.getOrders();
        });
      }
    });
  }

  List<OrderModel> get pendingOrders =>
      orders.where((o) => o.status == 'pending' || o.status == 'assigned' || o.status == 'confirmed').toList();

    List<OrderModel> get historyOrders =>
      orders.where((o) => o.status == 'completed' || o.status == 'cancelled' || o.status == 'rejected' || o.status == 'accepted').toList();

  @override
  Widget build(BuildContext context) {
    final displayOrders = _selectedTab == 0 ? pendingOrders : historyOrders;

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Orders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Pending',
                          style: TextStyle(
                            fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w600,
                            color: _selectedTab == 0 ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'History',
                          style: TextStyle(
                            fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w600,
                            color: _selectedTab == 1 ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Orders List or Empty State
          displayOrders.isEmpty
              ? Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Orders Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You have no active orders right now',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayOrders.length,
                    itemBuilder: (context, index) {
                      final order = displayOrders[index];
                      return _buildOrderCard(order);
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    Color statusColor;
    String statusLabel;

    switch (order.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'Pending';
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusLabel = 'Confirmed';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusLabel = 'Cancelled';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = 'Rejected';
        break;
      case 'assigned':
        statusColor = Colors.blue;
        statusLabel = 'Assigned';
        break;
      case 'accepted':
        statusColor = Colors.pink;
        statusLabel = 'Accepted';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.service,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatElapsed(order.statusChangedAt),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatElapsed(DateTime from) {
    final diff = DateTime.now().difference(from);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh UI every second to update elapsed time
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),

          Expanded(
            child: NotificationManager.getNotifications().isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_rounded,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You have no notifications right now',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: NotificationManager.getNotifications().length,
                    itemBuilder: (context, index) {
                      final notification = NotificationManager.getNotifications()[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Row(
        children: [
          // Icon with background
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: notification.iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                notification.icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      notification.timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Service {
  final String name;
  final String? imagePath;

  Service({required this.name, required this.imagePath});
}

part of 'part3.dart';

// Part 4: Job Booking & Placement Flow

// Models
class Job {
  final String id;
  final String name;
  final String? imagePath;
  final double price; // $75 per job

  Job({
    required this.id,
    required this.name,
    this.imagePath,
    this.price = 75.0,
  });
}

class Worker {
  final String id;
  final String name;
  final String image;
  final int jobsCompleted;
  final double rating;

  Worker({
    required this.id,
    required this.name,
    required this.image,
    required this.jobsCompleted,
    required this.rating,
  });
}

// Global state for booking
class BookingState {
  static List<Job> selectedJobs = [];
  static String? userLocation;
  static String? locationDetails;
  static String? photoPath;
  static double userBalance = 350.0; // Starting balance

  static void reset() {
    selectedJobs.clear();
    userLocation = null;
    locationDetails = null;
    photoPath = null;
  }

  static double getTotalCost() => selectedJobs.length * 75.0;

  static bool canAfford() => getTotalCost() <= userBalance;
}

// Place Order Screen
class PlaceOrderScreen extends StatefulWidget {
  final Job selectedJob;
  
  const PlaceOrderScreen({super.key, required this.selectedJob});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  final TextEditingController _detailsController = TextEditingController();
  String? _photoPath;
  late List<Job> _jobCatalog;

  @override
  void initState() {
    super.initState();
    _photoPath = BookingState.photoPath;
    _jobCatalog = _buildJobCatalog();
    _ensureInitialJob();
  }

  List<Job> _buildJobCatalog() {
    return [
      Job(id: 'builder', name: 'Builder', imagePath: 'Pics & Icons/Builder.png'),
      Job(id: 'electrician', name: 'Electrician', imagePath: 'Pics & Icons/Electrician.png'),
      Job(id: 'plumber', name: 'Plumber', imagePath: 'Pics & Icons/plumber.png'),
      Job(id: 'carpenter', name: 'Carpenter', imagePath: 'Pics & Icons/carpenter.png'),
      Job(id: 'tiler', name: 'Tiler', imagePath: 'Pics & Icons/tiler.png'),
      Job(id: 'steel_fixer', name: 'Steel Fixer', imagePath: 'Pics & Icons/steel fixer.png'),
      Job(id: 'plasterer', name: 'Plasterer', imagePath: 'Pics & Icons/plasterer.png'),
      Job(id: 'repairing', name: 'Repairing', imagePath: 'Pics & Icons/Repairing.png'),
      Job(id: 'gardener', name: 'Gardener', imagePath: 'Pics & Icons/Gardener.jpeg'),
      Job(id: 'heavy_equipment', name: 'Heavy Equipment', imagePath: 'Pics & Icons/Heavy Equipment Operator.png'),
      Job(id: 'rubbish', name: 'Rubbish', imagePath: 'Pics & Icons/Rubbish Removal.png'),
    ];
  }

  void _ensureInitialJob() {
    if (BookingState.selectedJobs.isEmpty) {
      BookingState.selectedJobs = [widget.selectedJob];
    } else {
      final exists = BookingState.selectedJobs.any((j) => j.id == widget.selectedJob.id);
      if (!exists) BookingState.selectedJobs.insert(0, widget.selectedJob);
    }
  }

  void _addJob(Job job) {
    final exists = BookingState.selectedJobs.any((j) => j.id == job.id);
    if (!exists) {
      setState(() {
        BookingState.selectedJobs.add(job);
      });
    }
  }

  void _removeJob(String jobId) {
    setState(() {
      BookingState.selectedJobs.removeWhere((j) => j.id == jobId);
    });
  }

  void _openJobPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _jobCatalog.length,
            itemBuilder: (context, index) {
              final job = _jobCatalog[index];
              final selected = BookingState.selectedJobs.any((j) => j.id == job.id);
              return GestureDetector(
                onTap: () {
                  _addJob(job);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFd7ff00).withOpacity(0.3) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (job.imagePath != null)
                        Image.asset(job.imagePath!, width: 40, height: 40, fit: BoxFit.contain)
                      else
                        const Icon(Icons.work, size: 32),
                      const SizedBox(height: 6),
                      Flexible(
                        child: Text(
                          job.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text('\$75', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _photoPath = image.path;
        BookingState.photoPath = image.path;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    // Placeholder GPS location
    // In production, use geolocator or location package
    setState(() {
      BookingState.userLocation = '40.7128° N, 74.0060° W'; // NYC
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location set to current location'),
          duration: Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Place order',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Section
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ...BookingState.selectedJobs.map(
                          (job) => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 90,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (job.imagePath != null)
                                      Image.asset(job.imagePath!, width: 42, height: 42, fit: BoxFit.contain)
                                    else
                                      const Icon(Icons.work, size: 36),
                                    const SizedBox(height: 6),
                                    Text(
                                      job.name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text('\$75', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: GestureDetector(
                                  onTap: () => _removeJob(job.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 14, color: Colors.black),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _openJobPicker,
                          child: Container(
                            width: 90,
                            height: 98,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: const Center(
                              child: Icon(Icons.add, size: 28, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Add Address
                    GestureDetector(
                      onTap: _getCurrentLocation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E8FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: Colors.grey[700],
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                BookingState.userLocation ?? 'Add Address',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: BookingState.userLocation != null 
                                      ? Colors.black 
                                      : Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Add details
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Add Details'),
                            content: TextField(
                              controller: _detailsController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'Describe the work needed...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  BookingState.locationDetails = _detailsController.text;
                                  Navigator.pop(context);
                                  setState(() {});
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E8FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_outlined,
                              color: Colors.grey[700],
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Add details',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Add photos
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E8FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.grey[700],
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _photoPath != null ? 'Photo added' : 'Add photos',
                              style: TextStyle(
                                fontSize: 15,
                                color: _photoPath != null ? Colors.black : Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
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

          // Continue Order Button
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  if (BookingState.selectedJobs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one job'),
                          duration: Duration(seconds: 3),
                        ),
                    );
                    return;
                  }
                  if (BookingState.userLocation == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please add address'),
                          duration: Duration(seconds: 3),
                        ),
                    );
                    return;
                  }
                  
                  // Check balance
                  if (!BookingState.canAfford()) {
                    final totalCost = BookingState.getTotalCost();
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '⚠️ Low Balance! Your balance is \$350.00, but this order costs \$$totalCost',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookingPaymentScreen(),
                    ),
                  ).then((_) {
                    // Refresh the page when returning from payment
                    setState(() {});
                  });
                },
                child: const Text(
                  'Continue Order',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Booking Payment Screen
class BookingPaymentScreen extends StatefulWidget {
  const BookingPaymentScreen({super.key});

  @override
  State<BookingPaymentScreen> createState() =>
      _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  bool _paymentDone = false;

  @override
  Widget build(BuildContext context) {
    final totalCost = BookingState.getTotalCost();
    final remainingBalance = BookingState.userBalance - totalCost;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...BookingState.selectedJobs
                        .map(
                          (job) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(job.name),
                                Text('\$${job.price}'),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Cost',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${totalCost.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Balance'),
                        Text('\$${BookingState.userBalance.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Remaining Balance',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${remainingBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: remainingBalance >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pay Button
              if (!_paymentDone)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      setState(() {
                        _paymentDone = true;
                        BookingState.userBalance = remainingBalance;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment successful! Select a worker'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                    child: const Text(
                      'Pay Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

              if (_paymentDone) ...[
                const SizedBox(height: 24),
                const Text(
                  'Select a Worker',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildWorkerList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkerList() {
    final workers = [
      Worker(
        id: '1',
        name: 'Mahmoud Mohammad',
        image: '👨‍🔧',
        jobsCompleted: 100,
        rating: 4.8,
      ),
      Worker(
        id: '2',
        name: 'Abo Faths',
        image: '👨‍🔧',
        jobsCompleted: 50,
        rating: 4.1,
      ),
      Worker(
        id: '3',
        name: 'Hisham Ahmad',
        image: '👨‍🔧',
        jobsCompleted: 100,
        rating: 4.2,
      ),
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: workers.length,
      itemBuilder: (context, index) {
        final worker = workers[index];
        return _buildWorkerCard(worker);
      },
    );
  }

  Widget _buildWorkerCard(Worker worker) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(worker.image, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${worker.jobsCompleted} jobs • ⭐${worker.rating}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFd7ff00),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              _showInviteDialog(worker);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(Worker worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Invite'),
        content: Text(
          'Send job invite to ${worker.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFd7ff00),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Invite sent to ${worker.name}!',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
              // Add notification
              NotificationManager.addNotification(
                NotificationModel(
                  id: DateTime.now().toString(),
                  title: 'Worker Invited',
                  description: 'You sent an invite to ${worker.name}. Waiting for response...',
                  timeAgo: 'just now',
                  icon: '👤',
                  iconColor: Colors.blue,
                ),
              );
              // Create an order tied to this invite
              final serviceName = BookingState.selectedJobs.isNotEmpty
                  ? BookingState.selectedJobs.map((j) => j.name).join(', ')
                  : 'Service Order';
              final desc = BookingState.locationDetails ?? 'Job details pending.';
              // Use first job to select an icon when available
              final icon = BookingState.selectedJobs.isNotEmpty
                  ? _mapServiceToIcon(BookingState.selectedJobs.first.name)
                  : '🛠️';
              OrdersManager.addOrder(
                service: serviceName,
                description: desc,
                icon: icon,
              );
              // Close the dialog and navigate back
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Pop PaymentScreen
              Navigator.of(context).pop(); // Pop PlaceOrderScreen
              BookingState.reset();
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  String _mapServiceToIcon(String name) {
    switch (name.toLowerCase()) {
      case 'electrician':
        return '🔌';
      case 'plumber':
        return '🔧';
      case 'carpenter':
        return '🪚';
      case 'builder':
        return '🏗️';
      case 'tiler':
        return '🧱';
      case 'steel fixer':
        return '🔩';
      case 'plasterer':
        return '🧱';
      case 'repairing':
        return '🛠️';
      case 'gardener':
        return '🌿';
      case 'heavy equipment':
        return '🚧';
      case 'rubbish':
        return '🗑️';
      default:
        return '🛠️';
    }
  }
}

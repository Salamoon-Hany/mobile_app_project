part of 'dashboard.dart';

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
  bool _pickingPhoto = false;
  late List<Job> _jobCatalog;

  @override
  void initState() {
    super.initState();
    _photoPath = BookingState.photoPath;
    _detailsController.text = BookingState.locationDetails ?? '';
    _jobCatalog = _buildJobCatalog();
    _ensureInitialJob();
  }

  List<Job> _buildJobCatalog() => jobCatalog;

  void _ensureInitialJob() {
    if (BookingState.selectedJobs.isEmpty) {
      BookingState.selectedJobs = [widget.selectedJob];
    } else {
      final exists = BookingState.selectedJobs.any(
        (j) => j.id == widget.selectedJob.id,
      );
      if (!exists) BookingState.addJob(widget.selectedJob);
    }
  }

  void _addJob(Job job) {
    if (BookingState.paymentCompleted) return;
    final exists = BookingState.selectedJobs.any((j) => j.id == job.id);
    if (!exists) {
      setState(() {
        BookingState.addJob(job);
      });
    }
  }

  void _removeJob(String jobId) {
    if (BookingState.paymentCompleted) return;
    setState(() {
      BookingState.removeJob(jobId);
    });
  }

  void _openJobPicker() {
    if (BookingState.paymentCompleted) return;
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
              final selected = BookingState.selectedJobs.any(
                (j) => j.id == job.id,
              );
              return GestureDetector(
                onTap: () {
                  _addJob(job);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFd7ff00).withValues(alpha: 0.3)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (job.imagePath != null)
                        Image.asset(
                          job.imagePath!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        )
                      else
                        const Icon(Icons.work, size: 32),
                      const SizedBox(height: 6),
                      Flexible(
                        child: AppText(
                          job.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AppText(
                        egp(job.pricePiasters),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
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
    if (_pickingPhoto || BookingState.paymentCompleted) return;
    _pickingPhoto = true;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (!mounted || image == null) return;
      setState(() {
        _photoPath = image.path;
        BookingState.photoPath = image.path;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Could not choose a photo. Please retry.'),
          ),
        );
      }
    } finally {
      _pickingPhoto = false;
    }
  }

  Future<void> _chooseLocation() async {
    if (BookingState.paymentCompleted) return;
    final location = await Navigator.push<SelectedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (!mounted || location == null) return;
    setState(() {
      BookingState.selectedLocation = location;
      BookingState.userLocation = '${location.label} (${location.coordinates})';
    });
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const AppText(
          'Place order',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
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
                    if (BookingState.paymentCompleted) ...[
                      const AppText(
                        'Payment reserved. Continue your booking or start a new order to release the reserved amount.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Category Section
                    const AppText(
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (job.imagePath != null)
                                      Image.asset(
                                        job.imagePath!,
                                        width: 42,
                                        height: 42,
                                        fit: BoxFit.contain,
                                      )
                                    else
                                      const Icon(Icons.work, size: 36),
                                    const SizedBox(height: 6),
                                    AppText(
                                      job.name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    AppText(
                                      egp(job.pricePiasters),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
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
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.black,
                                    ),
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
                              child: Icon(
                                Icons.add,
                                size: 28,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Add Address
                    GestureDetector(
                      onTap: _chooseLocation,
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
                              child: AppText(
                                BookingState.userLocation ??
                                    'Locate me or search for the area',
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
                      onTap: BookingState.paymentCompleted
                          ? null
                          : () {
                              _detailsController.text =
                                  BookingState.locationDetails ?? '';
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const AppText('Add Details'),
                                  content: TextField(
                                    controller: _detailsController,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      hintText: tr(
                                        'Describe the work needed...',
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const AppText('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        BookingState.locationDetails =
                                            _detailsController.text.trim();
                                        Navigator.pop(context);
                                        setState(() {});
                                      },
                                      child: const AppText('Save'),
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
                            AppText(
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
                            AppText(
                              _photoPath != null ? 'Photo added' : 'Add photos',
                              style: TextStyle(
                                fontSize: 15,
                                color: _photoPath != null
                                    ? Colors.black
                                    : Colors.grey[700],
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
                        content: AppText('Please select at least one job'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                    return;
                  }
                  if (BookingState.selectedLocation == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: AppText('Please add address'),
                        duration: Duration(seconds: 3),
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
                    if (mounted) setState(() {});
                  });
                },
                child: const AppText(
                  'Continue Order',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  late Future<List<Map<String, dynamic>>> _workers;
  String _requestId = Marketplace.id();
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _workers = Marketplace.enabled
        ? Marketplace.shared.workers(
            BookingState.selectedJobs.map((j) => j.id).toList(),
          )
        : Future.value([]);
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const AppText('Confirm order'),
        content: AppText('The amount is reserved until the worker responds.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const AppText('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const AppText('Send Invite'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Marketplace.shared.createOrder(_requestId);
      BookingState.reset();
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop();
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
    final worker = BookingState.selectedWorker;
    return Scaffold(
      appBar: AppBar(
        title: AppText(worker == null ? 'Select a Worker' : 'Order Summary'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (worker == null) ...[
            const AppText(
              'Choose your worker before reviewing and paying for the order.',
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _workers,
              builder: (c, s) {
                if (s.connectionState != ConnectionState.done)
                  return const Center(child: CircularProgressIndicator());
                if (s.hasError)
                  return Column(
                    children: [
                      const AppText(
                        'Could not load workers. Check your connection.',
                      ),
                      TextButton(
                        onPressed: () => setState(_load),
                        child: const AppText('Retry'),
                      ),
                    ],
                  );
                if (s.data!.isEmpty)
                  return Column(
                    children: [
                      const Icon(Icons.person_search, size: 56),
                      const SizedBox(height: 16),
                      const AppText(
                        'No workers are available for these services yet.',
                      ),
                      TextButton(
                        onPressed: () => setState(_load),
                        child: const AppText('Refresh'),
                      ),
                    ],
                  );
                return Column(
                  children: [
                    for (final w in s.data!)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: w['photo'] == null
                                ? null
                                : MemoryImage(
                                    Marketplace.photoBytes(
                                      w['photo'] as String,
                                    )!,
                                  ),
                            child: w['photo'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(w['name'] as String),
                          subtitle: const AppText('Registered worker'),
                          trailing: FilledButton(
                            onPressed: () => setState(
                              () => BookingState.selectWorker(
                                Worker(
                                  id: w['uid'] as String,
                                  name: w['name'] as String,
                                  image: '👨‍🔧',
                                  jobsCompleted: 0,
                                  rating: 0,
                                ),
                              ),
                            ),
                            child: const AppText('Select worker'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(worker.name),
              subtitle: const AppText('Selected worker'),
              trailing: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        BookingState.selectedWorker = null;
                        _requestId = Marketplace.id();
                        _load();
                      }),
                child: const AppText('Change worker'),
              ),
            ),
            const Divider(),
            for (final j in BookingState.selectedJobs)
              ListTile(
                title: AppText(j.name),
                trailing: Text(egp(j.pricePiasters)),
              ),
            ListTile(
              title: const AppText('Total Cost'),
              trailing: Text(egp(BookingState.totalPiasters)),
            ),
            AnimatedBuilder(
              animation: WalletState.shared,
              builder: (c, _) => ListTile(
                title: const AppText('Current Balance'),
                trailing: Text(egp(WalletState.shared.balancePiasters)),
              ),
            ),
            Text(BookingState.selectedLocation?.label ?? ''),
            Text(BookingState.locationDetails ?? ''),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: AppText(_error!),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(),
                    )
                  : const AppText('Pay and send invite'),
            ),
            const AppText('The amount is reserved until the worker responds.'),
          ],
        ],
      ),
    );
  }
}

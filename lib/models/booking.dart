import 'dart:typed_data';

import '../models/selected_location.dart';
import '../models/wallet.dart';

class Job {
  Job({required this.id, required this.name, this.imagePath, double price = 75})
    : pricePiasters = _pricePiasters(price) {
    if (!price.isFinite || pricePiasters <= 0) {
      throw const FormatException('A job must have a positive price.');
    }
  }
  static int _pricePiasters(double price) {
    if (!price.isFinite || price <= 0 || price > 1000000) {
      throw const FormatException(
        'A job must have a positive price of at most 1,000,000 pounds.',
      );
    }
    return (price * 100).round();
  }

  final String id;
  final String name;
  final String? imagePath;
  final int pricePiasters;
  double get price => pricePiasters / 100;
}

/// One catalogue supplies both the home page and the booking picker.
final List<Job> jobCatalog = List.unmodifiable([
  Job(id: 'builder', name: 'Builder', imagePath: 'Pics & Icons/Builder.png'),
  Job(
    id: 'electrician',
    name: 'Electrician',
    imagePath: 'Pics & Icons/Electrician.png',
  ),
  Job(id: 'plumber', name: 'Plumber', imagePath: 'Pics & Icons/plumber.png'),
  Job(
    id: 'carpenter',
    name: 'Carpenter',
    imagePath: 'Pics & Icons/carpenter.png',
  ),
  Job(id: 'tiler', name: 'Tiler', imagePath: 'Pics & Icons/tiler.png'),
  Job(
    id: 'steel_fixer',
    name: 'Steel Fixer',
    imagePath: 'Pics & Icons/steel fixer.png',
  ),
  Job(
    id: 'plasterer',
    name: 'Plasterer',
    imagePath: 'Pics & Icons/plasterer.png',
  ),
  Job(
    id: 'repairing',
    name: 'Repairing',
    imagePath: 'Pics & Icons/Repairing.png',
  ),
  Job(
    id: 'gardener',
    name: 'Gardener',
    imagePath: 'Pics & Icons/Gardener.jpeg',
  ),
  Job(
    id: 'heavy_equipment',
    name: 'Heavy Equipment',
    imagePath: 'Pics & Icons/Heavy Equipment Operator.png',
  ),
  Job(
    id: 'rubbish',
    name: 'Rubbish',
    imagePath: 'Pics & Icons/Rubbish Removal.png',
  ),
]);

class Worker {
  const Worker({
    required this.id,
    required this.name,
    required this.image,
    required this.jobsCompleted,
    required this.rating,
  });
  final String id;
  final String name;
  final String image;
  final int jobsCompleted;
  final double rating;
}

/// A local booking draft. A reservation survives back navigation and is
/// consumed when the invite creates an order, or released when discarded.
class BookingState {
  static List<Job> _jobs = [];
  static List<Job> get selectedJobs => List.unmodifiable(_jobs);
  static set selectedJobs(List<Job> jobs) {
    _requireEditable();
    _jobs = {for (final job in jobs) job.id: job}.values.toList();
  }

  static String? userLocation;
  static SelectedLocation? selectedLocation;
  static String? locationDetails;
  static String? photoPath;
  static Uint8List? photoBytes;
  static Worker? selectedWorker;
  static void selectWorker(Worker worker) {
    _requireEditable();
    selectedWorker = worker;
  }

  static int get reservedPiasters => paymentCompleted ? _reserved : 0;
  static int _reserved = 0;
  static String? _reservationOwner;
  static bool get paymentCompleted =>
      _reserved > 0 && _reservationOwner == WalletState.shared.ownerUid;
  static double get userBalance => WalletState.shared.balancePiasters / 100;
  static set userBalance(double value) =>
      WalletState.shared.setBalance((value * 100).round());
  static int get totalPiasters =>
      _jobs.fold(0, (sum, job) => sum + job.pricePiasters);
  static double getTotalCost() => totalPiasters / 100;
  static bool canAfford() =>
      paymentCompleted ||
      (totalPiasters > 0 &&
          totalPiasters <= WalletState.shared.balancePiasters);

  static void _requireEditable() {
    if (_reserved > 0) {
      throw StateError('Continue your paid booking or start a new order.');
    }
  }

  static void addJob(Job job) {
    _requireEditable();
    if (!_jobs.any((existing) => existing.id == job.id)) _jobs.add(job);
  }

  static void removeJob(String id) {
    _requireEditable();
    _jobs.removeWhere((job) => job.id == id);
  }

  static void reservePayment() {
    if (paymentCompleted) return;
    final wallet = WalletState.shared;
    if (wallet.ownerUid == null ||
        !canAfford() ||
        selectedLocation == null ||
        selectedWorker == null) {
      throw const FormatException(
        'Select jobs, an address and a worker, and add sufficient funds first.',
      );
    }
    _requireEditable();
    _reserved = totalPiasters;
    _reservationOwner = wallet.ownerUid;
    wallet.setBalance(wallet.balancePiasters - _reserved);
  }

  static void consumePayment() {
    if (!paymentCompleted) throw StateError('Complete booking payment first.');
    _reserved = 0;
    _reservationOwner = null;
  }

  static void reset() {
    final refund = _reservationOwner == WalletState.shared.ownerUid
        ? _reserved
        : 0;
    _reserved = 0;
    _reservationOwner = null;
    _jobs = [];
    selectedWorker = null;
    userLocation = null;
    selectedLocation = null;
    locationDetails = null;
    photoPath = null;
    photoBytes = null;
    if (refund > 0) {
      WalletState.shared.setBalance(
        WalletState.shared.balancePiasters + refund,
      );
    }
  }
}

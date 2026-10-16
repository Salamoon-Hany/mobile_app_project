part of 'dashboard.dart';

class OrderModel {
  final String id;
  final String? workerName;
  final int? amount;
  final bool cloud;
  final bool hasPhoto;
  final String? photo;
  final String service;
  final String description;
  final SelectedLocation? location;
  final String
  status; // pending, confirmed, completed, cancelled, assigned, accepted
  final String icon;
  final DateTime createdAt;
  final DateTime statusChangedAt;

  OrderModel({
    required this.id,
    this.workerName,
    this.amount,
    this.cloud = false,
    this.hasPhoto = false,
    this.photo,
    required this.service,
    required this.description,
    this.location,
    required this.status,
    required this.icon,
    required this.createdAt,
    required this.statusChangedAt,
  });

  OrderModel copyWith({String? status, DateTime? statusChangedAt}) =>
      OrderModel(
        id: id,
        workerName: workerName,
        amount: amount,
        cloud: cloud,
        hasPhoto: hasPhoto,
        photo: photo,
        service: service,
        description: description,
        location: location,
        status: status ?? this.status,
        icon: icon,
        createdAt: createdAt,
        statusChangedAt: statusChangedAt ?? this.statusChangedAt,
      );
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
    OrdersManager.notifier.addListener(_onOrdersChanged);
  }

  void _onOrdersChanged() {
    if (mounted) setState(() => orders = OrdersManager.getOrders());
  }

  @override
  void dispose() {
    OrdersManager.notifier.removeListener(_onOrdersChanged);
    super.dispose();
  }

  List<OrderModel> get pendingOrders => orders
      .where(
        (o) =>
            o.status == 'pending' ||
            o.status == 'assigned' ||
            o.status == 'confirmed',
      )
      .toList();

  List<OrderModel> get activeOrders =>
      orders.where((o) => o.status == 'accepted').toList();

  List<OrderModel> get historyOrders => orders
      .where(
        (o) =>
            o.status == 'completed' ||
            o.status == 'archived' ||
            o.status == 'cancelled' ||
            o.status == 'rejected',
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final displayOrders = _selectedTab == 0
        ? pendingOrders
        : _selectedTab == 1
        ? activeOrders
        : historyOrders;

    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            color: SanadUi.surface(context),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AppText(
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
          ),

          SanadTabs(
            labels: const ['Pending', 'Active', 'History'],
            selected: _selectedTab,
            onSelect: (v) => setState(() => _selectedTab = v),
          ),
          const SizedBox(height: 8),
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
                        AppText(
                          'No Orders Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppText(
                          'You have no active orders right now',
                          style: TextStyle(color: Colors.grey[600]),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SanadUi.surface(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AppText(
                  order.service,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SanadStatus(order.status),
            ],
          ),
          const SizedBox(height: 8),
          AppText(
            order.description,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          if (order.location != null) ...[
            AppText(
              '${order.location!.label} (${order.location!.coordinates})',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
          ],
          if (order.hasPhoto)
            TextButton(
              onPressed: () async {
                try {
                  final bytes = await Marketplace.shared.orderPhoto(order.id);
                  if (!mounted || bytes == null) return;
                  showDialog(
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
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: AppText('Could not load the photo. Retry.'),
                      ),
                    );
                  }
                }
              },
              child: const AppText('View Picture'),
            ),
          if (order.cloud)
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderActivityScreen(orderId: order.id),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const AppText('Chat, review & help'),
            ),
          if (order.cloud)
            Builder(
              builder: (c) {
                final o = Marketplace.shared.orders
                    .where((o) => o['id'] == order.id)
                    .firstOrNull;
                return (o?['scheduled_at'] as int? ?? 0) > 0
                    ? Text(localTime(o!['scheduled_at']))
                    : const SizedBox.shrink();
              },
            ),
          if (order.workerName != null) Text(order.workerName!),
          if (order.amount != null) Text(egp(order.amount!)),
          if (order.photo != null)
            Image.memory(Marketplace.photoBytes(order.photo)!, height: 120),
          if (order.cloud &&
              (order.status == 'pending' || order.status == 'accepted'))
            TextButton(
              onPressed: () async {
                final action = order.status == 'accepted'
                    ? 'complete'
                    : 'cancel';
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: AppText(
                      action == 'complete'
                          ? 'Confirm completed work'
                          : 'Cancel order?',
                    ),
                    content: AppText(
                      action == 'complete'
                          ? 'Confirm only after the work is finished. The worker will receive the amount.'
                          : 'The reserved amount will return to your balance.',
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
                if (confirmed != true) return;
                try {
                  await Marketplace.shared.decide(order.id, action);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: AppText(
                          e is FormatException
                              ? e.message
                              : 'Could not sync your account. Check your connection and retry.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: AppText(
                order.status == 'accepted'
                    ? 'Confirm completed work'
                    : 'Cancel order',
              ),
            ),
          Row(
            children: [
              const ReferenceIcon('time', muted: true),
              const SizedBox(width: 4),
              AppText(
                _formatElapsed(order.statusChangedAt),
                style: TextStyle(fontSize: 12, color: SanadUi.muted(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatElapsed(DateTime from) {
    final diff = DateTime.now().difference(from);
    if (diff.inSeconds < 60) {
      return tr('${diff.inSeconds}s ago');
    } else if (diff.inMinutes < 60) {
      return tr('${diff.inMinutes}m ago');
    } else if (diff.inHours < 24) {
      return tr('${diff.inHours}h ago');
    } else {
      return tr('${diff.inDays}d ago');
    }
  }
}

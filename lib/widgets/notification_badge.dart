import 'package:flutter/material.dart';

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({
    super.key,
    required this.count,
    required this.child,
  });
  final int count;
  final Widget child;
  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    backgroundColor: Colors.red.shade700,
    label: Text(count > 99 ? '99+' : '$count'),
    child: child,
  );
}

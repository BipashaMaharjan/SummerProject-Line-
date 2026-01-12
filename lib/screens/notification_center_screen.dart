import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification.dart';
import '../providers/notification_history_provider.dart';
import '../widgets/notification_widgets.dart';

/// Notification center screen
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        actions: [
          Consumer<NotificationHistoryProvider>(
            builder: (context, provider, _) {
              return PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: provider.unreadCount > 0,
                    child: const Text('Mark all as read'),
                    onTap: () {
                      provider.markAllAsRead();
                    },
                  ),
                  PopupMenuItem(
                    enabled: provider.allNotifications.isNotEmpty,
                    child: const Text('Clear all'),
                    onTap: () {
                      _showClearConfirmation(context, provider);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationHistoryProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Statistics bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.blue[50],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatisticItem(
                      label: 'Total',
                      value: provider.allNotifications.length.toString(),
                    ),
                    _StatisticItem(
                      label: 'Unread',
                      value: provider.unreadCount.toString(),
                      color: Colors.red,
                    ),
                    _StatisticItem(
                      label: 'Transfers',
                      value: provider
                          .getByType(NotificationType.tokenTransfer)
                          .length
                          .toString(),
                    ),
                    _StatisticItem(
                      label: 'Status',
                      value: provider
                          .getByType(NotificationType.statusChange)
                          .length
                          .toString(),
                    ),
                  ],
                ),
              ),
              // Filter bar
              const NotificationFilterBar(),
              // Notification list
              Expanded(
                child: NotificationListView(
                  onNotificationTap: (notification) {
                    _showNotificationDetail(context, notification);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showClearConfirmation(
    BuildContext context,
    NotificationHistoryProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications?'),
        content: const Text(
          'This will permanently delete all notifications. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications cleared')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetail(
    BuildContext context,
    TokenNotification notification,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  notification.displayTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  notification.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Token #${notification.tokenNumber}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              notification.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            // Details
            _DetailRow(
              label: 'Time',
              value: notification.formattedTime,
            ),
            if (notification.previousRoomName != null)
              _DetailRow(
                label: 'From',
                value: notification.previousRoomName!,
              ),
            if (notification.newRoomName != null)
              _DetailRow(
                label: 'To',
                value: notification.newRoomName!,
              ),
            if (notification.previousStatus != null)
              _DetailRow(
                label: 'Previous Status',
                value: notification.previousStatus!,
              ),
            if (notification.newStatus != null)
              _DetailRow(
                label: 'New Status',
                value: notification.newStatus!,
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatisticItem({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

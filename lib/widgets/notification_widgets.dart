import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification.dart';
import '../../providers/notification_history_provider.dart';

/// Notification card widget for displaying individual notifications
class NotificationCard extends StatelessWidget {
  final TokenNotification notification;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  const NotificationCard({
    Key? key,
    required this.notification,
    this.onDismiss,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        onDismiss?.call();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: notification.isRead ? 0 : 2,
        color: notification.isRead
            ? Colors.grey[50]
            : Colors.blue.withOpacity(0.05),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Notification type indicator
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getTypeColor(notification.type),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notification.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Main content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                notification.displayTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.grey[700],
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Metadata
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      notification.formattedTime,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(width: 12),
                    if (notification.tokenNumber.isNotEmpty)
                      Chip(
                        label: Text(
                          'Token #${notification.tokenNumber}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.grey[200],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.tokenTransfer:
        return Colors.orange[100]!;
      case NotificationType.statusChange:
        return Colors.blue[100]!;
      case NotificationType.tokenAssigned:
        return Colors.green[100]!;
      case NotificationType.transferredOut:
        return Colors.red[100]!;
      case NotificationType.admin:
        return Colors.purple[100]!;
    }
  }
}

/// Notification list widget with filtering
class NotificationListView extends StatefulWidget {
  final Function(TokenNotification)? onNotificationTap;
  final bool showEmptyState;

  const NotificationListView({
    Key? key,
    this.onNotificationTap,
    this.showEmptyState = true,
  }) : super(key: key);

  @override
  State<NotificationListView> createState() => _NotificationListViewState();
}

class _NotificationListViewState extends State<NotificationListView> {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationHistoryProvider>(
      builder: (context, provider, _) {
        if (!provider.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final notifications = provider.notifications;

        if (notifications.isEmpty && widget.showEmptyState) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.refresh(),
          child: ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationCard(
                notification: notification,
                onTap: () {
                  if (!notification.isRead) {
                    provider.markAsRead(notification.id);
                  }
                  widget.onNotificationTap?.call(notification);
                },
                onDismiss: () {
                  provider.deleteNotification(notification.id);
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Notification filter bar widget
class NotificationFilterBar extends StatelessWidget {
  const NotificationFilterBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationHistoryProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // All filter
                FilterChip(
                  label: const Text('All'),
                  selected: provider.selectedFilter == null,
                  onSelected: (_) => provider.clearTypeFilter(),
                ),
                const SizedBox(width: 8),
                // Transfer filter
                FilterChip(
                  label: const Text('Transfers'),
                  selected:
                      provider.selectedFilter == NotificationType.tokenTransfer,
                  onSelected: (_) => provider
                      .setTypeFilter(NotificationType.tokenTransfer),
                ),
                const SizedBox(width: 8),
                // Status change filter
                FilterChip(
                  label: const Text('Status Changes'),
                  selected:
                      provider.selectedFilter == NotificationType.statusChange,
                  onSelected: (_) => provider
                      .setTypeFilter(NotificationType.statusChange),
                ),
                const SizedBox(width: 8),
                // Assignments filter
                FilterChip(
                  label: const Text('Assigned'),
                  selected:
                      provider.selectedFilter == NotificationType.tokenAssigned,
                  onSelected: (_) => provider
                      .setTypeFilter(NotificationType.tokenAssigned),
                ),
                const SizedBox(width: 8),
                // Unread filter
                FilterChip(
                  label: const Text('Unread Only'),
                  selected: provider.showUnreadOnly,
                  onSelected: (_) => provider.toggleUnreadOnly(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Notification badge widget
class NotificationBadge extends StatelessWidget {
  final Widget child;

  const NotificationBadge({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationHistoryProvider>(
      builder: (context, provider, _) {
        final unreadCount = provider.unreadCount;

        return Stack(
          children: [
            child,
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

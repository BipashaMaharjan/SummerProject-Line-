import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/token.dart';
import '../models/notification.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_history_provider.dart';
import '../services/token_transfer_service.dart';
import '../widgets/notification_widgets.dart';
import '../screens/notification_center_screen.dart';

/// Example: Staff Dashboard with Real-Time Notifications
/// 
/// This is a complete example showing how to integrate the
/// real-time notification system into your staff dashboard.
///
/// Key features:
/// - Real-time token updates
/// - Instant notifications when tokens arrive
/// - Notification center with filtering
/// - Token transfer with automatic notifications
/// - Admin overview
class StaffDashboardWithNotificationsExample extends StatefulWidget {
  const StaffDashboardWithNotificationsExample({Key? key}) : super(key: key);

  @override
  State<StaffDashboardWithNotificationsExample> createState() =>
      _StaffDashboardWithNotificationsExampleState();
}

class _StaffDashboardWithNotificationsExampleState
    extends State<StaffDashboardWithNotificationsExample> {
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  /// Initialize notifications after widget build
  void _initializeNotifications() {
    // Wait for next frame to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final notificationProvider =
          context.read<NotificationHistoryProvider>();

      // Initialize notification provider for current staff
      if (authProvider.user != null) {
        notificationProvider.initialize(authProvider.user!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        elevation: 0,
        actions: [
          // Notification badge
          NotificationBadge(
            child: IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationCenterScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Recent notifications preview
          _buildNotificationsPreview(),
          // Main content
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  /// Build preview of recent notifications
  Widget _buildNotificationsPreview() {
    return Consumer<NotificationHistoryProvider>(
      builder: (context, provider, _) {
        if (!provider.isInitialized || provider.unreadCount == 0) {
          return const SizedBox.shrink();
        }

        final recentUnread = provider.getUnread().take(3).toList();

        return Container(
          color: Colors.blue[50],
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Notifications (${provider.unreadCount} unread)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...recentUnread.map((notification) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${notification.emoji} ${notification.message}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  /// Build main dashboard content
  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Example: Token transfer button
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Token Operations',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _showTransferTokenDialog(context),
                    child: const Text('Transfer Token to Next Room'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showUpdateStatusDialog(context),
                    child: const Text('Update Token Status'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Notification statistics
          _buildStatistics(),
        ],
      ),
    );
  }

  /// Build notification statistics
  Widget _buildStatistics() {
    return Consumer<NotificationHistoryProvider>(
      builder: (context, provider, _) {
        if (!provider.isInitialized) {
          return const SizedBox.shrink();
        }

        final stats = provider.getStatistics();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Statistics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _StatisticChip(
                      label: 'Total',
                      value: stats['total'].toString(),
                    ),
                    _StatisticChip(
                      label: 'Unread',
                      value: stats['unread'].toString(),
                      color: Colors.red,
                    ),
                    _StatisticChip(
                      label: 'Transfers',
                      value: stats['transfers'].toString(),
                    ),
                    _StatisticChip(
                      label: 'Status Changes',
                      value: stats['status_changes'].toString(),
                    ),
                    _StatisticChip(
                      label: 'Assignments',
                      value: stats['assignments'].toString(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show transfer token dialog
  void _showTransferTokenDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Token'),
        content: const Text(
          'This will transfer the token to the next room and automatically notify the assigned staff member.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performTokenTransfer(context);
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  /// Perform token transfer
  Future<void> _performTokenTransfer(BuildContext context) async {
    try {
      final transferService = TokenTransferService();
      await transferService.initialize();

      // Example token data (in real app, get from your state)
      const tokenId = 'token-example-id';
      const tokenNumber = 'A-001';
      const newRoomId = 'room-example-id';
      const newRoomName = 'Registration';
      const previousRoomId = 'room-reception-id';
      const previousRoomName = 'Reception';

      final authProvider = context.read<AuthProvider>();
      final staffId = authProvider.user?.id;

      final success = await transferService.transferTokenToRoom(
        tokenId: tokenId,
        tokenNumber: tokenNumber,
        newRoomId: newRoomId,
        newRoomName: newRoomName,
        previousRoomId: previousRoomId,
        previousRoomName: previousRoomName,
        currentStaffId: staffId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Token transferred successfully!\nNotification sent to next room.'
                  : 'Error transferring token',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show update status dialog
  void _showUpdateStatusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Token Status'),
        content: const Text(
          'This will update the token status and notify the assigned staff member.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performStatusUpdate(context);
            },
            child: const Text('Update to Processing'),
          ),
        ],
      ),
    );
  }

  /// Perform status update
  Future<void> _performStatusUpdate(BuildContext context) async {
    try {
      final transferService = TokenTransferService();
      await transferService.initialize();

      // Example token data (in real app, get from your state)
      const tokenId = 'token-example-id';
      const tokenNumber = 'A-001';

      final authProvider = context.read<AuthProvider>();
      final staffId = authProvider.user?.id;

      final success = await transferService.updateTokenStatus(
        tokenId: tokenId,
        tokenNumber: tokenNumber,
        newStatus: TokenStatus.processing,
        currentRoomName: 'Registration',
        currentStaffId: staffId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Status updated successfully!\nNotification sent to assigned staff.'
                  : 'Error updating status',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Statistics chip widget
class _StatisticChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatisticChip({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? Colors.blue).withOpacity(0.1),
        border: Border.all(color: color ?? Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.blue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Example: Notification Center Integration
/// 
/// Shows how to add the notification center to your app's navigation
class NotificationCenterIntegrationExample {
  // Add this to your Go Router configuration
  static const notificationRoutes = '''
  GoRoute(
    path: '/notifications',
    builder: (context, state) => const NotificationCenterScreen(),
  ),
  ''';

  // Add this to your main app navigation
  static const navigationExample = '''
  // In your bottom navigation or drawer
  ListTile(
    leading: NotificationBadge(
      child: Icon(Icons.notifications),
    ),
    title: Text('Notifications'),
    onTap: () => context.go('/notifications'),
  ),
  ''';
}

/// Example: Real-Time Notification Listener
/// 
/// Shows how to implement a custom notification listener
class NotificationListenerExample extends StatelessWidget {
  const NotificationListenerExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationHistoryProvider>(
      builder: (context, provider, _) {
        return StreamBuilder<TokenNotification>(
          stream: provider.allNotifications.isEmpty
              ? const Stream.empty()
              : _notificationStream(provider),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final notification = snapshot.data!;
              
              // Show toast or in-app notification
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(notification.message),
                    duration: const Duration(seconds: 4),
                  ),
                );
              });
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Stream<TokenNotification> _notificationStream(
    NotificationHistoryProvider provider,
  ) {
    // This would integrate with the notification service's stream
    // For now, returning empty stream as placeholder
    return const Stream.empty();
  }
}

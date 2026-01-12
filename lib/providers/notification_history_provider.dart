import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../services/staff_notification_service.dart';

/// Provider to manage notification history and state
/// Handles real-time updates, filtering, and persistence
class NotificationHistoryProvider extends ChangeNotifier {
  final StaffNotificationService _notificationService =
      StaffNotificationService();

  final List<TokenNotification> _notifications = [];
  StreamSubscription<TokenNotification>? _notificationSubscription;

  bool _isInitialized = false;
  String? _currentStaffId;
  
  // Filtering
  NotificationType? _selectedFilter;
  bool _showUnreadOnly = false;

  // Getters
  List<TokenNotification> get notifications {
    List<TokenNotification> filtered = _notifications;

    // Apply filter by type
    if (_selectedFilter != null) {
      filtered = filtered.where((n) => n.type == _selectedFilter).toList();
    }

    // Apply unread filter
    if (_showUnreadOnly) {
      filtered = filtered.where((n) => !n.isRead).toList();
    }

    return filtered;
  }

  List<TokenNotification> get allNotifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get hasUnread => unreadCount > 0;

  NotificationType? get selectedFilter => _selectedFilter;

  bool get showUnreadOnly => _showUnreadOnly;

  bool get isInitialized => _isInitialized;

  /// Initialize the provider for a staff member
  Future<void> initialize(String staffId) async {
    if (_isInitialized && _currentStaffId == staffId) {
      debugPrint('NotificationHistoryProvider: Already initialized');
      return;
    }

    try {
      debugPrint('NotificationHistoryProvider: Initializing for staff $staffId');
      _currentStaffId = staffId;

      // Initialize notification service
      await _notificationService.initialize(staffId);

      // Subscribe to real-time notification stream
      _subscribeToNotifications();

      // Load initial notifications
      await _loadInitialNotifications();

      _isInitialized = true;
      notifyListeners();
      debugPrint('NotificationHistoryProvider: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationHistoryProvider: Error initializing: $e');
      rethrow;
    }
  }

  /// Subscribe to real-time notifications
  void _subscribeToNotifications() {
    _notificationSubscription?.cancel();

    _notificationSubscription =
        _notificationService.notificationStream.listen((notification) {
      debugPrint(
        'NotificationHistoryProvider: Received notification: ${notification.tokenNumber}',
      );

      // Add to list if not already there
      if (!_notifications.any((n) => n.id == notification.id)) {
        _notifications.insert(0, notification);
      }

      notifyListeners();
    });

    debugPrint('NotificationHistoryProvider: Subscribed to real-time notifications');
  }

  /// Load initial notifications from database
  Future<void> _loadInitialNotifications() async {
    try {
      final recent = await _notificationService.getRecentNotifications(limit: 50);
      _notifications.clear();
      _notifications.addAll(recent);
      
      debugPrint(
        'NotificationHistoryProvider: Loaded ${_notifications.length} notifications',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationHistoryProvider: Error loading notifications: $e');
    }
  }

  /// Refresh notifications from database
  Future<void> refresh() async {
    try {
      debugPrint('NotificationHistoryProvider: Refreshing notifications');
      await _loadInitialNotifications();
    } catch (e) {
      debugPrint('NotificationHistoryProvider: Error refreshing: $e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        _notifications[index].isRead = true;
      }

      await _notificationService.markAsRead(notificationId);
      notifyListeners();

      debugPrint('NotificationHistoryProvider: Marked as read');
    } catch (e) {
      debugPrint('NotificationHistoryProvider: Error marking as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      for (final notification in _notifications) {
        notification.isRead = true;
      }

      await _notificationService.markAllAsRead();
      notifyListeners();

      debugPrint('NotificationHistoryProvider: Marked all as read');
    } catch (e) {
      debugPrint('NotificationHistoryProvider: Error marking all as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      _notifications.removeWhere((n) => n.id == notificationId);
      await _notificationService.deleteNotification(notificationId);
      notifyListeners();

      debugPrint('NotificationHistoryProvider: Deleted notification');
    } catch (e) {
      debugPrint('NotificationHistoryProvider: Error deleting: $e');
    }
  }

  /// Delete all notifications
  Future<void> deleteAll() async {
    try {
      for (final notification in _notifications) {
        await _notificationService.deleteNotification(notification.id);
      }
      
      _notifications.clear();
      notifyListeners();

      debugPrint('NotificationHistoryProvider: Deleted all notifications');
    } catch (e) {
      debugPrint('NotificationHistoryProvider: Error deleting all: $e');
    }
  }

  /// Set filter by notification type
  void setTypeFilter(NotificationType? type) {
    _selectedFilter = type;
    notifyListeners();
    debugPrint('NotificationHistoryProvider: Filter set to ${type?.name}');
  }

  /// Clear type filter
  void clearTypeFilter() {
    _selectedFilter = null;
    notifyListeners();
    debugPrint('NotificationHistoryProvider: Type filter cleared');
  }

  /// Toggle unread only filter
  void toggleUnreadOnly() {
    _showUnreadOnly = !_showUnreadOnly;
    notifyListeners();
    debugPrint(
      'NotificationHistoryProvider: Unread only filter: $_showUnreadOnly',
    );
  }

  /// Get notifications by type
  List<TokenNotification> getByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Get unread notifications
  List<TokenNotification> getUnread() {
    return _notifications.where((n) => !n.isRead).toList();
  }

  /// Get notifications for a specific token
  List<TokenNotification> getForToken(String tokenNumber) {
    return _notifications
        .where((n) => n.tokenNumber == tokenNumber)
        .toList();
  }

  /// Get notifications in date range
  List<TokenNotification> getInDateRange(DateTime start, DateTime end) {
    return _notifications
        .where((n) =>
            n.createdAt.isAfter(start) && n.createdAt.isBefore(end))
        .toList();
  }

  /// Search notifications by message
  List<TokenNotification> search(String query) {
    final lowerQuery = query.toLowerCase();
    return _notifications
        .where((n) =>
            n.message.toLowerCase().contains(lowerQuery) ||
            n.tokenNumber.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Get notification statistics
  Map<String, int> getStatistics() {
    return {
      'total': _notifications.length,
      'unread': unreadCount,
      'transfers': getByType(NotificationType.tokenTransfer).length,
      'status_changes': getByType(NotificationType.statusChange).length,
      'assignments': getByType(NotificationType.tokenAssigned).length,
      'transferred_out': getByType(NotificationType.transferredOut).length,
      'admin': getByType(NotificationType.admin).length,
    };
  }

  /// Cleanup and dispose
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationService.dispose();
    super.dispose();
    debugPrint('NotificationHistoryProvider: Disposed');
  }
}

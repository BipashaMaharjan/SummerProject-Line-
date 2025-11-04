import 'dart:async';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'realtime_tracking_service.dart';
import 'queue_estimation_service.dart';
import '../models/token.dart';

/// Service that integrates real-time tracking with notifications
/// Listens to token status changes and sends appropriate notifications
class RealtimeNotificationService {
  static final RealtimeNotificationService _instance = RealtimeNotificationService._internal();
  factory RealtimeNotificationService() => _instance;
  RealtimeNotificationService._internal();

  final _notificationService = NotificationService();
  final _realtimeService = RealtimeTrackingService();
  final _queueService = QueueEstimationService();
  
  StreamSubscription? _statusSubscription;
  StreamSubscription? _tokenSubscription;
  
  bool _isInitialized = false;
  String? _currentUserId;
  
  // Track tokens we've already notified about to avoid duplicates
  final Set<String> _notifiedTokens = {};
  final Map<String, TokenStatus> _lastKnownStatus = {};
  
  /// Initialize the service for a specific user
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) {
      debugPrint('RealtimeNotificationService: Already initialized for user $userId');
      return;
    }
    
    try {
      debugPrint('RealtimeNotificationService: Initializing for user $userId...');
      _currentUserId = userId;
      
      // Initialize notification service
      await _notificationService.initialize();
      
      // Initialize realtime tracking
      await _realtimeService.initialize();
      
      // Subscribe to status updates
      _subscribeToStatusUpdates(userId);
      
      // Subscribe to token updates for queue position alerts
      _subscribeToTokenUpdates(userId);
      
      _isInitialized = true;
      debugPrint('RealtimeNotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('RealtimeNotificationService: Error initializing: $e');
      rethrow;
    }
  }
  
  /// Subscribe to token status updates
  void _subscribeToStatusUpdates(String userId) {
    _statusSubscription?.cancel();
    
    _statusSubscription = _realtimeService.statusUpdates.listen((update) {
      debugPrint('RealtimeNotificationService: Status update received: ${update.tokenNumber} -> ${update.newStatus}');
      _handleStatusUpdate(update);
    });
    
    debugPrint('RealtimeNotificationService: Subscribed to status updates');
  }
  
  /// Subscribe to token updates for queue position monitoring
  void _subscribeToTokenUpdates(String userId) {
    _tokenSubscription?.cancel();
    
    _tokenSubscription = _realtimeService.subscribeToUserTokens(userId).listen((token) {
      debugPrint('RealtimeNotificationService: Token update received: ${token.tokenNumber}');
      _checkQueuePosition(token);
    });
    
    debugPrint('RealtimeNotificationService: Subscribed to token updates');
  }
  
  /// Handle token status change
  Future<void> _handleStatusUpdate(TokenStatusUpdate update) async {
    try {
      // Avoid duplicate notifications
      final notificationKey = '${update.tokenId}_${update.newStatus.name}';
      if (_notifiedTokens.contains(notificationKey)) {
        debugPrint('RealtimeNotificationService: Already notified about $notificationKey');
        return;
      }
      
      String title = 'Token ${update.tokenNumber}';
      String body = '';
      
      switch (update.newStatus) {
        case TokenStatus.processing:
          if (update.currentRoom != null) {
            title = 'Your Turn! 🎯';
            body = 'Token ${update.tokenNumber} is now being served in ${update.currentRoom}';
          } else {
            title = 'Your Turn! 🎯';
            body = 'Token ${update.tokenNumber} is now being processed';
          }
          break;
          
        case TokenStatus.completed:
          title = 'Service Completed ✅';
          body = 'Token ${update.tokenNumber} has been completed successfully';
          break;
          
        case TokenStatus.hold:
          title = 'Token On Hold ⏸️';
          body = 'Token ${update.tokenNumber} is on hold. Please wait for further instructions.';
          break;
          
        case TokenStatus.rejected:
          title = 'Token Rejected ❌';
          body = 'Token ${update.tokenNumber} was rejected. Please contact staff.';
          break;
          
        case TokenStatus.noShow:
          title = 'Missed Turn ⚠️';
          body = 'Token ${update.tokenNumber} was marked as no-show';
          break;
          
        case TokenStatus.waiting:
          // Don't notify for waiting status (initial state)
          return;
      }
      
      if (body.isNotEmpty) {
        await _notificationService.showNotification(
          id: update.tokenNumber.hashCode,
          title: title,
          body: body,
          payload: 'token:${update.tokenId}',
        );
        
        _notifiedTokens.add(notificationKey);
        _lastKnownStatus[update.tokenId] = update.newStatus;
        
        debugPrint('RealtimeNotificationService: Notification sent for ${update.tokenNumber}');
      }
    } catch (e) {
      debugPrint('RealtimeNotificationService: Error handling status update: $e');
    }
  }
  
  /// Check queue position and send alerts when user is close
  Future<void> _checkQueuePosition(Token token) async {
    try {
      // Only check for waiting tokens
      if (token.status != TokenStatus.waiting) {
        return;
      }
      
      // Get queue info
      final queueInfo = await _queueService.getQueueInfo(token);
      
      // Alert when user is next in line
      if (queueInfo.tokensAhead == 0) {
        final notificationKey = '${token.id}_next_in_line';
        if (!_notifiedTokens.contains(notificationKey)) {
          await _notificationService.showNotification(
            id: '${token.tokenNumber}_next'.hashCode,
            title: 'You\'re Next! 🎯',
            body: 'Token ${token.tokenNumber} - Please be ready, you\'re next in line!',
            payload: 'token:${token.id}',
          );
          
          _notifiedTokens.add(notificationKey);
          debugPrint('RealtimeNotificationService: Next-in-line notification sent for ${token.tokenNumber}');
        }
      }
      
      // Alert when user is close (2-3 people ahead)
      else if (queueInfo.tokensAhead <= 3 && queueInfo.tokensAhead > 0) {
        final notificationKey = '${token.id}_close_${queueInfo.tokensAhead}';
        if (!_notifiedTokens.contains(notificationKey)) {
          await _notificationService.showNotification(
            id: '${token.tokenNumber}_close'.hashCode,
            title: 'Almost Your Turn! ⏰',
            body: 'Token ${token.tokenNumber} - ${queueInfo.tokensAheadText}. Please be ready!',
            payload: 'token:${token.id}',
          );
          
          _notifiedTokens.add(notificationKey);
          debugPrint('RealtimeNotificationService: Close-to-turn notification sent for ${token.tokenNumber}');
        }
      }
    } catch (e) {
      debugPrint('RealtimeNotificationService: Error checking queue position: $e');
    }
  }
  
  /// Manually send a notification for a token status
  Future<void> sendTokenNotification({
    required String tokenNumber,
    required String title,
    required String body,
    String? tokenId,
  }) async {
    try {
      await _notificationService.showNotification(
        id: tokenNumber.hashCode,
        title: title,
        body: body,
        payload: tokenId != null ? 'token:$tokenId' : null,
      );
      
      debugPrint('RealtimeNotificationService: Manual notification sent for $tokenNumber');
    } catch (e) {
      debugPrint('RealtimeNotificationService: Error sending manual notification: $e');
    }
  }
  
  /// Schedule a notification for a specific time
  Future<void> scheduleNotification({
    required String tokenNumber,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? tokenId,
  }) async {
    try {
      await _notificationService.showNotification(
        id: tokenNumber.hashCode,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        payload: tokenId != null ? 'token:$tokenId' : null,
      );
      
      debugPrint('RealtimeNotificationService: Scheduled notification for $tokenNumber at $scheduledTime');
    } catch (e) {
      debugPrint('RealtimeNotificationService: Error scheduling notification: $e');
    }
  }
  
  /// Cancel a specific token notification
  Future<void> cancelTokenNotification(String tokenNumber) async {
    try {
      await _notificationService.cancelNotification(tokenNumber.hashCode);
      debugPrint('RealtimeNotificationService: Cancelled notification for $tokenNumber');
    } catch (e) {
      debugPrint('RealtimeNotificationService: Error cancelling notification: $e');
    }
  }
  
  /// Clear notification history for a token
  void clearTokenNotificationHistory(String tokenId) {
    _notifiedTokens.removeWhere((key) => key.startsWith(tokenId));
    _lastKnownStatus.remove(tokenId);
    debugPrint('RealtimeNotificationService: Cleared notification history for $tokenId');
  }
  
  /// Dispose and clean up
  Future<void> dispose() async {
    debugPrint('RealtimeNotificationService: Disposing...');
    
    await _statusSubscription?.cancel();
    await _tokenSubscription?.cancel();
    
    _notifiedTokens.clear();
    _lastKnownStatus.clear();
    
    _isInitialized = false;
    _currentUserId = null;
    
    debugPrint('RealtimeNotificationService: Disposed');
  }
}

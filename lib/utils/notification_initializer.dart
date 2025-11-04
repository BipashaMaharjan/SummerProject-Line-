import 'package:flutter/foundation.dart';
import '../services/realtime_notification_service.dart';
import '../config/supabase_config.dart';

/// Helper class to initialize notification services
class NotificationInitializer {
  static bool _isInitialized = false;
  
  /// Initialize notification service for the current user
  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('NotificationInitializer: Already initialized');
      return;
    }
    
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      
      if (userId == null) {
        debugPrint('NotificationInitializer: No user logged in, skipping notification setup');
        return;
      }
      
      debugPrint('NotificationInitializer: Initializing for user $userId');
      
      // Initialize the realtime notification service
      await RealtimeNotificationService().initialize(userId);
      
      _isInitialized = true;
      debugPrint('NotificationInitializer: Successfully initialized');
    } catch (e) {
      debugPrint('NotificationInitializer: Error initializing: $e');
      // Don't throw - notifications are not critical for app function
    }
  }
  
  /// Dispose notification services
  static Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      await RealtimeNotificationService().dispose();
      _isInitialized = false;
      debugPrint('NotificationInitializer: Disposed');
    } catch (e) {
      debugPrint('NotificationInitializer: Error disposing: $e');
    }
  }
  
  /// Check if notifications are initialized
  static bool get isInitialized => _isInitialized;
}

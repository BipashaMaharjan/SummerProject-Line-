import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'notification_service.dart';

class TokenUpdateService {
  final SupabaseClient _supabase;
  final NotificationService _notificationService;
  RealtimeChannel? _tokenChannel;
  String? _currentUserId;
  final String _channelName = 'token_updates';

  TokenUpdateService(this._supabase) : _notificationService = NotificationService();

  // Initialize the service with the current user ID
  void initialize(String userId) {
    _currentUserId = userId;
    _setupRealtimeSubscription();
  }

  // Set up real-time subscription to token updates
  void _setupRealtimeSubscription() {
    if (_currentUserId == null) return;

    // Cancel any existing subscription
    _tokenChannel?.unsubscribe();

    try {
      // Create a new channel for this user's token updates
      _tokenChannel = _supabase.channel('${_channelName}_$_currentUserId');

      // Subscribe to token status changes
      _tokenChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tokens',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _currentUserId,
            ),
            callback: (payload) async {
              try {
                final record = payload.newRecord;
                if (record.isEmpty) return;

                final tokenNumber = record['token_number']?.toString();
                final status = record['status']?.toString();
                
                if (tokenNumber != null && status != null) {
                  // Show notification for the status change
                  await _notificationService.handleTokenStatusChange(
                    tokenNumber: tokenNumber,
                    newStatus: status,
                  );

                  // Additional logic based on status
                  if (status.toLowerCase() == 'processing') {
                    await _handleProcessingStatus(record);
                  } else if (status.toLowerCase() == 'completed') {
                    await _handleCompletedStatus(record);
                  } else if (status.toLowerCase() == 'cancelled') {
                    await _handleCancelledStatus(record);
                  }
                }
              } catch (e) {
                print('Error processing token update: $e');
              }
            },
          )
          .subscribe();
    } catch (e) {
      print('Error setting up real-time subscription: $e');
    }
  }

  // Handle processing status
  Future<void> _handleProcessingStatus(Map<String, dynamic> record) async {
    // You can add additional processing logic here
    // For example, update UI or trigger other actions
  }

  // Handle completed status
  Future<void> _handleCompletedStatus(Map<String, dynamic> record) async {
    // You can add additional completion logic here
    // For example, show a thank you message or request feedback
  }

  // Handle cancelled status
  Future<void> _handleCancelledStatus(Map<String, dynamic> record) async {
    // You can add additional cancellation logic here
    // For example, show a message with the cancellation reason
    final reason = record['cancellation_reason'] as String?;
    if (reason != null) {
      await _notificationService.showNotification(
        id: const Uuid().v4().hashCode,
        title: 'Token ${record['token_number']} Cancelled',
        body: 'Reason: $reason',
      );
    }
  }

  // Clean up resources when the service is no longer needed
  void dispose() {
    _tokenChannel?.unsubscribe();
    _tokenChannel = null;
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Service to manage queue status and real-time updates
/// SINGLETON pattern to ensure proper lifecycle management
class QueueStatusService {
  // Singleton instance
  static final QueueStatusService _instance = QueueStatusService._internal();
  factory QueueStatusService() => _instance;
  QueueStatusService._internal();

  final _supabase = SupabaseConfig.client;
  
  // Store stream controllers for each service
  final Map<String, StreamController<QueueStatus>> _controllers = {};
  
  // Store Realtime channels for cleanup
  final Map<String, RealtimeChannel> _channels = {};
  
  // Track active subscriptions count for debugging
  int get activeSubscriptions => _controllers.length;

  /// Unsubscribe from a specific service
  /// Call this when a screen is disposed to prevent memory leaks
  void unsubscribeFromService(String serviceId) {
    debugPrint('QueueStatusService: Unsubscribing from service $serviceId');
    
    // Close stream controller
    if (_controllers.containsKey(serviceId)) {
      final controller = _controllers[serviceId];
      if (controller != null && !controller.isClosed) {
        controller.close();
      }
      _controllers.remove(serviceId);
    }
    
    // Unsubscribe from Realtime channel
    if (_channels.containsKey(serviceId)) {
      _channels[serviceId]?.unsubscribe();
      _channels.remove(serviceId);
    }
    
    debugPrint('QueueStatusService: Active subscriptions: $activeSubscriptions');
  }

  /// Dispose all resources - CRITICAL: Call this to prevent memory leaks!
  /// Should be called when app is closing or user logs out
  void dispose() {
    debugPrint('QueueStatusService: Disposing all resources');
    debugPrint('QueueStatusService: Closing ${_controllers.length} controllers');
    debugPrint('QueueStatusService: Unsubscribing ${_channels.length} channels');
    
    // Close all stream controllers
    for (var controller in _controllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _controllers.clear();
    
    // Unsubscribe all Realtime channels
    for (var channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
    
    debugPrint('QueueStatusService: All resources disposed');
  }

  /// Get the current serving token for a service
  Future<QueueStatus?> getCurrentServingToken(String serviceId) async {
    try {
      final response = await _supabase
          .from('queue_status')
          .select()
          .eq('service_id', serviceId)
          .maybeSingle();

      if (response == null) {
        debugPrint('QueueStatusService: No queue status found for service $serviceId');
        return null;
      }

      return QueueStatus.fromJson(response);
    } catch (e) {
      debugPrint('QueueStatusService: Error getting current token: $e');
      return null;
    }
  }

  /// Subscribe to queue status updates for a service
  /// Returns a stream that emits whenever the serving token changes
  /// IMPORTANT: Call unsubscribeFromService() when done to prevent memory leaks!
  Stream<QueueStatus> subscribeToQueueUpdates(String serviceId) {
    debugPrint('QueueStatusService: Subscribing to service $serviceId');
    
    // Return existing stream if already subscribed
    if (_controllers.containsKey(serviceId)) {
      debugPrint('QueueStatusService: Reusing existing subscription for $serviceId');
      return _controllers[serviceId]!.stream;
    }
    
    // Create new stream controller
    final controller = StreamController<QueueStatus>.broadcast(
      onCancel: () {
        debugPrint('QueueStatusService: Stream cancelled for $serviceId');
        // Auto-cleanup when all listeners are gone
        unsubscribeFromService(serviceId);
      },
    );
    _controllers[serviceId] = controller;
    
    debugPrint('QueueStatusService: Created new subscription for $serviceId');
    debugPrint('QueueStatusService: Total active subscriptions: $activeSubscriptions');
    
    // Load initial status with error handling
    getCurrentServingToken(serviceId).then((status) {
      if (!controller.isClosed) {
        if (status != null) {
          controller.add(status);
        } else {
          // Emit a "no token" status
          controller.add(QueueStatus(
            id: 'empty',
            serviceId: serviceId,
            currentTokenNumber: null,
            updatedAt: DateTime.now(),
          ));
        }
      }
    }).catchError((error) {
      debugPrint('QueueStatusService: Error loading initial status: $error');
      if (!controller.isClosed) {
        // Emit error state instead of crashing
        controller.add(QueueStatus(
          id: 'error',
          serviceId: serviceId,
          currentTokenNumber: null,
          updatedAt: DateTime.now(),
        ));
      }
    });
    
    // Subscribe to real-time updates
    _subscribeToRealtime(serviceId, controller);
    
    return controller.stream;
  }

  /// Subscribe to Realtime updates from Supabase
  void _subscribeToRealtime(
    String serviceId,
    StreamController<QueueStatus> controller,
  ) {
    try {
      // Remove existing channel if any
      if (_channels.containsKey(serviceId)) {
        _channels[serviceId]?.unsubscribe();
      }

      final channel = _supabase.channel('queue_status_$serviceId');
      _channels[serviceId] = channel;

      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'queue_status',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'service_id',
              value: serviceId,
            ),
            callback: (payload) {
              try {
                debugPrint('QueueStatusService: Queue status changed for service $serviceId');
                
                if (payload.newRecord.isNotEmpty) {
                  final status = QueueStatus.fromJson(payload.newRecord);
                  if (!controller.isClosed) {
                    controller.add(status);
                  } else {
                    debugPrint('QueueStatusService: Controller closed, cleaning up channel');
                    unsubscribeFromService(serviceId);
                  }
                }
              } catch (e) {
                debugPrint('QueueStatusService: Error processing realtime update: $e');
              }
            },
          )
          .subscribe();

      debugPrint('QueueStatusService: Subscribed to queue updates for service $serviceId');
    } catch (e) {
      debugPrint('QueueStatusService: Error subscribing to realtime: $e');
    }
  }

  /// Get queue information for a specific token
  Future<TokenQueueInfo?> getQueueInfoForToken(String tokenId) async {
    try {
      final response = await _supabase
          .rpc('get_token_queue_info', params: {'p_token_id': tokenId})
          .select()
          .single();
      
      return TokenQueueInfo.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('QueueStatusService: Error getting queue info: $e');
      return null;
    }
  }
  
  /// Calculate queue position for a token
  Future<int> calculateQueuePosition(String tokenId) async {
    try {
      final response = await _supabase
          .rpc('calculate_queue_position', params: {'p_token_id': tokenId});
      
      return response as int? ?? 0;
    } catch (e) {
      debugPrint('QueueStatusService: Error calculating queue position: $e');
      return 0;
    }
  }
  

}

/// Model for queue status
class QueueStatus {
  final String? id;  // Made nullable to handle empty state
  final String serviceId;
  final String? roomId;
  final String? currentTokenId;
  final String? currentTokenNumber;
  final DateTime? startedAt;
  final DateTime updatedAt;

  QueueStatus({
    this.id,  // Now optional
    required this.serviceId,
    this.roomId,
    this.currentTokenId,
    this.currentTokenNumber,
    this.startedAt,
    required this.updatedAt,
  });

  factory QueueStatus.fromJson(Map<String, dynamic> json) {
    return QueueStatus(
      id: json['id'] as String?,  // Handle null
      serviceId: json['service_id'] as String,
      roomId: json['room_id'] as String?,
      currentTokenId: json['current_token_id'] as String?,
      currentTokenNumber: json['current_token_number'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  String toString() {
    return 'QueueStatus(service: $serviceId, currentToken: $currentTokenNumber)';
  }
}

/// Model for token queue information
class TokenQueueInfo {
  final int queuePosition;
  final String? currentServingToken;
  final int tokensAhead;
  final int estimatedWaitMinutes;

  TokenQueueInfo({
    required this.queuePosition,
    this.currentServingToken,
    required this.tokensAhead,
    required this.estimatedWaitMinutes,
  });

  factory TokenQueueInfo.fromJson(Map<String, dynamic> json) {
    return TokenQueueInfo(
      queuePosition: json['queue_position'] as int? ?? 0,
      currentServingToken: json['current_serving_token'] as String?,
      tokensAhead: json['tokens_ahead'] as int? ?? 0,
      estimatedWaitMinutes: json['estimated_wait_minutes'] as int? ?? 0,
    );
  }

  /// Check if user should be alerted (2 or fewer positions away)
  bool get shouldAlert => queuePosition > 0 && queuePosition <= 2;

  /// Get alert message based on position
  String get alertMessage {
    if (queuePosition == 1) {
      return 'You\'re next! Please be ready.';
    } else if (queuePosition == 2) {
      return 'Your turn is coming soon! 2 tokens ahead.';
    }
    return '';
  }

  @override
  String toString() {
    return 'TokenQueueInfo(position: $queuePosition, serving: $currentServingToken, ahead: $tokensAhead)';
  }
}

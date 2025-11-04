import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/token.dart';
import '../models/room.dart';

/// Real-time tracking service for token status updates
/// Provides live updates using Supabase Realtime subscriptions
class RealtimeTrackingService {
  static final RealtimeTrackingService _instance = RealtimeTrackingService._internal();
  factory RealtimeTrackingService() => _instance;
  RealtimeTrackingService._internal();

  // Subscriptions
  RealtimeChannel? _tokenChannel;
  RealtimeChannel? _roomChannel;
  
  // Stream controllers for broadcasting updates
  final _tokenUpdateController = StreamController<Token>.broadcast();
  final _roomUpdateController = StreamController<Room>.broadcast();
  final _tokenStatusController = StreamController<TokenStatusUpdate>.broadcast();
  
  // Getters for streams
  Stream<Token> get tokenUpdates => _tokenUpdateController.stream;
  Stream<Room> get roomUpdates => _roomUpdateController.stream;
  Stream<TokenStatusUpdate> get statusUpdates => _tokenStatusController.stream;
  
  bool _isInitialized = false;
  
  /// Initialize real-time subscriptions
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('RealtimeTrackingService: Already initialized');
      return;
    }
    
    try {
      debugPrint('RealtimeTrackingService: Initializing...');
      await _subscribeToTokens();
      await _subscribeToRooms();
      _isInitialized = true;
      debugPrint('RealtimeTrackingService: Initialized successfully');
    } catch (e) {
      debugPrint('RealtimeTrackingService: Error initializing: $e');
      rethrow;
    }
  }
  
  /// Subscribe to token table changes
  Future<void> _subscribeToTokens() async {
    try {
      _tokenChannel = SupabaseConfig.client
          .channel('tokens_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tokens',
            callback: (payload) {
              debugPrint('RealtimeTrackingService: Token change detected: ${payload.eventType}');
              _handleTokenChange(payload);
            },
          )
          .subscribe();
      
      debugPrint('RealtimeTrackingService: Subscribed to tokens table');
    } catch (e) {
      debugPrint('RealtimeTrackingService: Error subscribing to tokens: $e');
      rethrow;
    }
  }
  
  /// Subscribe to room table changes
  Future<void> _subscribeToRooms() async {
    try {
      _roomChannel = SupabaseConfig.client
          .channel('rooms_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'rooms',
            callback: (payload) {
              debugPrint('RealtimeTrackingService: Room change detected: ${payload.eventType}');
              _handleRoomChange(payload);
            },
          )
          .subscribe();
      
      debugPrint('RealtimeTrackingService: Subscribed to rooms table');
    } catch (e) {
      debugPrint('RealtimeTrackingService: Error subscribing to rooms: $e');
      rethrow;
    }
  }
  
  /// Handle token change events
  void _handleTokenChange(PostgresChangePayload payload) {
    try {
      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;
      
      if (newRecord.isNotEmpty) {
        final token = Token.fromJson(newRecord);
        _tokenUpdateController.add(token);
        
        // If status changed, emit status update
        if (oldRecord.isNotEmpty) {
          final oldStatus = TokenStatus.values.firstWhere(
            (e) => e.name == oldRecord['status'],
            orElse: () => TokenStatus.waiting,
          );
          
          if (oldStatus != token.status) {
            _tokenStatusController.add(TokenStatusUpdate(
              tokenId: token.id,
              tokenNumber: token.tokenNumber,
              oldStatus: oldStatus,
              newStatus: token.status,
              currentRoom: token.currentRoomName,
              timestamp: DateTime.now(),
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('RealtimeTrackingService: Error handling token change: $e');
    }
  }
  
  /// Handle room change events
  void _handleRoomChange(PostgresChangePayload payload) {
    try {
      final newRecord = payload.newRecord;
      
      if (newRecord.isNotEmpty) {
        final room = Room.fromJson(newRecord);
        _roomUpdateController.add(room);
      }
    } catch (e) {
      debugPrint('RealtimeTrackingService: Error handling room change: $e');
    }
  }
  
  /// Subscribe to specific token updates
  Stream<Token> subscribeToToken(String tokenId) {
    return tokenUpdates.where((token) => token.id == tokenId);
  }
  
  /// Subscribe to specific user's tokens
  Stream<Token> subscribeToUserTokens(String userId) {
    return tokenUpdates.where((token) => token.userId == userId);
  }
  
  /// Subscribe to specific room updates
  Stream<Room> subscribeToRoom(String roomId) {
    return roomUpdates.where((room) => room.id == roomId);
  }
  
  /// Get current token status with room information
  Future<TokenTrackingInfo?> getTokenTrackingInfo(String tokenId) async {
    try {
      debugPrint('RealtimeTrackingService: Fetching tracking info for token: $tokenId');
      
      // Fetch token data
      final tokenResponse = await SupabaseConfig.client
          .from('tokens')
          .select()
          .eq('id', tokenId)
          .single();
      
      debugPrint('RealtimeTrackingService: Token data: $tokenResponse');
      
      // Fetch service data
      String? serviceName;
      try {
        final serviceResponse = await SupabaseConfig.client
            .from('services')
            .select('name')
            .eq('id', tokenResponse['service_id'])
            .single();
        serviceName = serviceResponse['name'];
      } catch (e) {
        debugPrint('RealtimeTrackingService: Error fetching service: $e');
      }
      
      // Fetch room data if available
      String? roomName;
      String? roomNumber;
      if (tokenResponse['current_room_id'] != null) {
        try {
          final roomResponse = await SupabaseConfig.client
              .from('rooms')
              .select('name, room_number')
              .eq('id', tokenResponse['current_room_id'])
              .single();
          roomName = roomResponse['name'];
          roomNumber = roomResponse['room_number'];
        } catch (e) {
          debugPrint('RealtimeTrackingService: Error fetching room: $e');
        }
      }
      
      // Build token with additional data
      final tokenData = Map<String, dynamic>.from(tokenResponse);
      tokenData['service_name'] = serviceName;
      tokenData['current_room_name'] = roomName;
      tokenData['current_room_number'] = roomNumber;
      
      final token = Token.fromJson(tokenData);
      
      debugPrint('RealtimeTrackingService: Token created: ${token.tokenNumber}, status: ${token.status}');
      
      // Get queue position
      final queuePosition = await _calculateQueuePosition(token);
      debugPrint('RealtimeTrackingService: Queue position: $queuePosition');
      
      // Get tokens ahead
      final tokensAhead = await _getTokensAhead(token);
      debugPrint('RealtimeTrackingService: Tokens ahead: $tokensAhead');
      
      return TokenTrackingInfo(
        token: token,
        queuePosition: queuePosition,
        tokensAhead: tokensAhead,
        currentRoomInfo: token.currentRoomId != null
            ? RoomInfo(
                roomId: token.currentRoomId!,
                roomName: roomName ?? 'Unknown',
                roomNumber: roomNumber ?? 'N/A',
              )
            : null,
        lastUpdated: DateTime.now(),
      );
    } catch (e, stackTrace) {
      debugPrint('RealtimeTrackingService: Error getting token tracking info: $e');
      debugPrint('RealtimeTrackingService: Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Calculate queue position for a token
  Future<int> _calculateQueuePosition(Token token) async {
    try {
      final response = await SupabaseConfig.client
          .from('tokens')
          .select('id')
          .eq('service_id', token.serviceId)
          .eq('status', 'waiting')
          .lt('created_at', token.createdAt.toIso8601String())
          .count();
      
      return response.count + 1;
    } catch (e) {
      debugPrint('RealtimeTrackingService: Error calculating queue position: $e');
      return 0;
    }
  }
  
  /// Get number of tokens ahead in queue
  Future<int> _getTokensAhead(Token token) async {
    try {
      final response = await SupabaseConfig.client
          .from('tokens')
          .select('id')
          .eq('service_id', token.serviceId)
          .inFilter('status', ['waiting', 'processing'])
          .lt('created_at', token.createdAt.toIso8601String())
          .count();
      
      return response.count;
    } catch (e) {
      debugPrint('RealtimeTrackingService: Error getting tokens ahead: $e');
      return 0;
    }
  }
  
  /// Dispose and clean up subscriptions
  Future<void> dispose() async {
    debugPrint('RealtimeTrackingService: Disposing...');
    
    await _tokenChannel?.unsubscribe();
    await _roomChannel?.unsubscribe();
    
    await _tokenUpdateController.close();
    await _roomUpdateController.close();
    await _tokenStatusController.close();
    
    _isInitialized = false;
    debugPrint('RealtimeTrackingService: Disposed');
  }
}

/// Token status update event
class TokenStatusUpdate {
  final String tokenId;
  final String tokenNumber;
  final TokenStatus oldStatus;
  final TokenStatus newStatus;
  final String? currentRoom;
  final DateTime timestamp;
  
  TokenStatusUpdate({
    required this.tokenId,
    required this.tokenNumber,
    required this.oldStatus,
    required this.newStatus,
    this.currentRoom,
    required this.timestamp,
  });
  
  String get message {
    if (newStatus == TokenStatus.processing && currentRoom != null) {
      return 'Your token $tokenNumber is now being served in $currentRoom';
    } else if (newStatus == TokenStatus.completed) {
      return 'Your token $tokenNumber has been completed';
    } else if (newStatus == TokenStatus.hold) {
      return 'Your token $tokenNumber is on hold';
    }
    return 'Token $tokenNumber status updated to ${newStatus.displayName}';
  }
}

/// Complete token tracking information
class TokenTrackingInfo {
  final Token token;
  final int queuePosition;
  final int tokensAhead;
  final RoomInfo? currentRoomInfo;
  final DateTime lastUpdated;
  
  TokenTrackingInfo({
    required this.token,
    required this.queuePosition,
    required this.tokensAhead,
    this.currentRoomInfo,
    required this.lastUpdated,
  });
  
  String get statusMessage {
    switch (token.status) {
      case TokenStatus.waiting:
        return 'You are #$queuePosition in queue. $tokensAhead tokens ahead.';
      case TokenStatus.processing:
        return currentRoomInfo != null
            ? 'Being served in ${currentRoomInfo!.roomName} (${currentRoomInfo!.roomNumber})'
            : 'Your token is being processed';
      case TokenStatus.completed:
        return 'Service completed';
      case TokenStatus.hold:
        return 'Token is on hold. Please wait for further instructions.';
      case TokenStatus.rejected:
        return 'Token was rejected. Please contact staff.';
      case TokenStatus.noShow:
        return 'Token marked as no-show';
    }
  }
}

/// Room information
class RoomInfo {
  final String roomId;
  final String roomName;
  final String roomNumber;
  
  RoomInfo({
    required this.roomId,
    required this.roomName,
    required this.roomNumber,
  });
}

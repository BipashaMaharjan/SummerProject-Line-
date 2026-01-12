import 'package:intl/intl.dart';

/// Type of notification
enum NotificationType {
  tokenTransfer,      // Token transferred to another room
  statusChange,       // Token status changed
  tokenAssigned,      // Token assigned to staff member
  transferredOut,     // Token transferred out of staff's queue
  admin,              // Admin specific notification
}

/// Token notification model for real-time notifications
class TokenNotification {
  final String id;
  final String tokenId;
  final String tokenNumber;
  final NotificationType type;
  final String message;
  final String? previousRoomId;
  final String? previousRoomName;
  final String? newRoomId;
  final String? newRoomName;
  final String? previousStatus;
  final String? newStatus;
  final String? staffId; // Staff member receiving the notification
  final DateTime createdAt;
  bool isRead;

  TokenNotification({
    required this.id,
    required this.tokenId,
    required this.tokenNumber,
    required this.type,
    required this.message,
    this.previousRoomId,
    this.previousRoomName,
    this.newRoomId,
    this.newRoomName,
    this.previousStatus,
    this.newStatus,
    this.staffId,
    required this.createdAt,
    this.isRead = false,
  });

  /// Factory constructor from JSON (Supabase)
  factory TokenNotification.fromJson(Map<String, dynamic> json) {
    return TokenNotification(
      id: json['id'] as String,
      tokenId: json['token_id'] as String,
      tokenNumber: json['token_number'] as String? ?? 'N/A',
      type: _parseNotificationType(json['type'] as String?),
      message: json['message'] as String? ?? '',
      previousRoomId: json['previous_room_id'] as String?,
      previousRoomName: json['previous_room_name'] as String?,
      newRoomId: json['new_room_id'] as String?,
      newRoomName: json['new_room_name'] as String?,
      previousStatus: json['previous_status'] as String?,
      newStatus: json['new_status'] as String?,
      staffId: json['staff_id'] as String?,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  /// Convert to JSON for database
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token_id': tokenId,
      'token_number': tokenNumber,
      'type': type.name,
      'message': message,
      'previous_room_id': previousRoomId,
      'previous_room_name': previousRoomName,
      'new_room_id': newRoomId,
      'new_room_name': newRoomName,
      'previous_status': previousStatus,
      'new_status': newStatus,
      'staff_id': staffId,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  /// Helper to parse notification type
  static NotificationType _parseNotificationType(String? type) {
    if (type == null) return NotificationType.statusChange;
    
    try {
      return NotificationType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => NotificationType.statusChange,
      );
    } catch (e) {
      return NotificationType.statusChange;
    }
  }

  /// Format time for display
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(createdAt);
    }
  }

  /// Get emoji based on notification type
  String get emoji {
    switch (type) {
      case NotificationType.tokenTransfer:
        return '→';
      case NotificationType.statusChange:
        return '🔄';
      case NotificationType.tokenAssigned:
        return '✅';
      case NotificationType.transferredOut:
        return '➡️';
      case NotificationType.admin:
        return '👨‍💼';
    }
  }

  /// Get display title based on type
  String get displayTitle {
    switch (type) {
      case NotificationType.tokenTransfer:
        return 'Token Transferred';
      case NotificationType.statusChange:
        return 'Status Changed';
      case NotificationType.tokenAssigned:
        return 'Token Assigned';
      case NotificationType.transferredOut:
        return 'Token Transferred Out';
      case NotificationType.admin:
        return 'Admin Notification';
    }
  }

  @override
  String toString() {
    return 'TokenNotification(id: $id, token: $tokenNumber, type: ${type.name}, message: $message)';
  }
}

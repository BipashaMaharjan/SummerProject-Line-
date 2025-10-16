import 'package:flutter/material.dart';
import 'service.dart';

class Token {
  final String id;
  final String tokenNumber; // Changed from int to String to match database
  final String userId;
  final String serviceId;
  final TokenStatus status;
  final String? currentRoomId;
  final int currentSequence;
  final int priority;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? startedAt;
  final DateTime? scheduledDate;
  final DateTime? bookedAt; // Added to match database schema

  // Additional fields from joins
  final String? userName;
  final String? userPhone;
  final String? serviceName;
  final ServiceType? serviceType;
  final String? currentRoomName;
  final String? currentRoomNumber;
  final int? queuePosition;

  Token({
    required this.id,
    required this.tokenNumber,
    required this.userId,
    required this.serviceId,
    required this.status,
    this.currentRoomId,
    required this.currentSequence,
    required this.priority,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.startedAt,
    this.scheduledDate,
    this.bookedAt,
    this.userName,
    this.userPhone,
    this.serviceName,
    this.serviceType,
    this.currentRoomName,
    this.currentRoomNumber,
    this.queuePosition,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      id: json['id'],
      tokenNumber: json['token_number']?.toString() ?? json['id'].toString(), // Handle both string and fallback
      userId: json['user_id'],
      serviceId: json['service_id'],
      status: TokenStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TokenStatus.waiting,
      ),
      currentRoomId: json['current_room_id'],
      currentSequence: json['current_sequence'] ?? 1,
      priority: json['priority'] ?? 0,
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at'] ?? json['booked_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['created_at'] ?? json['booked_at'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'])
          : null,
      bookedAt: json['booked_at'] != null
          ? DateTime.parse(json['booked_at'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      userName: json['user_name'],
      userPhone: json['user_phone'],
      serviceName: json['service_name'],
      serviceType: json['service_type'] != null
          ? ServiceType.values.firstWhere(
              (e) => e.name == json['service_type'],
              orElse: () => ServiceType.licenseRenewal,
            )
          : null,
      currentRoomName: json['current_room_name'],
      currentRoomNumber: json['current_room_number'],
      queuePosition: json['queue_position'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token_number': tokenNumber,
      'user_id': userId,
      'service_id': serviceId,
      'status': status.name,
      'current_room_id': currentRoomId,
      'current_sequence': currentSequence,
      'priority': priority,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
    };
  }

  // Generate display token with dash notation (e.g., "L001-1")
  String get displayToken => '$tokenNumber-$currentSequence';

  // Get status color for UI
  Color get statusColor {
    switch (status) {
      case TokenStatus.waiting:
        return Colors.orange;
      case TokenStatus.hold:
        return Colors.red;
      case TokenStatus.processing:
        return Colors.blue;
      case TokenStatus.completed:
        return Colors.green;
      case TokenStatus.rejected:
        return Colors.red.shade800;
      case TokenStatus.noShow:
        return Colors.grey;
    }
  }

  // Get status display text
  String get statusText {
    switch (status) {
      case TokenStatus.waiting:
        return 'Waiting';
      case TokenStatus.hold:
        return 'On Hold';
      case TokenStatus.processing:
        return 'In Progress';
      case TokenStatus.completed:
        return 'Completed';
      case TokenStatus.rejected:
        return 'Rejected';
      case TokenStatus.noShow:
        return 'No Show';
    }
  }

  Token copyWith({
    String? id,
    String? tokenNumber,
    String? userId,
    String? serviceId,
    TokenStatus? status,
    String? currentRoomId,
    int? currentSequence,
    int? priority,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? startedAt,
    DateTime? bookedAt,
    String? userName,
    String? userPhone,
    String? serviceName,
    ServiceType? serviceType,
    String? currentRoomName,
    String? currentRoomNumber,
  }) {
    return Token(
      id: id ?? this.id,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      userId: userId ?? this.userId,
      serviceId: serviceId ?? this.serviceId,
      status: status ?? this.status,
      currentRoomId: currentRoomId ?? this.currentRoomId,
      currentSequence: currentSequence ?? this.currentSequence,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      startedAt: startedAt ?? this.startedAt,
      bookedAt: bookedAt ?? this.bookedAt,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      serviceName: serviceName ?? this.serviceName,
      serviceType: serviceType ?? this.serviceType,
      currentRoomName: currentRoomName ?? this.currentRoomName,
      currentRoomNumber: currentRoomNumber ?? this.currentRoomNumber,
      queuePosition: queuePosition ?? queuePosition,
    );
  }
}

enum TokenStatus {
  waiting,
  hold,
  processing,
  completed,
  rejected,
  noShow,
}

extension TokenStatusExtension on TokenStatus {
  String get displayName {
    switch (this) {
      case TokenStatus.waiting:
        return 'Waiting';
      case TokenStatus.hold:
        return 'On Hold';
      case TokenStatus.processing:
        return 'In Progress';
      case TokenStatus.completed:
        return 'Completed';
      case TokenStatus.rejected:
        return 'Rejected';
      case TokenStatus.noShow:
        return 'No Show';
    }
  }
  
  bool get isActive => this == TokenStatus.waiting || 
                      this == TokenStatus.hold || 
                      this == TokenStatus.processing;
}

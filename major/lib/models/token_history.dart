import 'token.dart';

class TokenHistory {
  final String id;
  final String tokenId;
  final String? roomId;
  final String? staffId;
  final TokenStatus status;
  final int sequenceNumber;
  final String? action;
  final String? notes;
  final DateTime createdAt;

  // Additional fields from joins
  final String? roomName;
  final String? roomNumber;
  final String? staffName;

  TokenHistory({
    required this.id,
    required this.tokenId,
    this.roomId,
    this.staffId,
    required this.status,
    required this.sequenceNumber,
    this.action,
    this.notes,
    required this.createdAt,
    this.roomName,
    this.roomNumber,
    this.staffName,
  });

  factory TokenHistory.fromJson(Map<String, dynamic> json) {
    return TokenHistory(
      id: json['id'],
      tokenId: json['token_id'],
      roomId: json['room_id'],
      staffId: json['staff_id'],
      status: TokenStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TokenStatus.waiting,
      ),
      sequenceNumber: json['sequence_number'],
      action: json['action'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      roomName: json['room_name'],
      roomNumber: json['room_number'],
      staffName: json['staff_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token_id': tokenId,
      'room_id': roomId,
      'staff_id': staffId,
      'status': status.name,
      'sequence_number': sequenceNumber,
      'action': action,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get actionText {
    switch (action) {
      case 'picked':
        return 'Token picked up';
      case 'transferred':
        return 'Transferred to next room';
      case 'completed':
        return 'Service completed';
      case 'rejected':
        return 'Token rejected';
      case 'hold':
        return 'Put on hold';
      default:
        return action ?? 'Status updated';
    }
  }
}

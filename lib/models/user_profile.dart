class UserProfile {
  final String id;
  final String? fullName;
  final String? phone;
  final UserRole role;
  final bool isActive;
  final String? assignedRoomId; // For staff - their assigned room
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.fullName,
    this.phone,
    required this.role,
    required this.isActive,
    this.assignedRoomId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      fullName: json['full_name'],
      phone: json['phone'],
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.customer,
      ),
      isActive: json['is_active'] ?? true,
      assignedRoomId: json['assigned_room_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'role': role.name,
      'is_active': isActive,
      'assigned_room_id': assignedRoomId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? phone,
    UserRole? role,
    bool? isActive,
    String? assignedRoomId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      assignedRoomId: assignedRoomId ?? this.assignedRoomId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum UserRole {
  customer,
  staff,
  admin,
}

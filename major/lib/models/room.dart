class Room {
  final String id;
  final String name;
  final String roomNumber;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  Room({
    required this.id,
    required this.name,
    required this.roomNumber,
    this.description,
    required this.isActive,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      name: json['name'],
      roomNumber: json['room_number'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'room_number': roomNumber,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

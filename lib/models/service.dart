class Service {
  final String id;
  final String name;
  final ServiceType type;
  final String? description;
  final int estimatedTimeMinutes;
  final bool isActive;
  final DateTime createdAt;

  Service({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    required this.estimatedTimeMinutes,
    required this.isActive,
    required this.createdAt,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'].toString(), // Convert to string to handle int IDs
      name: json['name'].toString(),
      type: ServiceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => _getServiceTypeFromName(json['name']?.toString() ?? ''),
      ),
      description: json['description']?.toString(),
      estimatedTimeMinutes: json['estimated_duration'] ?? json['estimated_time_minutes'] ?? 30,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'description': description,
      'estimated_time_minutes': estimatedTimeMinutes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum ServiceType {
  licenseRenewal('license_renewal'),
  newLicense('new_license');

  const ServiceType(this.value);
  final String value;

  String get name => value;
}

// Helper function to determine service type from name when type column is missing
ServiceType _getServiceTypeFromName(String name) {
  final lowerName = name.toLowerCase();
  if (lowerName.contains('renewal')) {
    return ServiceType.licenseRenewal;
  } else if (lowerName.contains('new') && lowerName.contains('license')) {
    return ServiceType.newLicense;
  }
  return ServiceType.licenseRenewal; // Default fallback
}

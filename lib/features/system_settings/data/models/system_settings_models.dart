class GlobalSettingsModel {
  final double platformCommissionRate;
  final double taxRate;
  final bool isMaintenanceMode;
  final int maxDispatchRadiusKm;
  final String supportEmail;

  GlobalSettingsModel({
    required this.platformCommissionRate,
    required this.taxRate,
    required this.isMaintenanceMode,
    required this.maxDispatchRadiusKm,
    required this.supportEmail,
  });

  factory GlobalSettingsModel.fromJson(Map<String, dynamic> json) {
    return GlobalSettingsModel(
      platformCommissionRate: (json['platformCommissionRate'] ?? 0.20)
          .toDouble(),
      taxRate: (json['taxRate'] ?? 0.13).toDouble(),
      isMaintenanceMode: json['isMaintenanceMode'] ?? false,
      maxDispatchRadiusKm: json['maxDispatchRadiusKm'] ?? 50,
      supportEmail: json['supportEmail'] ?? 'support@company.com',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platformCommissionRate': platformCommissionRate,
      'taxRate': taxRate,
      'isMaintenanceMode': isMaintenanceMode,
      'maxDispatchRadiusKm': maxDispatchRadiusKm,
      'supportEmail': supportEmail,
    };
  }
}

class StaffUserModel {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final List<String> permissions;

  StaffUserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.permissions,
  });

  factory StaffUserModel.fromJson(Map<String, dynamic> json) {
    return StaffUserModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? 'Unknown',
      email: json['email'] ?? 'No Email',
      role: json['role'] ?? 'Dispatcher',
      isActive: json['isActive'] ?? true, // Default to true if missing
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }

  bool hasPermission(String permission) => permissions.contains(permission);
}

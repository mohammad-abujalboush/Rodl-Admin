class GlobalSettingsModel {
  final double b2cCommissionRate;
  final double b2bCommissionRate;
  final double driverPayoutRate;
  final double paymentGatewayFee;
  final double taxRate;
  final bool isMaintenanceMode;
  final int maxDispatchRadiusKm;
  final String supportEmail;

  GlobalSettingsModel({
    required this.b2cCommissionRate,
    required this.b2bCommissionRate,
    required this.driverPayoutRate,
    required this.paymentGatewayFee,
    required this.taxRate,
    required this.isMaintenanceMode,
    required this.maxDispatchRadiusKm,
    required this.supportEmail,
  });

  factory GlobalSettingsModel.fromJson(Map<String, dynamic> json) {
    return GlobalSettingsModel(
      b2cCommissionRate: (json['b2cCommissionRate'] ?? 0.20).toDouble(),
      b2bCommissionRate: (json['b2bCommissionRate'] ?? 0.15).toDouble(),
      driverPayoutRate: (json['driverPayoutRate'] ?? 0.80).toDouble(),
      paymentGatewayFee: (json['paymentGatewayFee'] ?? 0.029).toDouble(),
      taxRate: (json['taxRate'] ?? 0.13).toDouble(),
      isMaintenanceMode: json['isMaintenanceMode'] ?? false,
      maxDispatchRadiusKm: json['maxDispatchRadiusKm'] ?? 50,
      supportEmail: json['supportEmail'] ?? 'support@rodl.ca',
    );
  }

  Map<String, dynamic> toJson() => {
    'b2cCommissionRate': b2cCommissionRate,
    'b2bCommissionRate': b2bCommissionRate,
    'driverPayoutRate': driverPayoutRate,
    'paymentGatewayFee': paymentGatewayFee,
    'taxRate': taxRate,
    'isMaintenanceMode': isMaintenanceMode,
    'maxDispatchRadiusKm': maxDispatchRadiusKm,
    'supportEmail': supportEmail,
  };
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
      id: json['id'].toString(),
      fullName: json['fullName'] ?? 'Unknown',
      email: json['email'] ?? '',
      role: json['role'] ?? 'Employee',
      isActive: json['isActive'] ?? true,
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }
}

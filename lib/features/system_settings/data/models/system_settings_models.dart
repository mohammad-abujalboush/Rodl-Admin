class GlobalSettingsModel {
  // Part 1: Financial Configuration
  final double driverPayoutRatio;
  final double platformCommissionRate;
  final double taxRate;
  final double gatewayFeePercentage;
  final double gatewayFeeFixed;
  final double b2bCommissionRate;
  final double b2bCorporateCommissionRate;

  // Part 2: Cancellation Penalty Tiers
  final double defaultTier2EnRouteCancellationFee;
  final double defaultTier3ArrivedCancellationFee;

  // Part 3: Operational Controls
  final bool isMaintenanceMode;
  final int maxDispatchRadiusKm;
  final String supportEmail;

  GlobalSettingsModel({
    required this.driverPayoutRatio,
    required this.platformCommissionRate,
    required this.taxRate,
    required this.gatewayFeePercentage,
    required this.gatewayFeeFixed,
    required this.b2bCommissionRate,
    required this.b2bCorporateCommissionRate,
    required this.defaultTier2EnRouteCancellationFee,
    required this.defaultTier3ArrivedCancellationFee,
    required this.isMaintenanceMode,
    required this.maxDispatchRadiusKm,
    required this.supportEmail,
  });

  factory GlobalSettingsModel.fromJson(Map<String, dynamic> json) {
    return GlobalSettingsModel(
      driverPayoutRatio:
          ((json['driverPayoutRatio'] ??
                      json['DriverPayoutRatio'] ??
                      json['driverPayoutRate'] ??
                      0.80)
                  as num)
              .toDouble(),
      platformCommissionRate:
          ((json['platformCommissionRate'] ??
                      json['PlatformCommissionRate'] ??
                      json['b2cCommissionRate'] ??
                      0.20)
                  as num)
              .toDouble(),
      taxRate: ((json['taxRate'] ?? json['TaxRate'] ?? 0.05) as num).toDouble(),
      gatewayFeePercentage:
          ((json['gatewayFeePercentage'] ??
                      json['GatewayFeePercentage'] ??
                      json['paymentGatewayFee'] ??
                      0.029)
                  as num)
              .toDouble(),
      gatewayFeeFixed:
          ((json['gatewayFeeFixed'] ?? json['GatewayFeeFixed'] ?? 0.30) as num)
              .toDouble(),
      b2bCommissionRate:
          ((json['b2bCommissionRate'] ?? json['B2bCommissionRate'] ?? 0.10)
                  as num)
              .toDouble(),
      b2bCorporateCommissionRate:
          ((json['b2bCorporateCommissionRate'] ??
                      json['B2bCorporateCommissionRate'] ??
                      0.08)
                  as num)
              .toDouble(),
      defaultTier2EnRouteCancellationFee:
          ((json['defaultTier2EnRouteCancellationFee'] ??
                      json['DefaultTier2EnRouteCancellationFee'] ??
                      15.0)
                  as num)
              .toDouble(),
      defaultTier3ArrivedCancellationFee:
          ((json['defaultTier3ArrivedCancellationFee'] ??
                      json['DefaultTier3ArrivedCancellationFee'] ??
                      30.0)
                  as num)
              .toDouble(),
      isMaintenanceMode:
          json['isMaintenanceMode'] ?? json['IsMaintenanceMode'] ?? false,
      maxDispatchRadiusKm:
          ((json['maxDispatchRadiusKm'] ?? json['MaxDispatchRadiusKm'] ?? 50)
                  as num)
              .toInt(),
      supportEmail:
          (json['supportEmail'] ?? json['SupportEmail'] ?? 'support@rodl.app')
              .toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'driverPayoutRatio': driverPayoutRatio,
    'platformCommissionRate': platformCommissionRate,
    'taxRate': taxRate,
    'gatewayFeePercentage': gatewayFeePercentage,
    'gatewayFeeFixed': gatewayFeeFixed,
    'b2bCommissionRate': b2bCommissionRate,
    'b2bCorporateCommissionRate': b2bCorporateCommissionRate,
    'defaultTier2EnRouteCancellationFee': defaultTier2EnRouteCancellationFee,
    'defaultTier3ArrivedCancellationFee': defaultTier3ArrivedCancellationFee,
    'isMaintenanceMode': isMaintenanceMode,
    'maxDispatchRadiusKm': maxDispatchRadiusKm,
    'supportEmail': supportEmail,
  };
}

// Part 4: Regional Tax Model
class RegionalTaxRateModel {
  final String provinceCode;
  final String regionName;
  final double taxRate;
  final bool isActive;

  RegionalTaxRateModel({
    required this.provinceCode,
    required this.regionName,
    required this.taxRate,
    required this.isActive,
  });

  factory RegionalTaxRateModel.fromJson(Map<String, dynamic> json) {
    return RegionalTaxRateModel(
      provinceCode: (json['provinceCode'] ?? json['ProvinceCode'] ?? '')
          .toString(),
      regionName: (json['regionName'] ?? json['RegionName'] ?? '').toString(),
      taxRate: ((json['taxRate'] ?? json['TaxRate'] ?? 0.05) as num).toDouble(),
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'provinceCode': provinceCode,
    'regionName': regionName,
    'taxRate': taxRate,
    'isActive': isActive,
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

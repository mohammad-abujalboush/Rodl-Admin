class PricingRuleModel {
  final String id;
  final String ruleName;
  final String description;
  final int serviceType;
  final double baseFare;
  final double includedDistanceKm;
  final double ratePerKm;
  final double hourlyRate;
  final double recoveryBaseRate;
  final int recoveryIncludedMinutes;
  final double recoveryRatePerMinute;
  final int freeWaitingTimeMinutes;
  final double waitingRatePerMinute;
  final double cancellationFee;

  // --- UPGRADED: Surcharges are now optional (nullable) ---
  final double? afterHoursSurcharge;
  final double? holidaySurcharge;
  final double? duallySurcharge;
  final double? multiTruckSurcharge;
  final double? manualAdditionSurcharge;

  final bool isActive;

  PricingRuleModel({
    required this.id,
    required this.ruleName,
    required this.description,
    required this.serviceType,
    required this.baseFare,
    required this.includedDistanceKm,
    required this.ratePerKm,
    required this.hourlyRate,
    required this.recoveryBaseRate,
    required this.recoveryIncludedMinutes,
    required this.recoveryRatePerMinute,
    required this.freeWaitingTimeMinutes,
    required this.waitingRatePerMinute,
    required this.cancellationFee,
    this.afterHoursSurcharge,
    this.holidaySurcharge,
    this.duallySurcharge,
    this.multiTruckSurcharge,
    this.manualAdditionSurcharge,
    required this.isActive,
  });

  factory PricingRuleModel.fromJson(Map<String, dynamic> json) {
    return PricingRuleModel(
      id: json['id'] ?? '',
      ruleName: json['ruleName'] ?? 'Unnamed Rule',
      description: json['description'] ?? '',
      serviceType: json['serviceType'] ?? 1,
      baseFare: (json['baseFare'] ?? 0).toDouble(),
      includedDistanceKm: (json['includedDistanceKm'] ?? 0).toDouble(),
      ratePerKm: (json['ratePerKm'] ?? 0).toDouble(),
      hourlyRate: (json['hourlyRate'] ?? 0).toDouble(),
      recoveryBaseRate: (json['recoveryBaseRate'] ?? 0).toDouble(),
      recoveryIncludedMinutes: json['recoveryIncludedMinutes'] ?? 0,
      recoveryRatePerMinute: (json['recoveryRatePerMinute'] ?? 0).toDouble(),
      freeWaitingTimeMinutes: json['freeWaitingTimeMinutes'] ?? 0,
      waitingRatePerMinute: (json['waitingRatePerMinute'] ?? 0).toDouble(),
      cancellationFee: (json['cancellationFee'] ?? 0).toDouble(),
      afterHoursSurcharge: json['afterHoursSurcharge'] != null
          ? (json['afterHoursSurcharge'] as num).toDouble()
          : null,
      holidaySurcharge: json['holidaySurcharge'] != null
          ? (json['holidaySurcharge'] as num).toDouble()
          : null,
      duallySurcharge: json['duallySurcharge'] != null
          ? (json['duallySurcharge'] as num).toDouble()
          : null,
      multiTruckSurcharge: json['multiTruckSurcharge'] != null
          ? (json['multiTruckSurcharge'] as num).toDouble()
          : null,
      manualAdditionSurcharge: json['manualAdditionSurcharge'] != null
          ? (json['manualAdditionSurcharge'] as num).toDouble()
          : null,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ruleName': ruleName,
      'description': description,
      'serviceType': serviceType,
      'baseFare': baseFare,
      'includedDistanceKm': includedDistanceKm,
      'ratePerKm': ratePerKm,
      'hourlyRate': hourlyRate,
      'recoveryBaseRate': recoveryBaseRate,
      'recoveryIncludedMinutes': recoveryIncludedMinutes,
      'recoveryRatePerMinute': recoveryRatePerMinute,
      'freeWaitingTimeMinutes': freeWaitingTimeMinutes,
      'waitingRatePerMinute': waitingRatePerMinute,
      'cancellationFee': cancellationFee,
      'afterHoursSurcharge': afterHoursSurcharge,
      'holidaySurcharge': holidaySurcharge,
      'duallySurcharge': duallySurcharge,
      'multiTruckSurcharge': multiTruckSurcharge,
      'manualAdditionSurcharge': manualAdditionSurcharge,
    };
  }

  String get serviceTypeName {
    switch (serviceType) {
      case 1:
        return 'Wheel Lift Towing';
      case 2:
        return 'Flatbed Carrier';
      case 3:
        return 'Underground / Low Clearance';
      case 4:
        return 'Heavy Duty / Commercial';
      case 5:
        return 'Motorcycle Towing';
      case 6:
        return 'Battery Jump Start';
      case 7:
        return 'Flat Tire Service';
      case 8:
        return 'Lockout Service';
      case 9:
        return 'Fuel / Fluid Delivery';
      case 10:
        return 'Winching / Off-Road Recovery';
      default:
        return 'Standard Asset';
    }
  }
}

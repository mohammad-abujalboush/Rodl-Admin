class PricingRuleModel {
  final String id;
  final String ruleName;
  final String description;
  final int serviceType;
  final double baseFare;
  final double includedDistanceKm;
  final double ratePerKm;
  final double outOfZoneRatePerKm; // NEW: Cross-city boundary rate
  final double hourlyRate;
  final double recoveryBaseRate;
  final int recoveryIncludedMinutes;
  final double recoveryRatePerMinute;
  final int freeWaitingTimeMinutes;
  final double waitingRatePerMinute;
  final double cancellationFee;
  final double? afterHoursSurcharge;
  final double? holidaySurcharge;
  final double? duallySurcharge;
  final double? multiTruckSurcharge;
  final bool isActive;

  PricingRuleModel({
    required this.id,
    required this.ruleName,
    required this.description,
    required this.serviceType,
    required this.baseFare,
    required this.includedDistanceKm,
    required this.ratePerKm,
    required this.outOfZoneRatePerKm,
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
    required this.isActive,
  });

  factory PricingRuleModel.fromJson(Map<String, dynamic> json) {
    return PricingRuleModel(
      id: json['id']?.toString() ?? '',
      ruleName: json['ruleName'] ?? 'Unnamed Rule',
      description: json['description'] ?? '',
      serviceType: json['serviceType'] ?? 1,
      baseFare: (json['baseFare'] ?? 0.0).toDouble(),
      includedDistanceKm: (json['includedDistanceKm'] ?? 0.0).toDouble(),
      ratePerKm: (json['ratePerKm'] ?? 0.0).toDouble(),
      outOfZoneRatePerKm: (json['outOfZoneRatePerKm'] ?? 0.0).toDouble(),
      hourlyRate: (json['hourlyRate'] ?? 0.0).toDouble(),
      recoveryBaseRate: (json['recoveryBaseRate'] ?? 0.0).toDouble(),
      recoveryIncludedMinutes: json['recoveryIncludedMinutes'] ?? 0,
      recoveryRatePerMinute: (json['recoveryRatePerMinute'] ?? 0.0).toDouble(),
      freeWaitingTimeMinutes: json['freeWaitingTimeMinutes'] ?? 0,
      waitingRatePerMinute: (json['waitingRatePerMinute'] ?? 0.0).toDouble(),
      cancellationFee: (json['cancellationFee'] ?? 0.0).toDouble(),
      afterHoursSurcharge: json['afterHoursSurcharge']?.toDouble(),
      holidaySurcharge: json['holidaySurcharge']?.toDouble(),
      duallySurcharge: json['duallySurcharge']?.toDouble(),
      multiTruckSurcharge: json['multiTruckSurcharge']?.toDouble(),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ruleName': ruleName,
    'description': description,
    'serviceType': serviceType,
    'baseFare': baseFare,
    'includedDistanceKm': includedDistanceKm,
    'ratePerKm': ratePerKm,
    'outOfZoneRatePerKm': outOfZoneRatePerKm,
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
    'isActive': isActive,
  };
}

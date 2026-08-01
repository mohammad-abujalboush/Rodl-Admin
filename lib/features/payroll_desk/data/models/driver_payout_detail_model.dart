class DriverPayoutDetailModel {
  final String driverProfileId;
  final String driverName;
  final double totalNetOwed;
  final List<EarningLineItemModel> lineItems;

  DriverPayoutDetailModel({
    required this.driverProfileId,
    required this.driverName,
    required this.totalNetOwed,
    required this.lineItems,
  });

  factory DriverPayoutDetailModel.fromJson(Map<String, dynamic> json) {
    return DriverPayoutDetailModel(
      driverProfileId: json['driverProfileId'] ?? '',
      driverName: json['driverName'] ?? 'Unknown Driver',
      totalNetOwed: (json['totalNetOwed'] ?? 0).toDouble(),
      lineItems:
          (json['lineItems'] as List<dynamic>?)
              ?.map((item) => EarningLineItemModel.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class EarningLineItemModel {
  final String earningId;
  final String? serviceRequestId;
  final String description;
  final double grossAmount;
  final double platformFee;
  final double netPayout;
  final DateTime createdAt;
  final bool isOnHold;

  EarningLineItemModel({
    required this.earningId,
    this.serviceRequestId,
    required this.description,
    required this.grossAmount,
    required this.platformFee,
    required this.netPayout,
    required this.createdAt,
    required this.isOnHold,
  });

  factory EarningLineItemModel.fromJson(Map<String, dynamic> json) {
    return EarningLineItemModel(
      earningId: json['earningId'] ?? '',
      serviceRequestId: json['serviceRequestId'],
      description: json['description'] ?? 'Adjustment',
      grossAmount: (json['grossAmount'] ?? 0).toDouble(),
      platformFee: (json['platformFee'] ?? 0).toDouble(),
      netPayout: (json['netPayout'] ?? 0).toDouble(),
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      isOnHold: json['isOnHold'] ?? false,
    );
  }
}

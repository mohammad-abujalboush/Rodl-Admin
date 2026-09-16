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
      driverProfileId: json['driverProfileId'] ?? json['DriverProfileId'] ?? '',
      driverName: json['driverName'] ?? json['DriverName'] ?? 'Unknown Driver',
      totalNetOwed: ((json['totalNetOwed'] ?? json['TotalNetOwed'] ?? 0) as num)
          .toDouble(),
      lineItems:
          ((json['lineItems'] ?? json['LineItems']) as List<dynamic>?)
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
      earningId: json['earningId'] ?? json['EarningId'] ?? '',
      serviceRequestId: json['serviceRequestId'] ?? json['ServiceRequestId'],
      description: json['description'] ?? json['Description'] ?? 'Adjustment',
      grossAmount: ((json['grossAmount'] ?? json['GrossAmount'] ?? 0) as num)
          .toDouble(),
      platformFee: ((json['platformFee'] ?? json['PlatformFee'] ?? 0) as num)
          .toDouble(),
      netPayout: ((json['netPayout'] ?? json['NetPayout'] ?? 0) as num)
          .toDouble(),
      createdAt:
          DateTime.tryParse(json['createdAt'] ?? json['CreatedAt'] ?? '') ??
          DateTime.now(),
      isOnHold: json['isOnHold'] ?? json['IsOnHold'] ?? false,
    );
  }
}

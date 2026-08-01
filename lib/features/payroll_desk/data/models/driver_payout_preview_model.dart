class DriverPayoutPreviewModel {
  final String driverId;
  final String driverName;
  final int totalJobsCompleted;
  final double grossEarnings;
  final double platformFee;
  final double netPayout;

  DriverPayoutPreviewModel({
    required this.driverId,
    required this.driverName,
    required this.totalJobsCompleted,
    required this.grossEarnings,
    required this.platformFee,
    required this.netPayout,
  });

  factory DriverPayoutPreviewModel.fromJson(Map<String, dynamic> json) {
    return DriverPayoutPreviewModel(
      driverId: json['driverProfileId'] ?? json['driverId'] ?? '',
      driverName: json['driverName'] ?? 'Unknown Driver',
      totalJobsCompleted:
          json['unpaidJobCount'] ?? json['totalJobsCompleted'] ?? 0,
      grossEarnings: (json['grossEarnings'] ?? 0).toDouble(),
      platformFee: (json['platformFee'] ?? 0).toDouble(),
      netPayout: (json['netPayout'] ?? 0).toDouble(),
    );
  }
}

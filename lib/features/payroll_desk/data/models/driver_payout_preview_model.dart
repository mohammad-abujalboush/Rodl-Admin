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
      driverId:
          json['driverProfileId'] ??
          json['DriverProfileId'] ??
          json['driverId'] ??
          '',
      driverName: json['driverName'] ?? json['DriverName'] ?? 'Unknown Driver',
      totalJobsCompleted:
          json['unpaidJobCount'] ??
          json['UnpaidJobCount'] ??
          json['totalJobsCompleted'] ??
          0,
      grossEarnings:
          ((json['grossEarnings'] ?? json['GrossEarnings'] ?? 0) as num)
              .toDouble(),
      platformFee: ((json['platformFee'] ?? json['PlatformFee'] ?? 0) as num)
          .toDouble(),
      netPayout: ((json['netPayout'] ?? json['NetPayout'] ?? 0) as num)
          .toDouble(),
    );
  }
}

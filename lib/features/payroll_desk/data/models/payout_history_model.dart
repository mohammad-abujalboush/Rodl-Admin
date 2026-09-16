class PayoutHistoryModel {
  final String payoutId;
  final String driverProfileId;
  final String driverName;
  final String batchReference;
  final double totalAmount;
  final DateTime processedAt;
  final int jobsIncluded;

  PayoutHistoryModel({
    required this.payoutId,
    required this.driverProfileId,
    required this.driverName,
    required this.batchReference,
    required this.totalAmount,
    required this.processedAt,
    required this.jobsIncluded,
  });

  factory PayoutHistoryModel.fromJson(Map<String, dynamic> json) {
    return PayoutHistoryModel(
      payoutId: json['payoutId'] ?? json['PayoutId'] ?? '',
      driverProfileId: json['driverProfileId'] ?? json['DriverProfileId'] ?? '',
      driverName: json['driverName'] ?? json['DriverName'] ?? 'Unknown Driver',
      batchReference:
          json['batchReference'] ?? json['BatchReference'] ?? 'No Wire Ref',
      totalAmount: ((json['totalAmount'] ?? json['TotalAmount'] ?? 0) as num)
          .toDouble(),
      processedAt:
          DateTime.tryParse(json['processedAt'] ?? json['ProcessedAt'] ?? '') ??
          DateTime.now(),
      jobsIncluded: json['jobsIncluded'] ?? json['JobsIncluded'] ?? 0,
    );
  }
}

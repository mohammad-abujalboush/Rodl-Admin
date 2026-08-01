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
      payoutId: json['payoutId'] ?? '',
      driverProfileId: json['driverProfileId'] ?? '',
      driverName: json['driverName'] ?? 'Unknown Driver',
      batchReference: json['batchReference'] ?? 'No Wire Ref',
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      processedAt: DateTime.parse(
        json['processedAt'] ?? DateTime.now().toIso8601String(),
      ),
      jobsIncluded: json['jobsIncluded'] ?? 0,
    );
  }
}

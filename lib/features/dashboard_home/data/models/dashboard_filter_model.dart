class DashboardFilterModel {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<int>? serviceTypes;
  final List<int>? statuses;
  final String? driverId;

  DashboardFilterModel({
    this.startDate,
    this.endDate,
    this.serviceTypes,
    this.statuses,
    this.driverId,
  });

  Map<String, dynamic> toJson() => {
    'startDate': startDate?.toUtc().toIso8601String(),
    'endDate': endDate?.toUtc().toIso8601String(),
    'serviceTypes': serviceTypes,
    'statuses': statuses,
    'driverId': driverId,
  };
}

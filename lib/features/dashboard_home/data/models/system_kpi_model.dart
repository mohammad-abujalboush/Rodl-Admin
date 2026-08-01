class SystemKpiModel {
  final int unassignedJobs;
  final int activeTows;
  final int slaBreaches;
  final int onlineFleet;
  final double totalRevenue;
  final double averageTicketSize;
  final double cancellationRate;
  final int averageWaitTimeMinutes;

  final List<ChartPointModel> revenueTrend;

  final List<ServiceMixModel> serviceMix;
  final List<EscalationJobModel> escalations;

  SystemKpiModel({
    required this.unassignedJobs,
    required this.activeTows,
    required this.slaBreaches,
    required this.onlineFleet,
    required this.totalRevenue,
    required this.averageTicketSize,
    required this.cancellationRate,
    required this.averageWaitTimeMinutes,
    required this.revenueTrend, // <-- Added back here
    required this.serviceMix,
    required this.escalations,
  });

  factory SystemKpiModel.fromJson(Map<String, dynamic> json) {
    return SystemKpiModel(
      unassignedJobs: json['unassignedJobs'] ?? 0,
      activeTows: json['activeTows'] ?? 0,
      slaBreaches: json['slaBreaches'] ?? 0,
      onlineFleet: json['onlineFleet'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      averageTicketSize: (json['averageTicketSize'] ?? 0).toDouble(),
      cancellationRate: (json['cancellationRate'] ?? 0).toDouble(),
      averageWaitTimeMinutes: json['averageWaitTimeMinutes'] ?? 0,
      // --- MAP THE CHART DATA ---
      revenueTrend:
          (json['revenueTrend'] as List?)
              ?.map((e) => ChartPointModel.fromJson(e))
              .toList() ??
          [],
      serviceMix:
          (json['serviceMix'] as List?)
              ?.map((e) => ServiceMixModel.fromJson(e))
              .toList() ??
          [],
      escalations:
          (json['escalations'] as List?)
              ?.map((e) => EscalationJobModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class ChartPointModel {
  final String xLabel; // e.g. "12 Jun" from the C# backend
  final double y;

  ChartPointModel({required this.xLabel, required this.y});

  factory ChartPointModel.fromJson(Map<String, dynamic> json) {
    return ChartPointModel(
      xLabel: json['xLabel'] ?? '',
      y: (json['y'] ?? 0).toDouble(),
    );
  }
}

class ServiceMixModel {
  final String serviceName;
  final int count;
  final double percentage;

  ServiceMixModel({
    required this.serviceName,
    required this.count,
    required this.percentage,
  });

  factory ServiceMixModel.fromJson(Map<String, dynamic> json) =>
      ServiceMixModel(
        serviceName: json['serviceName'] ?? '',
        count: json['count'] ?? 0,
        percentage: (json['percentage'] ?? 0).toDouble(),
      );
}

class EscalationJobModel {
  final String serviceName;
  final String driverName;
  final String statusText;
  final int waitTimeMinutes;

  EscalationJobModel({
    required this.serviceName,
    required this.driverName,
    required this.statusText,
    required this.waitTimeMinutes,
  });

  factory EscalationJobModel.fromJson(Map<String, dynamic> json) =>
      EscalationJobModel(
        serviceName: json['serviceName'] ?? '',
        driverName: json['driverName'] ?? '',
        statusText: json['statusText'] ?? '',
        waitTimeMinutes: json['waitTimeMinutes'] ?? 0,
      );
}

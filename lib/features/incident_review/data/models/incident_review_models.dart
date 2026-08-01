import 'package:google_maps_flutter/google_maps_flutter.dart';

class HistoricalJobModel {
  final String requestId;
  final String customerName;
  final String driverName;
  final int finalStatus;
  final double totalFare;
  final DateTime createdAt;
  final DateTime? completedAt;

  HistoricalJobModel({
    required this.requestId,
    required this.customerName,
    required this.driverName,
    required this.finalStatus,
    required this.totalFare,
    required this.createdAt,
    this.completedAt,
  });

  factory HistoricalJobModel.fromJson(Map<String, dynamic> json) {
    return HistoricalJobModel(
      requestId: json['requestId'] ?? '',
      customerName: json['customerName'] ?? 'Unknown',
      driverName: json['driverName'] ?? 'Unassigned',
      finalStatus: json['finalStatus'] ?? 0,
      totalFare: (json['totalFare'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }

  String get finalStatusText {
    switch (finalStatus) {
      case 3:
        return 'Completed';
      case 99:
        return 'Cancelled / Voided';
      default:
        return 'Unknown Status ($finalStatus)';
    }
  }
}

class StatusHistoryModel {
  final int status;
  final String changedBy;
  final DateTime timestamp;
  final String? notes;

  StatusHistoryModel({
    required this.status,
    required this.changedBy,
    required this.timestamp,
    this.notes,
  });

  factory StatusHistoryModel.fromJson(Map<String, dynamic> json) {
    return StatusHistoryModel(
      status: json['status'] ?? 0,
      changedBy: json['changedBy'] ?? 'System',
      timestamp: DateTime.parse(json['timestamp']),
      notes: json['notes'],
    );
  }
}

class LocationBreadcrumbModel {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LocationBreadcrumbModel({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory LocationBreadcrumbModel.fromJson(Map<String, dynamic> json) {
    return LocationBreadcrumbModel(
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  LatLng toLatLng() => LatLng(latitude, longitude);
}

class IncidentDossierModel {
  final HistoricalJobModel job;
  final List<StatusHistoryModel> timeline;
  final List<LocationBreadcrumbModel> breadcrumbs;

  IncidentDossierModel({
    required this.job,
    required this.timeline,
    required this.breadcrumbs,
  });

  factory IncidentDossierModel.fromJson(Map<String, dynamic> json) {
    return IncidentDossierModel(
      job: HistoricalJobModel.fromJson(json['job']),
      timeline:
          (json['timeline'] as List<dynamic>?)
              ?.map((t) => StatusHistoryModel.fromJson(t))
              .toList() ??
          [],
      breadcrumbs:
          (json['breadcrumbs'] as List<dynamic>?)
              ?.map((b) => LocationBreadcrumbModel.fromJson(b))
              .toList() ??
          [],
    );
  }
}

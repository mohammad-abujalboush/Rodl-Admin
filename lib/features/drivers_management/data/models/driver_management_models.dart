class FleetDriverModel {
  final String driverProfileId;
  final String fullName;
  final String phoneNumber;
  final String email;
  final DateTime appliedAt;
  final Map<String, String?> documents;
  final Map<String, dynamic>? vehicleDetails;

  final bool isApproved;
  final bool isOnJob;
  final bool isOnline;
  final bool isSuspended;

  FleetDriverModel({
    required this.driverProfileId,
    required this.fullName,
    required this.phoneNumber,
    this.email = '',
    required this.appliedAt,
    required this.documents,
    this.vehicleDetails,
    this.isApproved = false,
    this.isOnJob = false,
    this.isOnline = false,
    this.isSuspended = false,
  });

  factory FleetDriverModel.fromJson(Map<String, dynamic> json) {
    return FleetDriverModel(
      driverProfileId: (json['driverId'] ?? json['driverProfileId'] ?? '')
          .toString(),
      fullName: json['fullName'] ?? 'Unknown',
      phoneNumber: json['phone'] ?? json['phoneNumber'] ?? 'No Phone',
      email: json['email'] ?? '',
      appliedAt: json['appliedAt'] != null
          ? DateTime.parse(json['appliedAt'])
          : DateTime.now(),
      isApproved: json['isApproved'] ?? (json['driverId'] != null),
      isOnJob: json['isOnJob'] ?? false,
      isOnline: json['isOnline'] ?? false,
      isSuspended: json['isSuspended'] ?? false,
      documents: {
        'Government ID': json['documents']?['governmentId'],
        'Driving License': json['documents']?['drivingLicense'],
        'Commercial Insurance': json['documents']?['insurance'],
        'Background Check': json['documents']?['backgroundCheck'],
      },
      vehicleDetails:
          json['vehicleDetails'] ??
          (json['vehicleMake'] != null
              ? {
                  'make': json['vehicleMake'],
                  'model': json['vehicleModel'],
                  'year': json['vehicleYear'],
                  'licensePlate': json['licensePlate'],
                  'truckType': json['truckType'],
                }
              : null),
    );
  }

  // --- UI FORMATTING GETTERS ---

  String get truckTypeText {
    if (vehicleDetails == null) return 'No Vehicle Assigned';
    final int type = vehicleDetails!['truckType'] ?? 1;

    switch (type) {
      case 1:
        return 'Standard Wrecker (Wheel Lift)';
      case 2:
        return 'Flatbed Rollback';
      case 3:
        return 'Low Clearance / Underground';
      case 4:
        return 'Heavy Duty Rotator (Commercial)';
      case 5:
        return 'Light Service (No Towing)';
      case 6:
        return 'Motorcycle Dedicated Trailer';
      default:
        return 'Unknown Class';
    }
  }

  String get vehicleSummary {
    if (vehicleDetails == null) return 'Pending Assignment';
    return '${vehicleDetails!['year']} ${vehicleDetails!['make']} ${vehicleDetails!['model']}';
  }
}

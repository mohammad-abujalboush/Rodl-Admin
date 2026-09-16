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
      // FIX: Added robust PascalCase checks to capture backend data
      driverProfileId:
          (json['driverId'] ??
                  json['DriverId'] ??
                  json['driverProfileId'] ??
                  json['DriverProfileId'] ??
                  '')
              .toString(),
      fullName: json['fullName'] ?? json['FullName'] ?? 'Unknown',
      phoneNumber:
          json['phone'] ??
          json['phoneNumber'] ??
          json['PhoneNumber'] ??
          'No Phone',
      email: json['email'] ?? json['Email'] ?? '',
      appliedAt:
          DateTime.tryParse(json['appliedAt'] ?? json['AppliedAt'] ?? '') ??
          DateTime.now(),
      isApproved:
          json['isApproved'] ??
          json['IsApproved'] ??
          (json['driverId'] != null || json['DriverId'] != null),
      isOnJob: json['isOnJob'] ?? json['IsOnJob'] ?? false,
      isOnline: json['isOnline'] ?? json['IsOnline'] ?? false,
      isSuspended: json['isSuspended'] ?? json['IsSuspended'] ?? false,

      // Document mapping handles both camelCase and PascalCase variations
      documents: {
        'Government ID':
            json['documents']?['governmentId'] ??
            json['Documents']?['governmentId'] ??
            json['Documents']?['GovernmentId'],
        'Driving License':
            json['documents']?['drivingLicense'] ??
            json['Documents']?['drivingLicense'] ??
            json['Documents']?['DrivingLicense'],
        'Commercial Insurance':
            json['documents']?['insurance'] ??
            json['Documents']?['insurance'] ??
            json['Documents']?['CommercialInsurance'],
        'Background Check':
            json['documents']?['backgroundCheck'] ??
            json['Documents']?['backgroundCheck'] ??
            json['Documents']?['BackgroundCheck'],
      },

      // Vehicle parsing safely extracts deeply nested dictionary items
      vehicleDetails:
          json['vehicleDetails'] ??
          json['VehicleDetails'] ??
          (json['vehicleMake'] != null || json['VehicleMake'] != null
              ? {
                  'make': json['vehicleMake'] ?? json['VehicleMake'],
                  'model': json['vehicleModel'] ?? json['VehicleModel'],
                  'year': json['vehicleYear'] ?? json['VehicleYear'],
                  'licensePlate': json['licensePlate'] ?? json['LicensePlate'],
                  'truckType': json['truckType'] ?? json['TruckType'],
                }
              : null),
    );
  }

  // --- UI FORMATTING GETTERS ---

  String get truckTypeText {
    if (vehicleDetails == null) return 'No Vehicle Assigned';

    // Safety cast to handle strings coming back from some JSON serializers
    final dynamic typeRaw =
        vehicleDetails!['truckType'] ?? vehicleDetails!['TruckType'];
    final int type = typeRaw is int
        ? typeRaw
        : int.tryParse(typeRaw.toString()) ?? 1;

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

    final year = vehicleDetails!['year'] ?? vehicleDetails!['Year'] ?? '0000';
    final make =
        vehicleDetails!['make'] ?? vehicleDetails!['Make'] ?? 'Unknown';
    final model =
        vehicleDetails!['model'] ?? vehicleDetails!['Model'] ?? 'Vehicle';

    return '$year $make $model';
  }
}

class ActiveJobModel {
  final String requestId;
  final int serviceType;
  final int status;
  final DateTime createdAt;
  final double pickupLatitude;
  final double pickupLongitude;
  final String? pickupAddress;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final String? dropoffAddress;
  final double estimatedDistanceKm;
  final String driverName;
  final String customerName;
  final String customerPhone;

  // --- Editable Dispatch Details ---
  final String? vehicleDetails;
  final String? locationCondition;

  // --- Granular Financials ---
  final double baseFare;
  final double distanceFee;
  final double waitPenalty;
  final double surcharges;
  final double totalFare;

  // --- NEW: Media & Addons ---
  final List<JobAddonModel> addons;
  final List<JobPhotoModel> photos;

  ActiveJobModel({
    required this.requestId,
    required this.serviceType,
    required this.status,
    required this.createdAt,
    required this.pickupLatitude,
    required this.pickupLongitude,
    this.pickupAddress,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.dropoffAddress,
    required this.estimatedDistanceKm,
    required this.driverName,
    required this.customerName,
    required this.customerPhone,
    this.vehicleDetails,
    this.locationCondition,
    required this.baseFare,
    required this.distanceFee,
    required this.waitPenalty,
    required this.surcharges,
    required this.totalFare,
    required this.addons,
    required this.photos,
  });

  factory ActiveJobModel.fromJson(Map<String, dynamic> json) {
    return ActiveJobModel(
      requestId: json['requestId']?.toString() ?? '',
      serviceType: json['serviceType'] ?? 1,
      status: json['status'] ?? 0,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      pickupLatitude: (json['pickupLatitude'] ?? 0).toDouble(),
      pickupLongitude: (json['pickupLongitude'] ?? 0).toDouble(),
      pickupAddress: json['pickupAddress'],
      dropoffLatitude: json['dropoffLatitude'] != null
          ? (json['dropoffLatitude']).toDouble()
          : null,
      dropoffLongitude: json['dropoffLongitude'] != null
          ? (json['dropoffLongitude']).toDouble()
          : null,
      dropoffAddress: json['dropoffAddress'],
      estimatedDistanceKm: (json['estimatedDistanceKm'] ?? 0).toDouble(),
      driverName: json['driverName'] ?? 'Unassigned',
      customerName: json['customerName'] ?? 'Unknown Customer',
      customerPhone: json['customerPhone'] ?? 'No Phone',
      vehicleDetails: json['vehicleDetails'],
      locationCondition: json['locationCondition'],
      baseFare: (json['baseFare'] ?? 0).toDouble(),
      distanceFee: (json['distanceFee'] ?? 0).toDouble(),
      waitPenalty: (json['waitPenalty'] ?? 0).toDouble(),
      surcharges: (json['surcharges'] ?? 0).toDouble(),
      totalFare: (json['totalFare'] ?? 0).toDouble(),
      addons:
          ((json['addons'] ?? json['serviceRequestAddons']) as List<dynamic>?)
              ?.map((x) => JobAddonModel.fromJson(x))
              .toList() ??
          [],
      photos:
          ((json['photos'] ?? json['serviceRequestPhotos']) as List<dynamic>?)
              ?.map((x) => JobPhotoModel.fromJson(x))
              .toList() ??
          [],
    );
  }

  String get statusText {
    switch (status) {
      case 0:
        return 'Pending Dispatch';
      case 1:
        return 'Driver Accepted';
      case 2:
        return 'Driver Arrived';
      case 3:
        return 'Completed';
      case 4:
        return 'Waiting on Customer';
      case 5:
        return 'Loading Vehicle';
      case 6:
        return 'In Transit to Dropoff';
      case 99:
        return 'Cancelled';
      default:
        return 'Unknown Status';
    }
  }

  String get serviceTypeText {
    switch (serviceType) {
      case 1:
        return 'Wheel Lift Towing';
      case 2:
        return 'Flatbed Carrier';
      case 3:
        return 'Underground / Low Clearance';
      case 4:
        return 'Heavy Duty / Commercial';
      case 5:
        return 'Motorcycle Towing';
      case 6:
        return 'Battery Jump Start';
      case 7:
        return 'Flat Tire Service';
      case 8:
        return 'Lockout Service';
      case 9:
        return 'Fuel / Fluid Delivery';
      case 10:
        return 'Winching / Off-Road Recovery';
      default:
        return 'Standard Tow';
    }
  }
}

class JobAddonModel {
  final String id;
  final String description;
  final double price;
  JobAddonModel({
    required this.description,
    required this.price,
    required this.id,
  });
  factory JobAddonModel.fromJson(Map<String, dynamic> json) => JobAddonModel(
    id:
        json['id']?.toString() ??
        json['Id']?.toString() ??
        json['addonId']?.toString() ??
        '',
    description:
        json['description'] ?? json['Description'] ?? 'Unknown Surcharge',
    price: (json['price'] ?? json['Price'] ?? 0).toDouble(),
  );
}

class JobPhotoModel {
  final String url;
  final String photoType;
  final String? notes;

  JobPhotoModel({required this.url, required this.photoType, this.notes});

  factory JobPhotoModel.fromJson(Map<String, dynamic> json) => JobPhotoModel(
    url: json['photoUrl'] ?? '',
    photoType: json['photoType'] ?? 'General',
    notes: json['notes'],
  );
}

class FleetDriverModel {
  final String id;
  final String fullName;
  final double currentLatitude;
  final double currentLongitude;
  final String vehicle;
  final bool isOnJob;

  FleetDriverModel.fromJson(Map<String, dynamic> json)
    : id = json['driverId']?.toString() ?? '',
      fullName = json['fullName'] ?? 'Unknown Fleet Member',
      currentLatitude = (json['currentLatitude'] ?? 0).toDouble(),
      currentLongitude = (json['currentLongitude'] ?? 0).toDouble(),
      vehicle = json['vehicle'] ?? 'Unknown Vehicle',
      isOnJob = json['isOnJob'] ?? false;
}

class ServiceAssetModel {
  final int serviceType;
  final String name;

  ServiceAssetModel({required this.serviceType, required this.name});

  factory ServiceAssetModel.fromJson(Map<String, dynamic> json) {
    int type = json['serviceType'] ?? 1;
    String assetName = type == 1
        ? 'Wheel Lift'
        : type == 2
        ? 'Flatbed Carrier'
        : type == 3
        ? 'Underground Van'
        : 'Standard Asset';
    return ServiceAssetModel(serviceType: type, name: assetName);
  }
}

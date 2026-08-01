class CustomerModel {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final DateTime joinedAt;
  final int totalRequests;
  final double totalSpent;

  CustomerModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.joinedAt,
    this.totalRequests = 0,
    this.totalSpent = 0.0,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? 'Unknown',
      // FIX: Mapped to correct backend DTO keys
      phone: json['phoneNumber'] ?? json['phone'] ?? 'No Phone',
      email: json['email'] ?? 'No Email',
      joinedAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      totalRequests: json['totalRequests'] ?? 0,
      totalSpent: (json['totalSpent'] ?? 0).toDouble(),
    );
  }
}

class CustomerVehicleModel {
  final String id;
  final int year;
  final String make;
  final String model;
  final String color; // NEW
  final String? licensePlate;
  final bool isDefault;

  CustomerVehicleModel({
    required this.id,
    required this.year,
    required this.make,
    required this.model,
    required this.color,
    this.licensePlate,
    required this.isDefault,
  });

  factory CustomerVehicleModel.fromJson(Map<String, dynamic> json) {
    return CustomerVehicleModel(
      id: json['id'] ?? '',
      year: json['year'] ?? 0,
      make: json['make'] ?? 'Unknown',
      model: json['model'] ?? 'Unknown',
      color: json['color'] ?? 'Unknown',
      licensePlate: json['licensePlate'],
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class JobHistoryModel {
  final String requestId;
  final DateTime date;
  final String serviceType;
  final String status;
  final double totalPaid;

  JobHistoryModel({
    required this.requestId,
    required this.date,
    required this.serviceType,
    required this.status,
    required this.totalPaid,
  });

  factory JobHistoryModel.fromJson(Map<String, dynamic> json) {
    return JobHistoryModel(
      requestId: json['requestId']?.toString() ?? '',
      date: DateTime.parse(json['date']),
      serviceType: json['serviceType'] ?? 'Standard Tow',
      status: json['status'] ?? 'Unknown',
      totalPaid: (json['totalPaid'] ?? 0).toDouble(),
    );
  }
}

class CustomerProfileModel {
  final CustomerModel customer;
  final List<CustomerVehicleModel> vehicles;
  final List<JobHistoryModel> jobHistory;
  final int totalTows;
  final double lifetimeValue;
  final bool hasSavedPaymentMethod;

  CustomerProfileModel({
    required this.customer,
    required this.vehicles,
    required this.jobHistory,
    required this.totalTows,
    required this.lifetimeValue,
    required this.hasSavedPaymentMethod,
  });

  factory CustomerProfileModel.fromJson(Map<String, dynamic> json) {
    return CustomerProfileModel(
      customer: CustomerModel.fromJson(json['customer'] ?? {}),
      vehicles:
          (json['vehicles'] as List<dynamic>?)
              ?.map((v) => CustomerVehicleModel.fromJson(v))
              .toList() ??
          [],
      jobHistory:
          (json['jobHistory'] as List<dynamic>?)
              ?.map((j) => JobHistoryModel.fromJson(j))
              .toList() ??
          [],
      totalTows: json['totalTows'] ?? 0,
      lifetimeValue: (json['lifetimeValue'] ?? 0).toDouble(),
      hasSavedPaymentMethod: json['hasSavedPaymentMethod'] ?? false,
    );
  }
}

class StaffModel {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final List<String> permissions;

  StaffModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.permissions,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName'] ?? 'Unknown Staff',
      email: json['email'] ?? 'No Email Provided',
      role: json['role'] ?? 'Employee',
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  // Helper to get initials for the Avatar
  String get initials {
    if (fullName.isEmpty) return 'S';
    final parts = fullName.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.substring(0, 1).toUpperCase();
  }
}

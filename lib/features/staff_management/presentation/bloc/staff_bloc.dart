import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/api/dio_client.dart';

// --- MODEL ---
class StaffMemberModel {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String role;
  final List<String> permissions;
  final String employeeNumber;
  final String department;
  final String jobTitle;
  final bool isActive;
  final Map<String, String> documents;

  // --- NEW: PAYROLL & COMPENSATION FIELDS ---
  final int payrollType; // 0 = Hourly, 1 = Salaried
  final double baseRate;
  final double taxDeductionPercentage;

  StaffMemberModel.fromJson(Map<String, dynamic> json)
    : id = (json['id'] ?? json['Id'] ?? '').toString(),
      fullName = json['fullName'] ?? json['FullName'] ?? 'Unknown',
      email = json['email'] ?? json['Email'] ?? '',
      phoneNumber = json['phoneNumber'] ?? json['PhoneNumber'] ?? '',
      role = json['role'] ?? json['Role'] ?? 'Employee',
      permissions = List<String>.from(
        json['permissions'] ?? json['Permissions'] ?? [],
      ),
      employeeNumber =
          json['employeeNumber'] ?? json['EmployeeNumber'] ?? 'N/A',
      department = json['department'] ?? json['Department'] ?? 'General',
      jobTitle = json['jobTitle'] ?? json['JobTitle'] ?? 'Staff',
      isActive = json['isActive'] ?? json['IsActive'] ?? true,
      payrollType = ((json['payrollType'] ?? json['PayrollType'] ?? 0) as num)
          .toInt(),
      baseRate = ((json['baseRate'] ?? json['BaseRate'] ?? 0) as num)
          .toDouble(),
      taxDeductionPercentage =
          ((json['taxDeductionPercentage'] ??
                      json['TaxDeductionPercentage'] ??
                      0)
                  as num)
              .toDouble(),
      documents = {
        'Government ID':
            json['governmentIdUrl'] ?? json['GovernmentIdUrl'] ?? '',
        'Employment Contract':
            json['employmentContractUrl'] ??
            json['EmploymentContractUrl'] ??
            '',
        'NDA':
            json['nonDisclosureAgreementUrl'] ??
            json['NonDisclosureAgreementUrl'] ??
            '',
      };
}

// --- EVENTS ---
abstract class StaffEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchStaff extends StaffEvent {}

class AddStaffMember extends StaffEvent {
  final Map<String, dynamic> staffData;
  AddStaffMember(this.staffData);

  @override
  List<Object> get props => [staffData];
}

class EditStaffMember extends StaffEvent {
  final String staffId;
  final Map<String, dynamic> staffData;
  EditStaffMember(this.staffId, this.staffData);

  @override
  List<Object> get props => [staffId, staffData];
}

class UpdatePermissions extends StaffEvent {
  final String staffId;
  final List<String> permissions;
  UpdatePermissions(this.staffId, this.permissions);

  @override
  List<Object> get props => [staffId, permissions];
}

class ToggleStaffStatus extends StaffEvent {
  final String staffId;
  final bool isActive;
  ToggleStaffStatus(this.staffId, this.isActive);

  @override
  List<Object> get props => [staffId, isActive];
}

class DeleteStaffMember extends StaffEvent {
  final String staffId;
  DeleteStaffMember(this.staffId);

  @override
  List<Object> get props => [staffId];
}

// --- STATES ---
abstract class StaffState extends Equatable {
  @override
  List<Object> get props => [];
}

class StaffLoading extends StaffState {}

class StaffLoaded extends StaffState {
  final List<StaffMemberModel> staff;
  StaffLoaded(this.staff);

  @override
  List<Object> get props => [staff];
}

class StaffError extends StaffState {
  final String message;
  StaffError(this.message);

  @override
  List<Object> get props => [message];
}

class StaffSuccess extends StaffState {
  final String message;
  StaffSuccess(this.message);

  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class StaffManagementBloc extends Bloc<StaffEvent, StaffState> {
  final DioClient dioClient;

  StaffManagementBloc({required this.dioClient}) : super(StaffLoading()) {
    on<FetchStaff>((event, emit) async {
      emit(StaffLoading());
      try {
        final response = await dioClient.dio.get('/api/admin/staff');
        final staff = (response.data as List)
            .map((j) => StaffMemberModel.fromJson(j))
            .toList();
        emit(StaffLoaded(staff));
      } on DioException catch (e) {
        emit(
          StaffError(
            e.response?.data?['message'] ??
                'Failed to fetch employee directory.',
          ),
        );
      } catch (_) {
        emit(StaffError('Failed to fetch employee directory.'));
      }
    });

    on<AddStaffMember>((event, emit) async {
      try {
        final res = await dioClient.dio.post(
          '/api/admin/create-employee',
          data: event.staffData,
        );
        emit(
          StaffSuccess(
            res.data?['message'] ?? 'Employee created successfully.',
          ),
        );
        add(FetchStaff());
      } on DioException catch (e) {
        emit(
          StaffError(
            e.response?.data?['message'] ?? 'Failed to create employee.',
          ),
        );
      } catch (_) {
        emit(StaffError('Failed to create employee.'));
      }
    });

    on<EditStaffMember>((event, emit) async {
      try {
        final res = await dioClient.dio.put(
          '/api/admin/staff/${event.staffId}',
          data: event.staffData,
        );
        emit(
          StaffSuccess(res.data?['message'] ?? 'Profile updated successfully.'),
        );
        add(FetchStaff());
      } on DioException catch (e) {
        emit(
          StaffError(
            e.response?.data?['message'] ?? 'Failed to update employee.',
          ),
        );
      } catch (_) {
        emit(StaffError('Failed to update employee.'));
      }
    });

    on<UpdatePermissions>((event, emit) async {
      try {
        await dioClient.dio.put(
          '/api/admin/staff/${event.staffId}/permissions',
          data: {'permissions': event.permissions},
        );
        emit(StaffSuccess('RBAC permissions saved successfully.'));
        add(FetchStaff());
      } on DioException catch (e) {
        emit(
          StaffError(
            e.response?.data?['message'] ?? 'Failed to update permissions.',
          ),
        );
      } catch (_) {
        emit(StaffError('Failed to update permissions.'));
      }
    });

    on<ToggleStaffStatus>((event, emit) async {
      try {
        await dioClient.dio.put(
          '/api/admin/staff/${event.staffId}/status',
          data: {'isActive': event.isActive},
        );
        emit(
          StaffSuccess(
            event.isActive ? 'Account reactivated.' : 'Account suspended.',
          ),
        );
        add(FetchStaff());
      } on DioException catch (e) {
        emit(
          StaffError(
            e.response?.data?['message'] ?? 'Failed to update account status.',
          ),
        );
      } catch (_) {
        emit(StaffError('Failed to update account status.'));
      }
    });

    on<DeleteStaffMember>((event, emit) async {
      try {
        await dioClient.dio.delete('/api/admin/staff/${event.staffId}');
        emit(StaffSuccess('Employee permanently deleted.'));
        add(FetchStaff());
      } on DioException catch (e) {
        emit(
          StaffError(
            e.response?.data?['message'] ?? 'Failed to delete employee.',
          ),
        );
      } catch (_) {
        emit(StaffError('Failed to delete employee.'));
      }
    });
  }
}

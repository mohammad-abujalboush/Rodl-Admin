import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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

  StaffMemberModel.fromJson(Map<String, dynamic> json)
    : id = json['id'].toString(),
      fullName = json['fullName'] ?? 'Unknown',
      email = json['email'] ?? '',
      phoneNumber = json['phoneNumber'] ?? '',
      role = json['role'] ?? 'Employee',
      permissions = List<String>.from(json['permissions'] ?? []),
      employeeNumber = json['employeeNumber'] ?? 'N/A',
      department = json['department'] ?? 'General',
      jobTitle = json['jobTitle'] ?? 'Staff',
      isActive = json['isActive'] ?? true,
      documents = {
        'Government ID': json['governmentIdUrl'] ?? '',
        'Employment Contract': json['employmentContractUrl'] ?? '',
        'NDA': json['nonDisclosureAgreementUrl'] ?? '',
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
}

class EditStaffMember extends StaffEvent {
  final String staffId;
  final Map<String, dynamic> staffData;
  EditStaffMember(this.staffId, this.staffData);
}

class UpdatePermissions extends StaffEvent {
  final String staffId;
  final List<String> permissions;
  UpdatePermissions(this.staffId, this.permissions);
}

class ToggleStaffStatus extends StaffEvent {
  final String staffId;
  final bool isActive;
  ToggleStaffStatus(this.staffId, this.isActive);
}

class DeleteStaffMember extends StaffEvent {
  final String staffId;
  DeleteStaffMember(this.staffId);
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
}

class StaffSuccess extends StaffState {
  final String message;
  StaffSuccess(this.message);
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
      } catch (e) {
        emit(StaffError('Failed to fetch employee directory.'));
      }
    });

    on<AddStaffMember>((event, emit) async {
      try {
        final res = await dioClient.dio.post(
          '/api/admin/create-employee',
          data: event.staffData,
        );
        emit(StaffSuccess(res.data['message'] ?? 'Employee created.'));
        add(FetchStaff());
      } catch (e) {
        emit(StaffError('Failed to create employee.'));
      }
    });

    on<EditStaffMember>((event, emit) async {
      try {
        final res = await dioClient.dio.put(
          '/api/admin/staff/${event.staffId}',
          data: event.staffData,
        );
        emit(StaffSuccess(res.data['message'] ?? 'Profile updated.'));
        add(FetchStaff());
      } catch (e) {
        emit(StaffError('Failed to update employee.'));
      }
    });

    on<UpdatePermissions>((event, emit) async {
      try {
        await dioClient.dio.put(
          '/api/admin/staff/${event.staffId}/permissions',
          data: {'permissions': event.permissions},
        );
        emit(StaffSuccess('RBAC permissions saved.'));
        add(FetchStaff());
      } catch (e) {
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
      } catch (e) {
        emit(StaffError('Failed to update status.'));
      }
    });

    on<DeleteStaffMember>((event, emit) async {
      try {
        await dioClient.dio.delete('/api/admin/staff/${event.staffId}');
        emit(StaffSuccess('Employee permanently deleted.'));
        add(FetchStaff());
      } catch (e) {
        emit(StaffError('Failed to delete employee.'));
      }
    });
  }
}

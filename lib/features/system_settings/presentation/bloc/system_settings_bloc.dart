import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:roadside_service/features/system_settings/data/models/system_settings_models.dart';
import '../../../../core/api/dio_client.dart';

// --- EVENTS ---
abstract class SystemSettingsEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchSystemSettings extends SystemSettingsEvent {}

class UpdateGlobalVariables extends SystemSettingsEvent {
  final GlobalSettingsModel settings;
  UpdateGlobalVariables({required this.settings});
  @override
  List<Object> get props => [settings];
}

class InviteStaffMember extends SystemSettingsEvent {
  final String fullName;
  final String email;
  final String role;
  InviteStaffMember({
    required this.fullName,
    required this.email,
    required this.role,
  });
  @override
  List<Object> get props => [fullName, email, role];
}

class UpdateStaffPermissions extends SystemSettingsEvent {
  final String staffId;
  final List<String> permissions;
  UpdateStaffPermissions({required this.staffId, required this.permissions});
  @override
  List<Object> get props => [staffId, permissions];
}

class ToggleStaffStatus extends SystemSettingsEvent {
  final String staffId;
  final bool isActive;
  ToggleStaffStatus({required this.staffId, required this.isActive});
  @override
  List<Object> get props => [staffId, isActive];
}

// --- STATES ---
abstract class SystemSettingsState extends Equatable {
  @override
  List<Object> get props => [];
}

class SettingsLoading extends SystemSettingsState {}

class SettingsLoaded extends SystemSettingsState {
  final GlobalSettingsModel globalConfig;
  final List<StaffUserModel> staffList;
  SettingsLoaded({required this.globalConfig, required this.staffList});
  @override
  List<Object> get props => [globalConfig, staffList];
}

class SettingsError extends SystemSettingsState {
  final String message;
  SettingsError(this.message);
  @override
  List<Object> get props => [message];
}

class SettingsActionSuccess extends SystemSettingsState {
  final String message;
  SettingsActionSuccess(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class SystemSettingsBloc extends Bloc<SystemSettingsEvent, SystemSettingsState> {
  final DioClient dioClient;

  SystemSettingsBloc({required this.dioClient}) : super(SettingsLoading()) {
    
    on<FetchSystemSettings>((event, emit) async {
      emit(SettingsLoading());
      try {
        final responses = await Future.wait([
          dioClient.dio.get('/api/admin/settings/global'),
          dioClient.dio.get('/api/admin/staff'),
        ]);

        if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
          final config = GlobalSettingsModel.fromJson(responses[0].data);
          final staff = (responses[1].data as List).map((json) => StaffUserModel.fromJson(json)).toList();
          emit(SettingsLoaded(globalConfig: config, staffList: staff));
        } else {
          emit(SettingsError('Failed to load system settings payload.'));
        }
      } on DioException catch (e) {
        emit(SettingsError(e.response?.data['message'] ?? 'Network error while connecting to configuration service.'));
      } catch (e) {
        emit(SettingsError('An unexpected error occurred parsing settings.'));
      }
    });

    on<UpdateGlobalVariables>((event, emit) async {
      try {
        final response = await dioClient.dio.put('/api/admin/settings/global', data: event.settings.toJson());
        if (response.statusCode == 200) {
          emit(SettingsActionSuccess('Global ecosystem variables synchronized and broadcasted successfully.'));
          add(FetchSystemSettings());
        }
      } on DioException catch (e) {
        emit(SettingsError(e.response?.data['message'] ?? 'Failed to push global variables to server.'));
      }
    });

    on<InviteStaffMember>((event, emit) async {
      try {
        final response = await dioClient.dio.post(
          '/api/admin/create-employee',
          data: {
            'fullName': event.fullName,
            'email': event.email,
            'role': event.role == 'Administrator' ? 4 : 3, // Mapping UI string to DB Role Enum
            'sendInviteEmail': true,
          },
        );
        if (response.statusCode == 200) {
          emit(SettingsActionSuccess('Secure invitation token transmitted to ${event.email}.'));
          add(FetchSystemSettings());
        }
      } on DioException catch (e) {
        emit(SettingsError(e.response?.data['message'] ?? 'Failed to invite staff infrastructure member.'));
      }
    });

    on<UpdateStaffPermissions>((event, emit) async {
      try {
        final response = await dioClient.dio.put('/api/admin/staff/${event.staffId}/permissions', data: {'permissions': event.permissions});
        if (response.statusCode == 200) {
          emit(SettingsActionSuccess('Staff access control privileges locked down.'));
          add(FetchSystemSettings());
        }
      } on DioException catch (e) {
        emit(SettingsError(e.response?.data['message'] ?? 'Failed to update staff RBAC privileges.'));
      }
    });

    on<ToggleStaffStatus>((event, emit) async {
      try {
        final response = await dioClient.dio.put('/api/admin/staff/${event.staffId}/status', data: {'isActive': event.isActive});
        if (response.statusCode == 200) {
          emit(SettingsActionSuccess(event.isActive ? 'Staff identity node reactivated.' : 'Staff identity node securely suspended.'));
          add(FetchSystemSettings());
        }
      } on DioException catch (e) {
        emit(SettingsError(e.response?.data['message'] ?? 'Failed to toggle operational status of staff member.'));
      }
    });
  }
}
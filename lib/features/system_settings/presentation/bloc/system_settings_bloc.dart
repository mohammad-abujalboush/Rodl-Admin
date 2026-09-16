import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:roadside_service/features/system_settings/data/models/system_settings_models.dart';
import '../../../../core/api/dio_client.dart';

// --- EVENTS ---
abstract class SystemSettingsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchSystemSettings extends SystemSettingsEvent {}

class UpdateGlobalVariables extends SystemSettingsEvent {
  final GlobalSettingsModel settings;
  UpdateGlobalVariables({required this.settings});
  @override
  List<Object?> get props => [settings];
}

class SaveRegionalTaxRate extends SystemSettingsEvent {
  final RegionalTaxRateModel taxRate;
  final bool isNew;
  SaveRegionalTaxRate({required this.taxRate, required this.isNew});
  @override
  List<Object?> get props => [taxRate, isNew];
}

class DeleteRegionalTaxRate extends SystemSettingsEvent {
  final String provinceCode;
  DeleteRegionalTaxRate({required this.provinceCode});
  @override
  List<Object?> get props => [provinceCode];
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
  List<Object?> get props => [fullName, email, role];
}

class UpdateStaffPermissions extends SystemSettingsEvent {
  final String staffId;
  final List<String> permissions;
  UpdateStaffPermissions({required this.staffId, required this.permissions});
  @override
  List<Object?> get props => [staffId, permissions];
}

class ToggleStaffStatus extends SystemSettingsEvent {
  final String staffId;
  final bool isActive;
  ToggleStaffStatus({required this.staffId, required this.isActive});
  @override
  List<Object?> get props => [staffId, isActive];
}

// --- STATES ---
abstract class SystemSettingsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SettingsLoading extends SystemSettingsState {}

class SettingsLoaded extends SystemSettingsState {
  final GlobalSettingsModel globalConfig;
  final List<RegionalTaxRateModel> regionalTaxes;
  final List<StaffUserModel> staffList;

  SettingsLoaded({
    required this.globalConfig,
    required this.regionalTaxes,
    required this.staffList,
  });

  @override
  List<Object?> get props => [globalConfig, regionalTaxes, staffList];
}

class SettingsError extends SystemSettingsState {
  final String message;
  SettingsError(this.message);
  @override
  List<Object?> get props => [message];
}

class SettingsActionSuccess extends SystemSettingsState {
  final String message;
  SettingsActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

// --- BLOC ---
class SystemSettingsBloc
    extends Bloc<SystemSettingsEvent, SystemSettingsState> {
  final DioClient dioClient;

  SystemSettingsBloc({required this.dioClient}) : super(SettingsLoading()) {
    on<FetchSystemSettings>((event, emit) async {
      emit(SettingsLoading());
      try {
        final responses = await Future.wait([
          dioClient.dio.get('/api/admin/settings/global'),
          dioClient.dio.get('/api/admin/staff'),
          dioClient.dio
              .get('/api/admin/settings/regional-taxes')
              .catchError(
                (_) => Response(
                  requestOptions: RequestOptions(path: ''),
                  data: [],
                  statusCode: 200,
                ),
              ),
        ]);

        if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
          final config = GlobalSettingsModel.fromJson(responses[0].data);
          final staff = (responses[1].data as List)
              .map((json) => StaffUserModel.fromJson(json))
              .toList();
          final taxes = (responses[2].data is List)
              ? (responses[2].data as List)
                    .map((j) => RegionalTaxRateModel.fromJson(j))
                    .toList()
              : <RegionalTaxRateModel>[];

          emit(
            SettingsLoaded(
              globalConfig: config,
              regionalTaxes: taxes,
              staffList: staff,
            ),
          );
        } else {
          emit(SettingsError('Failed to load system settings payload.'));
        }
      } on DioException catch (e) {
        emit(
          SettingsError(
            e.response?.data?['message'] ??
                'Network error while connecting to configuration service.',
          ),
        );
      } catch (e) {
        emit(SettingsError('An unexpected error occurred parsing settings.'));
      }
    });

    on<UpdateGlobalVariables>((event, emit) async {
      try {
        final response = await dioClient.dio.put(
          '/api/admin/settings/global',
          data: event.settings.toJson(),
        );
        if (response.statusCode == 200) {
          emit(
            SettingsActionSuccess(
              'Global financial and operational variables committed successfully.',
            ),
          );
          add(FetchSystemSettings());
        }
      } on DioException catch (e) {
        emit(
          SettingsError(
            e.response?.data?['message'] ??
                'Failed to update global variables.',
          ),
        );
      } catch (_) {
        emit(SettingsError('Failed to update global variables.'));
      }
    });

    on<SaveRegionalTaxRate>((event, emit) async {
      try {
        final res = event.isNew
            ? await dioClient.dio.post(
                '/api/admin/settings/regional-taxes',
                data: event.taxRate.toJson(),
              )
            : await dioClient.dio.put(
                '/api/admin/settings/regional-taxes/${event.taxRate.provinceCode}',
                data: event.taxRate.toJson(),
              );

        if (res.statusCode == 200 || res.statusCode == 201) {
          emit(
            SettingsActionSuccess(
              'Regional tax profile saved for ${event.taxRate.regionName}.',
            ),
          );
          add(FetchSystemSettings());
        }
      } on DioException catch (e) {
        emit(
          SettingsError(
            e.response?.data?['message'] ?? 'Failed to save regional tax rate.',
          ),
        );
      } catch (_) {
        emit(SettingsError('Failed to save regional tax rate.'));
      }
    });

    on<DeleteRegionalTaxRate>((event, emit) async {
      try {
        final res = await dioClient.dio.delete(
          '/api/admin/settings/regional-taxes/${event.provinceCode}',
        );
        if (res.statusCode == 200 || res.statusCode == 204) {
          emit(SettingsActionSuccess('Regional tax profile removed.'));
          add(FetchSystemSettings());
        }
      } on DioException catch (e) {
        emit(
          SettingsError(
            e.response?.data?['message'] ??
                'Failed to delete regional tax profile.',
          ),
        );
      } catch (_) {
        emit(SettingsError('Failed to delete regional tax profile.'));
      }
    });

    on<InviteStaffMember>((event, emit) async {
      try {
        final response = await dioClient.dio.post(
          '/api/admin/create-employee',
          data: {
            'fullName': event.fullName,
            'email': event.email,
            'role': event.role == 'Administrator' ? 4 : 3,
            'sendInviteEmail': true,
          },
        );
        if (response.statusCode == 200) {
          emit(
            SettingsActionSuccess('Invitation transmitted to ${event.email}.'),
          );
          add(FetchSystemSettings());
        }
      } on DioException catch (e) {
        emit(
          SettingsError(
            e.response?.data?['message'] ?? 'Failed to invite staff member.',
          ),
        );
      } catch (_) {
        emit(SettingsError('Failed to invite staff member.'));
      }
    });

    on<UpdateStaffPermissions>((event, emit) async {
      try {
        final response = await dioClient.dio.put(
          '/api/admin/staff/${event.staffId}/permissions',
          data: {'permissions': event.permissions},
        );
        if (response.statusCode == 200) {
          emit(SettingsActionSuccess('Staff access privileges updated.'));
          add(FetchSystemSettings());
        }
      } on DioException catch (e) {
        emit(
          SettingsError(
            e.response?.data?['message'] ??
                'Failed to update staff RBAC privileges.',
          ),
        );
      } catch (_) {
        emit(SettingsError('Failed to update staff RBAC privileges.'));
      }
    });

    on<ToggleStaffStatus>((event, emit) async {
      try {
        final response = await dioClient.dio.put(
          '/api/admin/staff/${event.staffId}/status',
          data: {'isActive': event.isActive},
        );
        if (response.statusCode == 200) {
          emit(
            SettingsActionSuccess(
              event.isActive
                  ? 'Staff account reactivated.'
                  : 'Staff account suspended.',
            ),
          );
          add(FetchSystemSettings());
        }
      } on DioException catch (e) {
        emit(
          SettingsError(
            e.response?.data?['message'] ?? 'Failed to update account status.',
          ),
        );
      } catch (_) {
        emit(SettingsError('Failed to update account status.'));
      }
    });
  }
}

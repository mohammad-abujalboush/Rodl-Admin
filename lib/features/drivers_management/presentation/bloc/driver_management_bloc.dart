import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/models/driver_management_models.dart';

// --- EVENTS ---
abstract class DriverManagementEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchFleetData extends DriverManagementEvent {}

class ReviewApplication extends DriverManagementEvent {
  final String driverProfileId;
  final bool isApproved;
  ReviewApplication({required this.driverProfileId, required this.isApproved});
  @override
  List<Object> get props => [driverProfileId, isApproved];
}

class ManualOnboard extends DriverManagementEvent {
  final Map<String, dynamic> driverData;
  ManualOnboard({required this.driverData});
  @override
  List<Object> get props => [driverData];
}

class EditDriverDetails extends DriverManagementEvent {
  final String driverProfileId;
  final Map<String, dynamic> driverData;
  EditDriverDetails({required this.driverProfileId, required this.driverData});
  @override
  List<Object> get props => [driverProfileId, driverData];
}

class ToggleDriverStatus extends DriverManagementEvent {
  final String driverProfileId;
  final bool isSuspended;
  ToggleDriverStatus({
    required this.driverProfileId,
    required this.isSuspended,
  });
  @override
  List<Object> get props => [driverProfileId, isSuspended];
}

class DeleteDriver extends DriverManagementEvent {
  final String driverProfileId;
  DeleteDriver({required this.driverProfileId});
  @override
  List<Object> get props => [driverProfileId];
}

// --- STATES ---
abstract class DriverManagementState extends Equatable {
  @override
  List<Object?> get props => [];
}

class FleetLoading extends DriverManagementState {}

class FleetLoaded extends DriverManagementState {
  final List<FleetDriverModel> activeFleet;
  final List<FleetDriverModel> pendingQueue;
  FleetLoaded(this.activeFleet, this.pendingQueue);
  @override
  List<Object> get props => [activeFleet, pendingQueue];
}

class FleetError extends DriverManagementState {
  final String message;
  FleetError(this.message);
  @override
  List<Object> get props => [message];
}

class FleetActionSuccess extends DriverManagementState {
  final String message;
  FleetActionSuccess(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class DriverManagementBloc
    extends Bloc<DriverManagementEvent, DriverManagementState> {
  final DioClient dioClient;

  DriverManagementBloc({required this.dioClient}) : super(FleetLoading()) {
    on<FetchFleetData>((event, emit) async {
      emit(FleetLoading());
      try {
        final responses = await Future.wait([
          dioClient.dio.get('/api/admin/active-fleet'),
          dioClient.dio.get('/api/admin/pending-drivers'),
        ]);

        final activeFleet = (responses[0].data as List<dynamic>)
            .map((j) => FleetDriverModel.fromJson(j))
            .toList();
        final pendingQueue = (responses[1].data as List<dynamic>)
            .map((j) => FleetDriverModel.fromJson(j))
            .toList();

        emit(FleetLoaded(activeFleet, pendingQueue));
      } catch (e) {
        emit(FleetError('Network error while fetching fleet data.'));
      }
    });

    on<ReviewApplication>((event, emit) async {
      try {
        final response = await dioClient.dio.post(
          '/api/admin/review-driver/${event.driverProfileId}',
          data: {'isApproved': event.isApproved},
        );
        if (response.statusCode == 200) {
          emit(
            FleetActionSuccess(
              event.isApproved
                  ? 'Driver hired and activated.'
                  : 'Application rejected.',
            ),
          );
          add(FetchFleetData());
        }
      } catch (e) {
        emit(FleetError('Failed to process application.'));
      }
    });

    on<ManualOnboard>((event, emit) async {
      try {
        final response = await dioClient.dio.post(
          '/api/admin/drivers/manual',
          data: event.driverData,
        );
        if (response.statusCode == 200) {
          emit(FleetActionSuccess('Driver manually onboarded successfully.'));
          add(FetchFleetData());
        }
      } catch (e) {
        emit(FleetError('Failed to manually onboard driver.'));
      }
    });

    on<EditDriverDetails>((event, emit) async {
      try {
        final response = await dioClient.dio.put(
          '/api/admin/drivers/${event.driverProfileId}',
          data: event.driverData,
        );
        if (response.statusCode == 200) {
          emit(FleetActionSuccess('Driver details successfully updated.'));
          add(FetchFleetData());
        }
      } catch (e) {
        emit(FleetError('Failed to update driver details.'));
      }
    });

    on<ToggleDriverStatus>((event, emit) async {
      try {
        final response = await dioClient.dio.put(
          '/api/admin/drivers/${event.driverProfileId}/status',
          data: {'isSuspended': event.isSuspended},
        );
        if (response.statusCode == 200) {
          emit(
            FleetActionSuccess(
              response.data['message'] ?? 'Driver status updated.',
            ),
          );
          add(FetchFleetData());
        }
      } catch (e) {
        emit(FleetError('Failed to update driver status.'));
      }
    });

    on<DeleteDriver>((event, emit) async {
      try {
        final response = await dioClient.dio.delete(
          '/api/admin/drivers/${event.driverProfileId}',
        );
        if (response.statusCode == 200) {
          emit(FleetActionSuccess('Driver permanently removed.'));
          add(FetchFleetData());
        }
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 400) {
          emit(
            FleetError(
              e.response?.data['message'] ??
                  'Cannot delete driver with existing history.',
            ),
          );
        } else {
          emit(FleetError('Failed to delete driver.'));
        }
      }
    });
  }
}

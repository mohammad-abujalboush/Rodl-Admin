import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/models/active_job_model.dart';

// --- EVENTS ---
abstract class ActiveJobsEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchActiveJobs extends ActiveJobsEvent {}

class IssueRefund extends ActiveJobsEvent {
  final String requestId;
  final double amount;
  final String reason;
  IssueRefund({
    required this.requestId,
    required this.amount,
    required this.reason,
  });
  @override
  List<Object> get props => [requestId, amount, reason];
}

class CancelJob extends ActiveJobsEvent {
  final String requestId;
  final String reason;
  final double cancellationFee;
  CancelJob({
    required this.requestId,
    required this.reason,
    required this.cancellationFee,
  });
  @override
  List<Object> get props => [requestId, reason, cancellationFee];
}

class CreateManualDispatch extends ActiveJobsEvent {
  final Map<String, dynamic> dispatchData;
  CreateManualDispatch({required this.dispatchData});
  @override
  List<Object> get props => [dispatchData];
}

class AssignDriver extends ActiveJobsEvent {
  final String requestId;
  final String driverId;
  AssignDriver({required this.requestId, required this.driverId});
  @override
  List<Object> get props => [requestId, driverId];
}

class UpdateJobDetails extends ActiveJobsEvent {
  final String requestId;
  final Map<String, dynamic> updateData;
  UpdateJobDetails({required this.requestId, required this.updateData});
  @override
  List<Object> get props => [requestId, updateData];
}

class OverrideJobPricing extends ActiveJobsEvent {
  final String requestId;
  final Map<String, dynamic> pricingData;
  OverrideJobPricing({required this.requestId, required this.pricingData});
  @override
  List<Object> get props => [requestId, pricingData];
}

class AddJobAddon extends ActiveJobsEvent {
  final String requestId;
  final String description;
  final double price;
  AddJobAddon({
    required this.requestId,
    required this.description,
    required this.price,
  });
  @override
  List<Object> get props => [requestId, description, price];
}

class RemoveJobAddon extends ActiveJobsEvent {
  final String requestId;
  final String addonId;
  RemoveJobAddon({required this.requestId, required this.addonId});
  @override
  List<Object> get props => [requestId, addonId];
}

class AddJobPhoto extends ActiveJobsEvent {
  final String requestId;
  final String photoUrl;
  final String photoType;
  final String? notes;

  AddJobPhoto({
    required this.requestId,
    required this.photoUrl,
    required this.photoType,
    this.notes,
  });

  @override
  List<Object> get props => [requestId, photoUrl, photoType, notes ?? ''];
}

// --- STATES ---
abstract class ActiveJobsState extends Equatable {
  @override
  List<Object> get props => [];
}

class ActiveJobsLoading extends ActiveJobsState {}

class ActiveJobsLoaded extends ActiveJobsState {
  final List<ActiveJobModel> jobs;
  final List<FleetDriverModel> activeFleet;
  final List<ServiceAssetModel> serviceAssets;

  ActiveJobsLoaded(this.jobs, this.activeFleet, this.serviceAssets);
  @override
  List<Object> get props => [jobs, activeFleet, serviceAssets];
}

class ActiveJobsError extends ActiveJobsState {
  final String message;
  ActiveJobsError(this.message);
  @override
  List<Object> get props => [message];
}

class JobActionSuccess extends ActiveJobsState {
  final String message;
  JobActionSuccess(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class ActiveJobsBloc extends Bloc<ActiveJobsEvent, ActiveJobsState> {
  final DioClient dioClient;

  List<FleetDriverModel> _cachedFleet = [];
  List<ServiceAssetModel> _cachedAssets = [];

  ActiveJobsBloc({required this.dioClient}) : super(ActiveJobsLoading()) {
    on<FetchActiveJobs>((event, emit) async {
      emit(ActiveJobsLoading());
      try {
        final responses = await Future.wait([
          dioClient.dio.get('/api/admin/jobs/all'),
          dioClient.dio
              .get('/api/admin/active-fleet')
              .catchError(
                (_) => Response(
                  requestOptions: RequestOptions(),
                  statusCode: 404,
                  data: [],
                ),
              ),
          dioClient.dio
              .get('/api/admin/pricing-rules')
              .catchError(
                (_) => Response(
                  requestOptions: RequestOptions(),
                  statusCode: 404,
                  data: [],
                ),
              ),
        ]);

        final jobs = (responses[0].data as List)
            .map((json) => ActiveJobModel.fromJson(json))
            .toList();

        if (responses[1].statusCode == 200) {
          _cachedFleet = (responses[1].data as List)
              .map((json) => FleetDriverModel.fromJson(json))
              .toList();
        }

        if (responses[2].statusCode == 200) {
          _cachedAssets = (responses[2].data as List)
              .map((json) => ServiceAssetModel.fromJson(json))
              .toList();
        }

        if (_cachedAssets.isEmpty) {
          _cachedAssets = [
            ServiceAssetModel(serviceType: 1, name: 'Wheel Lift'),
            ServiceAssetModel(serviceType: 2, name: 'Flatbed Carrier'),
          ];
        }

        emit(ActiveJobsLoaded(jobs, _cachedFleet, _cachedAssets));
      } on DioException catch (e) {
        emit(
          ActiveJobsError(
            e.response?.data['message'] ?? 'Network error fetching data.',
          ),
        );
      } catch (e) {
        emit(ActiveJobsError('Unexpected error parsing data.'));
      }
    });

    on<IssueRefund>((event, emit) async {
      try {
        await dioClient.dio.post(
          '/api/admin/issue-refund/${event.requestId}',
          data: {'amount': event.amount, 'reason': event.reason},
        );
        emit(JobActionSuccess('Refund of \$${event.amount} issued.'));
        add(FetchActiveJobs());
      } catch (e) {
        emit(ActiveJobsError('Failed to issue refund.'));
      }
    });

    on<CancelJob>((event, emit) async {
      try {
        await dioClient.dio.post(
          '/api/admin/jobs/${event.requestId}/cancel',
          data: {
            'reason': event.reason,
            'cancellationFee': event.cancellationFee,
          },
        );
        emit(JobActionSuccess('Job force-cancelled.'));
        add(FetchActiveJobs());
      } catch (e) {
        emit(ActiveJobsError('Failed to cancel job.'));
      }
    });

    on<CreateManualDispatch>((event, emit) async {
      try {
        await dioClient.dio.post(
          '/api/admin/dispatch/manual',
          data: event.dispatchData,
        );
        emit(JobActionSuccess('Manual dispatch broadcasted successfully.'));
        add(FetchActiveJobs());
      } catch (e) {
        emit(ActiveJobsError('Failed to broadcast dispatch.'));
      }
    });

    on<AssignDriver>((event, emit) async {
      try {
        await dioClient.dio.post(
          '/api/admin/jobs/${event.requestId}/assign',
          data: {'driverId': event.driverId},
        );
        emit(JobActionSuccess('Driver successfully assigned.'));
        add(FetchActiveJobs());
      } catch (e) {
        emit(ActiveJobsError('Failed to assign driver.'));
      }
    });

    on<UpdateJobDetails>((event, emit) async {
      try {
        await dioClient.dio.put(
          '/api/admin/jobs/${event.requestId}',
          data: event.updateData,
        );
        emit(JobActionSuccess('Dispatch profile updated.'));
        add(FetchActiveJobs());
      } catch (e) {
        emit(ActiveJobsError('Failed to update job details.'));
      }
    });

    on<OverrideJobPricing>((event, emit) async {
      try {
        await dioClient.dio.post(
          '/api/admin/override-job/${event.requestId}',
          data: event.pricingData,
        );
        emit(JobActionSuccess('Financial override applied.'));
        add(FetchActiveJobs());
      } catch (e) {
        emit(ActiveJobsError('Failed to override pricing.'));
      }
    });

    on<AddJobAddon>((event, emit) async {
      try {
        await dioClient.dio.post(
          '/api/admin/jobs/${event.requestId}/addons',
          data: {'description': event.description, 'price': event.price},
        );
        emit(JobActionSuccess('Manual Addon applied to job.'));
        add(FetchActiveJobs());
      } catch (e) {
        emit(ActiveJobsError('Failed to apply Addon.'));
      }
    });

    on<AddJobPhoto>((event, emit) async {
      try {
        await dioClient.dio.post(
          '/api/admin/jobs/${event.requestId}/photos',
          data: {
            'photoUrl': event.photoUrl,
            'photoType': event.photoType,
            'notes': event.notes,
          },
        );
        emit(JobActionSuccess('Media evidence attached successfully.'));
        add(FetchActiveJobs());
      } catch (e) {
        emit(ActiveJobsError('Failed to attach Media.'));
      }
    });

    on<RemoveJobAddon>((event, emit) async {
      try {
        await dioClient.dio.delete(
          '/api/admin/jobs/${event.requestId}/addons/${event.addonId}',
        );
        emit(JobActionSuccess('Addon successfully reversed.'));
        add(FetchActiveJobs());
      } catch (e) {
        emit(ActiveJobsError('Failed to remove addon.'));
      }
    });
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    try {
      final res = await dioClient.dio.get(
        '/api/Admin/customers/search',
        queryParameters: {'query': query},
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      return [];
    }
  }
}

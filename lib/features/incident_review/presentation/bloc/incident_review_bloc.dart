import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:roadside_service/features/incident_review/data/models/incident_review_models.dart';
import '../../../../core/api/dio_client.dart';

// --- EVENTS ---
abstract class IncidentReviewEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class SearchIncident extends IncidentReviewEvent {
  final String jobId;

  SearchIncident({required this.jobId});

  @override
  List<Object> get props => [jobId];
}

class ClearIncidentSearch extends IncidentReviewEvent {}

// --- STATES ---
abstract class IncidentReviewState extends Equatable {
  @override
  List<Object> get props => [];
}

class IncidentIdle extends IncidentReviewState {}

class IncidentLoading extends IncidentReviewState {}

class IncidentLoaded extends IncidentReviewState {
  final IncidentDossierModel dossier;

  IncidentLoaded(this.dossier);

  @override
  List<Object> get props => [dossier];
}

class IncidentError extends IncidentReviewState {
  final String message;

  IncidentError(this.message);

  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class IncidentReviewBloc
    extends Bloc<IncidentReviewEvent, IncidentReviewState> {
  final DioClient dioClient;

  IncidentReviewBloc({required this.dioClient}) : super(IncidentIdle()) {
    on<SearchIncident>((event, emit) async {
      if (event.jobId.trim().isEmpty) return;

      emit(IncidentLoading());
      try {
        final response = await dioClient.dio.get(
          '/api/admin/incidents/${event.jobId.trim()}',
        );

        if (response.statusCode == 200) {
          final dossier = IncidentDossierModel.fromJson(response.data);
          emit(IncidentLoaded(dossier));
        } else {
          emit(
            IncidentError(
              'Incident not found or no historical data available.',
            ),
          );
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          emit(IncidentError('Job ID not found in archive.'));
        } else {
          emit(IncidentError('Network error connecting to archive database.'));
        }
      } catch (e) {
        emit(IncidentError('Failed to parse the incident data.'));
      }
    });

    on<ClearIncidentSearch>((event, emit) {
      emit(IncidentIdle());
    });
  }
}

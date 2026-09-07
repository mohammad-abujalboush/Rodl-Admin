import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/models/system_kpi_model.dart';
import '../../data/models/dashboard_filter_model.dart';

// --- EVENTS ---
abstract class DashboardEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchDashboardKpis extends DashboardEvent {
  final DashboardFilterModel filter;

  FetchDashboardKpis({required this.filter});

  @override
  List<Object> get props => [filter];
}

// --- STATES ---
abstract class DashboardState extends Equatable {
  @override
  List<Object> get props => [];
}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final SystemKpiModel kpis;

  DashboardLoaded(this.kpis);

  @override
  List<Object> get props => [kpis];
}

class DashboardError extends DashboardState {
  final String message;

  DashboardError(this.message);

  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DioClient dioClient;

  DashboardBloc({required this.dioClient}) : super(DashboardLoading()) {
    on<FetchDashboardKpis>((event, emit) async {
      emit(DashboardLoading());
      try {
        // We use POST here to safely send the complex JSON filter payload
        // to the new advanced filter engine in the .NET API.
        final response = await dioClient.dio.post(
          '/api/admin/kpis/filtered',
          data: event.filter.toJson(),
        );

        if (response.statusCode == 200) {
          final kpis = SystemKpiModel.fromJson(response.data);
          emit(DashboardLoaded(kpis));
        } else {
          emit(DashboardError('Failed to load dashboard data.'));
        }
      } on DioException catch (e) {
        String errorMessage = 'Network error while fetching metrics.';
        if (e.response != null && e.response?.statusCode != 500) {
          // Safeguard against malformed error responses
          if (e.response?.data is Map && e.response?.data['message'] != null) {
            errorMessage = e.response?.data['message'];
          } else {
            errorMessage = 'Data retrieval failed (${e.response?.statusCode}).';
          }
        } else if (e.response?.statusCode == 500) {
          errorMessage =
              'System calculation error. Please refine your filter dates.';
        }
        emit(DashboardError(errorMessage));
      } catch (e) {
        emit(
          DashboardError(
            'An unexpected error occurred parsing the dashboard data.',
          ),
        );
      }
    });
  }
}

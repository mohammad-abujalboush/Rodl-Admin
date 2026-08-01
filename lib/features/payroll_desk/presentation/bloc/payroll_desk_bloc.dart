import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:roadside_service/features/payroll_desk/data/models/driver_payout_preview_model.dart';
import 'package:roadside_service/features/payroll_desk/data/models/driver_payout_detail_model.dart';
import 'package:roadside_service/features/payroll_desk/data/models/payout_history_model.dart';
import '../../../../core/api/dio_client.dart';

// --- EVENTS ---
abstract class PayrollDeskEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchPayrollPreview extends PayrollDeskEvent {}

class FetchPayoutHistory extends PayrollDeskEvent {}

class ExecutePayrollBatch extends PayrollDeskEvent {
  final String bankWireReference;
  ExecutePayrollBatch({required this.bankWireReference});
  @override
  List<Object> get props => [bankWireReference];
}

class FetchDriverPayoutDetails extends PayrollDeskEvent {
  final String driverId;
  FetchDriverPayoutDetails({required this.driverId});
  @override
  List<Object> get props => [driverId];
}

class SubmitManualAdjustment extends PayrollDeskEvent {
  final String driverId;
  final double amount;
  final String reason;
  SubmitManualAdjustment({
    required this.driverId,
    required this.amount,
    required this.reason,
  });
  @override
  List<Object> get props => [driverId, amount, reason];
}

class ToggleEarningHoldStatus extends PayrollDeskEvent {
  final String earningId;
  final bool holdStatus;
  final String driverId;
  ToggleEarningHoldStatus({
    required this.earningId,
    required this.holdStatus,
    required this.driverId,
  });
  @override
  List<Object> get props => [earningId, holdStatus, driverId];
}

class DeleteEarningItem extends PayrollDeskEvent {
  final String earningId;
  final String driverId;
  DeleteEarningItem({required this.earningId, required this.driverId});
  @override
  List<Object> get props => [earningId, driverId];
}

class ClearSelectedDriver extends PayrollDeskEvent {}

// --- STATES ---
abstract class PayrollDeskState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PayrollLoading extends PayrollDeskState {}

class PayrollLoaded extends PayrollDeskState {
  final List<DriverPayoutPreviewModel> payouts;
  final List<PayoutHistoryModel> history;
  final DriverPayoutDetailModel? selectedDriverDetails;
  final double totalNetPayout;
  final double totalPlatformFees;
  final bool isDetailsLoading;

  PayrollLoaded({
    required this.payouts,
    this.history = const [],
    this.selectedDriverDetails,
    this.isDetailsLoading = false,
  }) : totalNetPayout = payouts.fold(0, (sum, item) => sum + item.netPayout),
       totalPlatformFees = payouts.fold(
         0,
         (sum, item) => sum + item.platformFee,
       );

  PayrollLoaded copyWith({
    List<DriverPayoutPreviewModel>? payouts,
    List<PayoutHistoryModel>? history,
    DriverPayoutDetailModel? selectedDriverDetails,
    bool? isDetailsLoading,
    bool clearDetails = false,
  }) {
    return PayrollLoaded(
      payouts: payouts ?? this.payouts,
      history: history ?? this.history,
      selectedDriverDetails: clearDetails
          ? null
          : (selectedDriverDetails ?? this.selectedDriverDetails),
      isDetailsLoading: isDetailsLoading ?? this.isDetailsLoading,
    );
  }

  @override
  List<Object?> get props => [
    payouts,
    history,
    selectedDriverDetails,
    totalNetPayout,
    totalPlatformFees,
    isDetailsLoading,
  ];
}

class PayrollError extends PayrollDeskState {
  final String message;
  PayrollError(this.message);
  @override
  List<Object> get props => [message];
}

class PayrollActionSuccess extends PayrollDeskState {
  final String message;
  PayrollActionSuccess(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class PayrollDeskBloc extends Bloc<PayrollDeskEvent, PayrollDeskState> {
  final DioClient dioClient;

  PayrollDeskBloc({required this.dioClient}) : super(PayrollLoading()) {
    // 1. Fetch Preview Ledger
    on<FetchPayrollPreview>((event, emit) async {
      final currentState = state;
      if (currentState is! PayrollLoaded) emit(PayrollLoading());

      try {
        final responses = await Future.wait([
          dioClient.dio.get('/api/admin/payroll/preview'),
          dioClient.dio
              .get('/api/admin/payroll/history')
              .catchError(
                (_) => Response(
                  requestOptions: RequestOptions(),
                  statusCode: 404,
                  data: [],
                ),
              ),
        ]);

        final payouts = (responses[0].data as List)
            .map((json) => DriverPayoutPreviewModel.fromJson(json))
            .toList();

        List<PayoutHistoryModel> history = [];
        if (responses[1].statusCode == 200) {
          history = (responses[1].data as List)
              .map((json) => PayoutHistoryModel.fromJson(json))
              .toList();
        }

        if (currentState is PayrollLoaded) {
          emit(currentState.copyWith(payouts: payouts, history: history));
        } else {
          emit(PayrollLoaded(payouts: payouts, history: history));
        }
      } on DioException catch (e) {
        emit(
          PayrollError(
            e.response?.data['message'] ??
                'Network error fetching payroll data.',
          ),
        );
      }
    });

    // 2. Execute Batch
    on<ExecutePayrollBatch>((event, emit) async {
      try {
        final response = await dioClient.dio.post(
          '/api/admin/payroll/execute',
          data: {'bankWireReference': event.bankWireReference},
        );
        if (response.statusCode == 200) {
          emit(
            PayrollActionSuccess(
              'Payroll batch executed and ledgers locked successfully!',
            ),
          );
          add(FetchPayrollPreview());
        }
      } on DioException catch (e) {
        emit(
          PayrollError(
            e.response?.data['message'] ?? 'Network error executing payroll.',
          ),
        );
      }
    });

    // 3. Fetch Driver Details
    on<FetchDriverPayoutDetails>((event, emit) async {
      final currentState = state;
      if (currentState is PayrollLoaded) {
        emit(currentState.copyWith(isDetailsLoading: true));
        try {
          final response = await dioClient.dio.get(
            '/api/admin/payroll/driver/${event.driverId}',
          );
          if (response.statusCode == 200) {
            final details = DriverPayoutDetailModel.fromJson(response.data);
            emit(
              currentState.copyWith(
                selectedDriverDetails: details,
                isDetailsLoading: false,
              ),
            );
          }
        } on DioException catch (e) {
          emit(
            PayrollError(
              e.response?.data['message'] ?? 'Failed to load driver details.',
            ),
          );
          emit(currentState.copyWith(isDetailsLoading: false));
        }
      }
    });

    // 4. Toggle Hold (Refetches driver details in-place without closing sheet)
    on<ToggleEarningHoldStatus>((event, emit) async {
      try {
        await dioClient.dio.put(
          '/api/admin/payroll/earnings/${event.earningId}/hold',
          data: {'isOnHold': event.holdStatus},
        );
        add(FetchDriverPayoutDetails(driverId: event.driverId));
        add(FetchPayrollPreview());
      } on DioException catch (e) {
        emit(
          PayrollError(
            e.response?.data['message'] ?? 'Failed to update hold status.',
          ),
        );
      }
    });

    // 5. Submit Manual Adjustment
    on<SubmitManualAdjustment>((event, emit) async {
      try {
        await dioClient.dio.post(
          '/api/admin/payroll/adjustments',
          data: {
            'driverProfileId': event.driverId,
            'amount': event.amount,
            'reason': event.reason,
          },
        );
        add(FetchDriverPayoutDetails(driverId: event.driverId));
        add(FetchPayrollPreview());
      } on DioException catch (e) {
        emit(
          PayrollError(
            e.response?.data['message'] ?? 'Failed to submit adjustment.',
          ),
        );
      }
    });

    // 6. Delete Earning Line Item
    on<DeleteEarningItem>((event, emit) async {
      try {
        await dioClient.dio.delete(
          '/api/admin/payroll/earnings/${event.earningId}',
        );
        emit(PayrollActionSuccess('Line item deleted from ledger.'));
        add(FetchDriverPayoutDetails(driverId: event.driverId));
        add(FetchPayrollPreview());
      } on DioException catch (e) {
        emit(
          PayrollError(
            e.response?.data['message'] ?? 'Failed to delete line item.',
          ),
        );
      }
    });

    // 7. Clear Details
    on<ClearSelectedDriver>((event, emit) {
      if (state is PayrollLoaded) {
        emit((state as PayrollLoaded).copyWith(clearDetails: true));
      }
    });
  }
}

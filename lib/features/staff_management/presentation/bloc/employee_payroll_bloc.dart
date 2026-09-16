import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/api/dio_client.dart';

// --- MODELS ---
class EmployeePayrollPreviewModel {
  final String employeeProfileId;
  final String fullName;
  final String department;
  final int payrollType; // 0 = Hourly, 1 = Salaried
  final double baseRate;
  final double unpaidHours;
  final double grossBasePay;
  final double pendingBonuses;
  final double taxDeductionAmount;
  final double netPayout;

  EmployeePayrollPreviewModel.fromJson(Map<String, dynamic> json)
    : employeeProfileId =
          (json['employeeProfileId'] ?? json['EmployeeProfileId'] ?? '')
              .toString(),
      fullName = json['fullName'] ?? json['FullName'] ?? 'Unknown',
      department = json['department'] ?? json['Department'] ?? 'General',
      payrollType = ((json['payrollType'] ?? json['PayrollType'] ?? 0) as num)
          .toInt(),
      baseRate = ((json['baseRate'] ?? json['BaseRate'] ?? 0) as num)
          .toDouble(),
      unpaidHours = ((json['unpaidHours'] ?? json['UnpaidHours'] ?? 0) as num)
          .toDouble(),
      grossBasePay =
          ((json['grossBasePay'] ?? json['GrossBasePay'] ?? 0) as num)
              .toDouble(),
      pendingBonuses =
          ((json['pendingBonuses'] ?? json['PendingBonuses'] ?? 0) as num)
              .toDouble(),
      taxDeductionAmount =
          ((json['taxDeductionAmount'] ?? json['TaxDeductionAmount'] ?? 0)
                  as num)
              .toDouble(),
      netPayout = ((json['netPayout'] ?? json['NetPayout'] ?? 0) as num)
          .toDouble();
}

// --- EVENTS ---
abstract class EmployeePayrollEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchEmployeePayroll extends EmployeePayrollEvent {}

class AddEmployeeBonus extends EmployeePayrollEvent {
  final String employeeProfileId;
  final double amount;
  final String reason;

  AddEmployeeBonus({
    required this.employeeProfileId,
    required this.amount,
    required this.reason,
  });

  @override
  List<Object> get props => [employeeProfileId, amount, reason];
}

class ExecuteEmployeeBatch extends EmployeePayrollEvent {
  final String bankWireReference;
  final bool isBiWeeklySalaryRun;

  ExecuteEmployeeBatch({
    required this.bankWireReference,
    required this.isBiWeeklySalaryRun,
  });

  @override
  List<Object> get props => [bankWireReference, isBiWeeklySalaryRun];
}

// --- STATES ---
abstract class EmployeePayrollState extends Equatable {
  @override
  List<Object> get props => [];
}

class EmployeePayrollLoading extends EmployeePayrollState {}

class EmployeePayrollLoaded extends EmployeePayrollState {
  final List<EmployeePayrollPreviewModel> payrolls;
  final double totalNetPayout;
  final double totalTaxWithheld;

  EmployeePayrollLoaded(this.payrolls)
    : totalNetPayout = payrolls.fold(0, (sum, item) => sum + item.netPayout),
      totalTaxWithheld = payrolls.fold(
        0,
        (sum, item) => sum + item.taxDeductionAmount,
      );

  @override
  List<Object> get props => [payrolls, totalNetPayout, totalTaxWithheld];
}

class EmployeePayrollError extends EmployeePayrollState {
  final String message;
  EmployeePayrollError(this.message);

  @override
  List<Object> get props => [message];
}

class EmployeePayrollSuccess extends EmployeePayrollState {
  final String message;
  EmployeePayrollSuccess(this.message);

  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class EmployeePayrollBloc
    extends Bloc<EmployeePayrollEvent, EmployeePayrollState> {
  final DioClient dioClient;

  EmployeePayrollBloc({required this.dioClient})
    : super(EmployeePayrollLoading()) {
    on<FetchEmployeePayroll>((event, emit) async {
      emit(EmployeePayrollLoading());
      try {
        final response = await dioClient.dio.get(
          '/api/admin/employee-payroll/preview',
        );
        final data = (response.data as List)
            .map((j) => EmployeePayrollPreviewModel.fromJson(j))
            .toList();
        emit(EmployeePayrollLoaded(data));
      } on DioException catch (e) {
        emit(
          EmployeePayrollError(
            e.response?.data?['message'] ??
                'Failed to load employee payroll ledger.',
          ),
        );
      } catch (_) {
        emit(
          EmployeePayrollError(
            'Network error while fetching employee payroll.',
          ),
        );
      }
    });

    on<AddEmployeeBonus>((event, emit) async {
      try {
        final res = await dioClient.dio.post(
          '/api/admin/employee-payroll/bonus',
          data: {
            'employeeProfileId': event.employeeProfileId,
            'amount': event.amount,
            'reason': event.reason,
          },
        );
        emit(
          EmployeePayrollSuccess(
            res.data?['message'] ?? 'Bonus appended successfully.',
          ),
        );
        add(FetchEmployeePayroll());
      } on DioException catch (e) {
        emit(
          EmployeePayrollError(
            e.response?.data?['message'] ?? 'Failed to append bonus.',
          ),
        );
      } catch (_) {
        emit(EmployeePayrollError('Error processing bonus addition.'));
      }
    });

    on<ExecuteEmployeeBatch>((event, emit) async {
      try {
        final res = await dioClient.dio.post(
          '/api/admin/employee-payroll/execute',
          data: {
            'bankWireReference': event.bankWireReference,
            'isBiWeeklySalaryRun': event.isBiWeeklySalaryRun,
          },
        );
        emit(
          EmployeePayrollSuccess(
            res.data?['message'] ?? 'Payroll executed successfully.',
          ),
        );
        add(FetchEmployeePayroll());
      } on DioException catch (e) {
        emit(
          EmployeePayrollError(
            e.response?.data?['message'] ?? 'Failed to execute payroll batch.',
          ),
        );
      } catch (_) {
        emit(EmployeePayrollError('Network error during batch execution.'));
      }
    });
  }
}

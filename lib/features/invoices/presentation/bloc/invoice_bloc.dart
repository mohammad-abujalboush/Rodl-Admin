import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:roadside_service/features/invoices/data/invoice_model.dart';
import '../../../../core/api/dio_client.dart';

// --- EVENTS ---
abstract class InvoicesEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchInvoices extends InvoicesEvent {}

class UpdateInvoiceStatus extends InvoicesEvent {
  final String invoiceId;
  final InvoiceStatus newStatus;

  UpdateInvoiceStatus({required this.invoiceId, required this.newStatus});

  @override
  List<Object> get props => [invoiceId, newStatus];
}

class DownloadInvoicePdf extends InvoicesEvent {
  final String invoiceId;
  DownloadInvoicePdf({required this.invoiceId});
  @override
  List<Object> get props => [invoiceId];
}

// NEW EVENT: Create Invoice
class CreateInvoice extends InvoicesEvent {
  final Map<String, dynamic> invoiceData;
  CreateInvoice({required this.invoiceData});
  @override
  List<Object> get props => [invoiceData];
}

class UpdateInvoice extends InvoicesEvent {
  final String invoiceId;
  final Map<String, dynamic> invoiceData;
  UpdateInvoice({required this.invoiceId, required this.invoiceData});
  @override
  List<Object> get props => [invoiceId, invoiceData];
}

class DeleteInvoice extends InvoicesEvent {
  final String invoiceId;
  DeleteInvoice({required this.invoiceId});
  @override
  List<Object> get props => [invoiceId];
}

// --- STATES ---
abstract class InvoicesState extends Equatable {
  @override
  List<Object> get props => [];
}

class InvoicesLoading extends InvoicesState {}

class InvoicesLoaded extends InvoicesState {
  final List<InvoiceModel> invoices;
  final double totalOutstanding;
  final double totalOverdue;
  final double paidThisMonth;

  InvoicesLoaded({
    required this.invoices,
    required this.totalOutstanding,
    required this.totalOverdue,
    required this.paidThisMonth,
  });

  @override
  List<Object> get props => [
    invoices,
    totalOutstanding,
    totalOverdue,
    paidThisMonth,
  ];
}

class InvoicesError extends InvoicesState {
  final String message;
  InvoicesError(this.message);
  @override
  List<Object> get props => [message];
}

class InvoiceActionSuccess extends InvoicesState {
  final String message;
  InvoiceActionSuccess(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class InvoicesBloc extends Bloc<InvoicesEvent, InvoicesState> {
  final DioClient dioClient;

  InvoicesBloc({required this.dioClient}) : super(InvoicesLoading()) {
    on<FetchInvoices>((event, emit) async {
      emit(InvoicesLoading());
      try {
        final response = await dioClient.dio.get('/api/admin/invoices');
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data['invoices'] ?? [];
          final invoices = data
              .map((json) => InvoiceModel.fromJson(json))
              .toList();

          final outstanding = invoices
              .where(
                (i) =>
                    i.status == InvoiceStatus.unpaid &&
                    i.type != InvoiceType.b2cReceipt,
              )
              .fold(0.0, (sum, i) => sum + i.totalAmount);
          final overdue = invoices
              .where((i) => i.status == InvoiceStatus.overdue)
              .fold(0.0, (sum, i) => sum + i.totalAmount);

          final now = DateTime.now();
          final paidThisMonth = invoices
              .where(
                (i) =>
                    i.status == InvoiceStatus.paid &&
                    i.issueDate.month == now.month &&
                    i.issueDate.year == now.year,
              )
              .fold(0.0, (sum, i) => sum + i.totalAmount);

          emit(
            InvoicesLoaded(
              invoices: invoices,
              totalOutstanding: outstanding,
              totalOverdue: overdue,
              paidThisMonth: paidThisMonth,
            ),
          );
        } else {
          emit(InvoicesError('Failed to load financial records.'));
        }
      } catch (e) {
        emit(InvoicesError('Network error while fetching invoices.'));
      }
    });

    on<UpdateInvoiceStatus>((event, emit) async {
      try {
        await dioClient.dio.put(
          '/api/admin/invoices/${event.invoiceId}/status',
          data: {'status': event.newStatus.index},
        );
        emit(InvoiceActionSuccess('Invoice status updated successfully.'));
        add(FetchInvoices());
      } catch (e) {
        emit(InvoicesError('Failed to update invoice status.'));
      }
    });

    on<CreateInvoice>((event, emit) async {
      try {
        await dioClient.dio.post(
          '/api/admin/invoices',
          data: event.invoiceData,
        );
        emit(
          InvoiceActionSuccess('Invoice generated and issued successfully.'),
        );
        add(FetchInvoices());
      } catch (e) {
        emit(
          InvoicesError(
            'Failed to generate invoice. Check network connection.',
          ),
        );
      }
    });

    on<UpdateInvoice>((event, emit) async {
      try {
        await dioClient.dio.put(
          '/api/admin/invoices/${event.invoiceId}',
          data: event.invoiceData,
        );
        emit(InvoiceActionSuccess('Invoice updated successfully.'));
        add(FetchInvoices());
      } catch (e) {
        emit(InvoicesError('Failed to update invoice.'));
      }
    });

    on<DeleteInvoice>((event, emit) async {
      try {
        await dioClient.dio.delete('/api/admin/invoices/${event.invoiceId}');
        emit(InvoiceActionSuccess('Invoice permanently deleted.'));
        add(FetchInvoices());
      } catch (e) {
        emit(InvoicesError('Failed to delete invoice.'));
      }
    });
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:roadside_service/features/helpdesk/data/models/support_ticket_model.dart';
import '../../../../core/api/dio_client.dart';

// --- EVENTS ---
abstract class HelpdeskEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchTickets extends HelpdeskEvent {}

class UpdateTicketStatus extends HelpdeskEvent {
  final String ticketId;
  final int newStatus;
  UpdateTicketStatus({required this.ticketId, required this.newStatus});
  @override
  List<Object> get props => [ticketId, newStatus];
}

class UpdateTicketNote extends HelpdeskEvent {
  final String ticketId;
  final String note;
  UpdateTicketNote({required this.ticketId, required this.note});
  @override
  List<Object> get props => [ticketId, note];
}

class CreateManualTicket extends HelpdeskEvent {
  final String subject;
  final String description;
  final String? customerId;
  final String customerName;
  final int priority;

  CreateManualTicket({
    required this.subject,
    required this.description,
    this.customerId,
    required this.customerName,
    required this.priority,
  });

  @override
  List<Object?> get props => [
    subject,
    description,
    customerId,
    customerName,
    priority,
  ];
}

// --- STATES ---
abstract class HelpdeskState extends Equatable {
  @override
  List<Object> get props => [];
}

class HelpdeskLoading extends HelpdeskState {}

class HelpdeskLoaded extends HelpdeskState {
  final List<SupportTicketModel> tickets;
  HelpdeskLoaded(this.tickets);
  @override
  List<Object> get props => [tickets];
}

class HelpdeskError extends HelpdeskState {
  final String message;
  HelpdeskError(this.message);
  @override
  List<Object> get props => [message];
}

class HelpdeskActionSuccess extends HelpdeskState {
  final String message;
  HelpdeskActionSuccess(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class HelpdeskBloc extends Bloc<HelpdeskEvent, HelpdeskState> {
  final DioClient dioClient;

  HelpdeskBloc({required this.dioClient}) : super(HelpdeskLoading()) {
    on<FetchTickets>((event, emit) async {
      emit(HelpdeskLoading());
      try {
        final response = await dioClient.dio.get('/api/admin/tickets');
        if (response.statusCode == 200) {
          final tickets = (response.data as List)
              .map((json) => SupportTicketModel.fromJson(json))
              .toList();
          emit(HelpdeskLoaded(tickets));
        } else {
          emit(HelpdeskError('Failed to load support tickets.'));
        }
      } catch (e) {
        emit(HelpdeskError('Network error while fetching tickets.'));
      }
    });

    on<UpdateTicketStatus>((event, emit) async {
      try {
        final response = await dioClient.dio.put(
          '/api/admin/tickets/${event.ticketId}/status',
          data: {'status': event.newStatus},
        );
        if (response.statusCode == 200) {
          emit(HelpdeskActionSuccess('Ticket status updated.'));
          add(FetchTickets());
        }
      } catch (e) {
        emit(HelpdeskError('Failed to update ticket status.'));
      }
    });

    on<UpdateTicketNote>((event, emit) async {
      try {
        final response = await dioClient.dio.put(
          '/api/admin/tickets/${event.ticketId}/note',
          data: {'note': event.note},
        );
        if (response.statusCode == 200) {
          emit(HelpdeskActionSuccess('Internal note saved.'));
          add(FetchTickets());
        }
      } catch (e) {
        emit(HelpdeskError('Failed to save ticket note.'));
      }
    });

    on<CreateManualTicket>((event, emit) async {
      try {
        final response = await dioClient.dio.post(
          '/api/admin/tickets/create',
          data: {
            'subject': event.subject,
            'description': event.description,
            'customerId': event.customerId,
            'customerName': event.customerName,
            'priority': event.priority,
          },
        );
        if (response.statusCode == 200) {
          emit(HelpdeskActionSuccess('Ticket logged successfully.'));
          add(FetchTickets());
        }
      } catch (e) {
        emit(HelpdeskError('Failed to create manual ticket.'));
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

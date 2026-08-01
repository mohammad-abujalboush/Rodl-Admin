import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:roadside_service/features/customer_crm/data/models/customer_crm_models.dart';
import '../../../../core/api/dio_client.dart';

// --- EVENTS ---
abstract class CustomerCrmEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchCustomers extends CustomerCrmEvent {}

class FetchCustomerProfile extends CustomerCrmEvent {
  final String customerId;
  FetchCustomerProfile({required this.customerId});
  @override
  List<Object> get props => [customerId];
}

class CreateNewCustomer extends CustomerCrmEvent {
  final String fullName;
  final String phone;
  final String email;
  CreateNewCustomer({
    required this.fullName,
    required this.phone,
    required this.email,
  });
  @override
  List<Object?> get props => [fullName, phone, email];
}

class UpdateCustomerInfo extends CustomerCrmEvent {
  final String customerId;
  final String fullName;
  final String phone;
  final String email;
  UpdateCustomerInfo({
    required this.customerId,
    required this.fullName,
    required this.phone,
    required this.email,
  });
  @override
  List<Object?> get props => [customerId, fullName, phone, email];
}

class DeleteCustomer extends CustomerCrmEvent {
  final String customerId;
  DeleteCustomer({required this.customerId});
  @override
  List<Object> get props => [customerId];
}

class AddCustomerVehicle extends CustomerCrmEvent {
  final String customerId;
  final Map<String, dynamic> vehicleData;
  AddCustomerVehicle({required this.customerId, required this.vehicleData});
}

// NEW: Edit Customer Vehicle Event
class EditCustomerVehicle extends CustomerCrmEvent {
  final String customerId;
  final String vehicleId;
  final Map<String, dynamic> vehicleData;
  EditCustomerVehicle({
    required this.customerId,
    required this.vehicleId,
    required this.vehicleData,
  });
}

class RemoveCustomerVehicle extends CustomerCrmEvent {
  final String customerId;
  final String vehicleId;
  RemoveCustomerVehicle({required this.customerId, required this.vehicleId});
}

// --- STATES ---
abstract class CustomerCrmState extends Equatable {
  @override
  List<Object> get props => [];
}

class CrmLoading extends CustomerCrmState {}

class ProfileLoading extends CustomerCrmState {}

class CrmError extends CustomerCrmState {
  final String message;
  CrmError(this.message);
  @override
  List<Object> get props => [message];
}

class CustomersLoaded extends CustomerCrmState {
  final List<CustomerModel> customers;
  CustomersLoaded({required this.customers});
  @override
  List<Object> get props => [customers];
}

class CustomerProfileLoaded extends CustomerCrmState {
  final CustomerProfileModel profile;
  CustomerProfileLoaded({required this.profile});
  @override
  List<Object> get props => [profile];
}

class CustomerActionSuccess extends CustomerCrmState {
  final String message;
  CustomerActionSuccess(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class CustomerCrmBloc extends Bloc<CustomerCrmEvent, CustomerCrmState> {
  final DioClient dioClient;

  CustomerCrmBloc({required this.dioClient}) : super(CrmLoading()) {
    on<FetchCustomers>((event, emit) async {
      emit(CrmLoading());
      try {
        final response = await dioClient.dio.get('/api/admin/customers');
        final customers = (response.data as List)
            .map((json) => CustomerModel.fromJson(json))
            .toList();
        emit(CustomersLoaded(customers: customers));
      } catch (e) {
        emit(CrmError('Failed to fetch CRM directory.'));
      }
    });

    on<FetchCustomerProfile>((event, emit) async {
      emit(ProfileLoading());
      try {
        final response = await dioClient.dio.get(
          '/api/admin/customers/${event.customerId}/dossier',
        );
        emit(
          CustomerProfileLoaded(
            profile: CustomerProfileModel.fromJson(response.data),
          ),
        );
      } catch (e) {
        emit(CrmError('Failed to load customer profile.'));
      }
    });

    on<CreateNewCustomer>((event, emit) async {
      emit(CrmLoading());
      try {
        final response = await dioClient.dio.post(
          '/api/admin/customers',
          data: {
            'fullName': event.fullName,
            'phoneNumber': event.phone,
            'email': event.email,
          },
        );
        if (response.statusCode == 200) {
          emit(
            CustomerActionSuccess('Profile Activated & Credentials Emailed.'),
          );
          add(FetchCustomers());
        }
      } catch (e) {
        emit(CrmError('Failed to create customer profile.'));
      }
    });

    on<UpdateCustomerInfo>((event, emit) async {
      try {
        await dioClient.dio.put(
          '/api/admin/customers/${event.customerId}',
          data: {
            'fullName': event.fullName,
            'phoneNumber': event.phone,
            'email': event.email,
          },
        );
        emit(CustomerActionSuccess('Identity details updated.'));
        add(FetchCustomerProfile(customerId: event.customerId));
      } catch (e) {
        emit(CrmError('Network error while updating customer.'));
      }
    });

    on<DeleteCustomer>((event, emit) async {
      try {
        await dioClient.dio.delete('/api/admin/customers/${event.customerId}');
        emit(CustomerActionSuccess('Customer permanently removed.'));
        add(FetchCustomers());
      } on DioException catch (e) {
        if (e.response?.statusCode == 400) {
          emit(
            CrmError(
              e.response?.data['message'] ??
                  'Cannot delete customer with history.',
            ),
          );
        } else {
          emit(CrmError('Failed to delete customer.'));
        }
      }
    });

    on<AddCustomerVehicle>((event, emit) async {
      try {
        await dioClient.dio.post(
          '/api/admin/customers/${event.customerId}/vehicles',
          data: event.vehicleData,
        );
        emit(CustomerActionSuccess('Vehicle securely added to profile.'));
        add(FetchCustomerProfile(customerId: event.customerId));
      } catch (e) {
        emit(CrmError('Failed to add vehicle.'));
      }
    });

    // NEW: Handle Editing Existing Vehicles
    on<EditCustomerVehicle>((event, emit) async {
      try {
        await dioClient.dio.put(
          '/api/admin/vehicles/${event.vehicleId}',
          data: event.vehicleData,
        );
        emit(CustomerActionSuccess('Vehicle details updated.'));
        add(FetchCustomerProfile(customerId: event.customerId));
      } catch (e) {
        emit(CrmError('Failed to update vehicle.'));
      }
    });

    on<RemoveCustomerVehicle>((event, emit) async {
      try {
        await dioClient.dio.delete('/api/admin/vehicles/${event.vehicleId}');
        emit(CustomerActionSuccess('Vehicle detached from profile.'));
        add(FetchCustomerProfile(customerId: event.customerId));
      } catch (e) {
        emit(CrmError('Failed to remove vehicle.'));
      }
    });
  }
}

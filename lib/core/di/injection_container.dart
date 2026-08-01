import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:roadside_service/features/Marketing/presentation/bloc/marketing_bloc.dart';
import 'package:roadside_service/features/dispatch_builder/presentation/bloc/dispatch_rulers_bloc.dart';
import 'package:roadside_service/features/drivers_management/presentation/bloc/driver_management_bloc.dart';
import 'package:roadside_service/features/invoices/presentation/bloc/invoice_bloc.dart';
import 'package:roadside_service/features/payroll_desk/presentation/bloc/payroll_desk_bloc.dart';
import 'package:roadside_service/features/staff_management/presentation/bloc/staff_bloc.dart';

// Core
import '../api/dio_client.dart';
import '../api/secure_storage_helper.dart';
import '../api/signalr_client.dart';

// Features - Auth
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// Features - Admin / Pricing
import 'package:roadside_service/features/pricing_engine/domain/repositories/admin_repository.dart';
import 'package:roadside_service/features/pricing_engine/domain/repositories/admin_repository_impl.dart';

// Features - Blocs
import '../../features/dashboard_home/presentation/bloc/dashboard_bloc.dart';
import '../../features/live_radar/presentation/bloc/live_radar_bloc.dart';
import '../../features/service_requests/presentation/bloc/active_jobs_bloc.dart';
import '../../features/pricing_engine/presentation/bloc/pricing_engine_bloc.dart';

// NEW Features - Blocs
import '../../features/customer_crm/presentation/bloc/customer_crm_bloc.dart';
import '../../features/helpdesk/presentation/bloc/helpdesk_bloc.dart';
import '../../features/incident_review/presentation/bloc/incident_review_bloc.dart';
import '../../features/system_settings/presentation/bloc/system_settings_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // 1. External Packages
  sl.registerLazySingleton(() => Dio());
  sl.registerLazySingleton(() => const FlutterSecureStorage());

  // 2. Core API & Real-time
  sl.registerLazySingleton(() => SecureStorageHelper(sl()));
  sl.registerLazySingleton(() => DioClient(sl(), sl()));
  sl.registerLazySingleton(() => SignalRClient(sl()));

  // 3. Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl(), sl(), sl()),
  );

  sl.registerLazySingleton<AdminRepository>(() => AdminRepositoryImpl(sl()));

  // 4. Blocs
  sl.registerFactory(() => AuthBloc(authRepository: sl()));
  sl.registerFactory(() => DashboardBloc(dioClient: sl()));
  sl.registerFactory(() => LiveRadarBloc(signalRClient: sl(), dioClient: sl()));
  sl.registerFactory(() => ActiveJobsBloc(dioClient: sl()));
  sl.registerFactory(() => PricingEngineBloc(dioClient: sl()));

  // ---> Enterprise Blocs <---
  sl.registerFactory(() => DispatchRulesBloc(dioClient: sl()));
  sl.registerFactory(() => PayrollDeskBloc(dioClient: sl()));
  sl.registerFactory(() => CustomerCrmBloc(dioClient: sl()));
  sl.registerFactory(() => HelpdeskBloc(dioClient: sl()));
  sl.registerFactory(() => IncidentReviewBloc(dioClient: sl()));
  sl.registerFactory(() => SystemSettingsBloc(dioClient: sl()));
  sl.registerFactory(() => DriverManagementBloc(dioClient: sl()));
  sl.registerFactory(() => StaffManagementBloc(dioClient: sl()));
  sl.registerFactory(() => InvoicesBloc(dioClient: sl()));
  sl.registerFactory(() => MarketingBloc(dioClient: sl()));
}

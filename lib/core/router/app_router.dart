import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:roadside_service/features/Marketing/presentation/screen/marketing_management_screen.dart';
import 'package:roadside_service/features/communication/presentation/call_management_screen.dart';
import 'package:roadside_service/features/drivers_management/presentation/screens/driver_management_screen.dart';
import 'package:roadside_service/features/financial_overview/data/api_data.dart';
import 'package:roadside_service/features/financial_overview/presentation/financial_overview_screen.dart';
import 'package:roadside_service/features/invoices/presentation/presentation/invoices_screen.dart';
import 'package:roadside_service/features/staff_management/presentation/screen/staff_management_screen.dart';
import '../api/secure_storage_helper.dart';
import '../di/injection_container.dart';
import '../layout/dashboard_layout.dart';

// Feature Screens
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard_home/presentation/screens/dashboard_home_screen.dart';
import '../../features/live_radar/presentation/screens/live_radar_screen.dart';
// FIXED: Renamed to match the pluralized file we just created
import '../../features/service_requests/presentation/screens/active_jobs_screen.dart';
import '../../features/pricing_engine/presentation/screens/pricing_engine_screen.dart';
import '../../features/dispatch_builder/presentation/screens/visual_builder_screen.dart';

// NEW Feature Screens
import '../../features/payroll_desk/presentation/screens/payroll_desk_screen.dart';
import '../../features/customer_crm/presentation/screens/customer_crm_screen.dart';
import '../../features/helpdesk/presentation/screens/helpdesk_screen.dart';
import '../../features/incident_review/presentation/screens/incident_review_screen.dart';
import '../../features/system_settings/presentation/screens/system_settings_screen.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) async {
      final secureStorage = sl<SecureStorageHelper>();
      final token = await secureStorage.getToken();

      final isLoggingIn = state.matchedLocation == '/login';

      if (token == null && !isLoggingIn) return '/login';
      if (token != null && isLoggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return DashboardLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardHomeScreen(),
          ),
          GoRoute(
            path: '/live-radar',
            builder: (context, state) => const LiveRadarScreen(),
          ),
          GoRoute(
            path: '/active-jobs',
            builder: (context, state) {
              final extraData = state.extra as Map<String, dynamic>?;
              return ActiveJobsScreen(
                // Auto-fill new dispatch
                prefillCustomerData: extraData?['prefill'],
                // Auto-open existing dispatch modal
                autoOpenJobId: extraData?['autoOpenJobId'],
              );
            },
          ),
          GoRoute(
            path: '/driver-approvals',
            builder: (context, state) => const DriverManagementScreen(),
          ),
          GoRoute(
            path: '/pricing',
            builder: (context, state) => const PricingEngineScreen(),
          ),
          GoRoute(
            path: '/financial-overview',
            builder: (context, state) => FinancialOverviewScreen(
              apiService: FinancialLedgerService(sl()),
            ),
          ),
          GoRoute(
            path: '/dispatch-builder',
            builder: (context, state) => const VisualBuilderScreen(),
          ),
          GoRoute(
            path: '/staff-management',
            builder: (context, state) => const StaffManagementScreen(),
          ),

          GoRoute(
            path: '/payroll',
            builder: (context, state) => const PayrollDeskScreen(),
          ),
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const InvoicesScreen(),
          ),
          GoRoute(
            path: '/crm',
            builder: (context, state) => const CustomerCrmScreen(),
          ),
          GoRoute(
            path: '/helpdesk',
            builder: (context, state) => const HelpdeskScreen(),
          ),
          GoRoute(
            path: '/incidents',
            builder: (context, state) => const IncidentReviewScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SystemSettingsScreen(),
          ),
          GoRoute(
            path: '/call-management',
            builder: (context, state) => const CallManagementScreen(),
          ),
          GoRoute(
            path: '/marketing',
            builder: (context, state) => const MarketingManagementScreen(),
          ),
        ],
      ),
    ],
  );
}

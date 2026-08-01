import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:roadside_service/core/utils/call_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/driver_management_bloc.dart';
import '../../data/models/driver_management_models.dart';

class DriverManagementScreen extends StatelessWidget {
  const DriverManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DriverManagementBloc>()..add(FetchFleetData()),
      child: const _DriverManagementView(),
    );
  }
}

class _DriverManagementView extends StatefulWidget {
  const _DriverManagementView();

  @override
  State<_DriverManagementView> createState() => _DriverManagementViewState();
}

class _DriverManagementViewState extends State<_DriverManagementView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, context),
              const SizedBox(height: 24),
              SizedBox(
                width: 400,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID, phone, or vehicle...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: theme.primaryColor,
                  indicatorWeight: 3,
                  labelColor: theme.primaryColor,
                  unselectedLabelColor: theme.disabledColor,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(text: 'Active Fleet Directory (CRM)'),
                    Tab(text: 'Pending Approvals / Compliance'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child:
                    BlocConsumer<DriverManagementBloc, DriverManagementState>(
                      listener: (context, state) {
                        if (state is FleetError) {
                          _showSnackBar(
                            context,
                            state.message,
                            theme.colorScheme.error,
                          );
                          context.read<DriverManagementBloc>().add(
                            FetchFleetData(),
                          );
                        } else if (state is FleetActionSuccess) {
                          _showSnackBar(
                            context,
                            state.message,
                            Colors.green.shade700,
                          );
                          context.read<DriverManagementBloc>().add(
                            FetchFleetData(),
                          );
                        }
                      },
                      buildWhen: (prev, current) =>
                          current is FleetLoaded || current is FleetLoading,
                      builder: (context, state) {
                        if (state is FleetLoading)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        if (state is FleetLoaded) {
                          final filteredActive = state.activeFleet
                              .where(
                                (d) =>
                                    d.fullName.toLowerCase().contains(
                                      _searchQuery,
                                    ) ||
                                    d.phoneNumber.contains(_searchQuery) ||
                                    d.driverProfileId.toLowerCase().contains(
                                      _searchQuery,
                                    ),
                              )
                              .toList();

                          final filteredPending = state.pendingQueue
                              .where(
                                (d) =>
                                    d.fullName.toLowerCase().contains(
                                      _searchQuery,
                                    ) ||
                                    d.phoneNumber.contains(_searchQuery) ||
                                    d.driverProfileId.toLowerCase().contains(
                                      _searchQuery,
                                    ),
                              )
                              .toList();

                          return TabBarView(
                            controller: _tabController,
                            children: [
                              _buildActiveFleetTab(filteredActive, theme),
                              _buildPendingApprovalsTab(filteredPending, theme),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fleet Operations',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage active drivers, vehicle routing, and compliance documents.',
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
        Row(
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text(
                'Manual Onboard',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showManualOnboardDialog(context, theme),
            ),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: IconButton(
                icon: Icon(Icons.refresh, color: theme.primaryColor),
                tooltip: 'Refresh Data',
                onPressed: () =>
                    context.read<DriverManagementBloc>().add(FetchFleetData()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- ACTIVE FLEET TAB ---
  Widget _buildActiveFleetTab(
    List<FleetDriverModel> activeFleet,
    ThemeData theme,
  ) {
    if (activeFleet.isEmpty) {
      return Center(
        child: Text(
          'No active drivers match your search.',
          style: TextStyle(color: theme.disabledColor, fontSize: 16),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: theme.primaryColor.withValues(alpha: 0.03),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('DRIVER PROFILE', style: _headerStyle(theme)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('ASSIGNED VEHICLE', style: _headerStyle(theme)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('LIVE STATUS', style: _headerStyle(theme)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'MANAGEMENT',
                    style: _headerStyle(theme),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: activeFleet.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) {
                final d = activeFleet[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: theme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              child: const Icon(
                                Icons.engineering,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  d.phoneNumber,
                                  style: TextStyle(
                                    color: theme.disabledColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              d.vehicleSummary,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              d.truckTypeText,
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            label: Text(
                              d.isSuspended
                                  ? 'Suspended'
                                  : d.isOnJob
                                  ? 'On Job'
                                  : d.isOnline
                                  ? 'Available'
                                  : 'Offline',
                              style: TextStyle(
                                color: d.isSuspended
                                    ? Colors.red.shade800
                                    : d.isOnJob
                                    ? Colors.orange.shade800
                                    : d.isOnline
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            backgroundColor:
                                (d.isSuspended
                                        ? Colors.red
                                        : d.isOnJob
                                        ? Colors.orange
                                        : d.isOnline
                                        ? Colors.green
                                        : Colors.grey)
                                    .withValues(alpha: 0.1),
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // AGORA CALL OPERATOR BUTTON
                            IconButton(
                              icon: const Icon(
                                Icons.phone_in_talk,
                                color: Colors.greenAccent,
                                size: 20,
                              ),
                              tooltip: 'Call Driver via Agora',
                              onPressed: () => triggerVoiceCall(
                                context: context,
                                dioClient: sl<DioClient>(),
                                receiverUserId: d.driverProfileId,
                                currentUserId: 'ADMIN',
                                receiverName: d.fullName,
                                reason:
                                    'Fleet Operations Dispatch Communication',
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                d.isSuspended ? Icons.restore : Icons.block,
                                color: d.isSuspended
                                    ? Colors.blue
                                    : theme.colorScheme.error,
                                size: 20,
                              ),
                              tooltip: d.isSuspended
                                  ? 'Reactivate Driver'
                                  : 'Suspend Driver',
                              onPressed: () =>
                                  context.read<DriverManagementBloc>().add(
                                    ToggleDriverStatus(
                                      driverProfileId: d.driverProfileId,
                                      isSuspended: !d.isSuspended,
                                    ),
                                  ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.folder_shared, size: 16),
                              label: const Text('Manage'),
                              onPressed: () =>
                                  _showActiveDriverDossier(context, d, theme),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle(ThemeData theme) => TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 12,
    letterSpacing: 0.5,
    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
  );

  // --- PENDING APPROVALS TAB ---
  Widget _buildPendingApprovalsTab(
    List<FleetDriverModel> drivers,
    ThemeData theme,
  ) {
    if (drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Inbox Zero',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'All driver applications have been processed.',
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
      );
    }

    return ResponsiveBuilder(
      builder: (context, sizingInfo) {
        int crossAxisCount = sizingInfo.isDesktop ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.only(top: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 1.5,
          ),
          itemCount: drivers.length,
          itemBuilder: (context, index) =>
              _buildApplicationCard(context, drivers[index], theme),
        );
      },
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    FleetDriverModel driver,
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.badge, color: theme.primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Applied: ${DateFormat('MMM dd, yyyy').format(driver.appliedAt)}',
                        style: TextStyle(
                          color: theme.disabledColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  driver.phoneNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.local_shipping, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    driver.vehicleSummary,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.fact_check),
                label: const Text('Review Compliance Docs'),
                onPressed: () => _showReviewDialog(context, driver, theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DOSSIER MODAL (ACTIVE DRIVERS) ---
  void _showActiveDriverDossier(
    BuildContext parentContext,
    FleetDriverModel driver,
    ThemeData theme,
  ) {
    final docs = driver.documents;
    final vehicle = driver.vehicleDetails;
    final bloc = parentContext.read<DriverManagementBloc>();

    showDialog(
      context: parentContext,
      builder: (dialogContext) => Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 1000,
          height: 800,
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Fleet Management: ${driver.fullName}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View and manage the active profile for this fleet driver.',
                        style: TextStyle(color: theme.disabledColor),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.phone),
                        label: const Text('Call Operator'),
                        onPressed: () => triggerVoiceCall(
                          context: parentContext,
                          dioClient: sl<DioClient>(),
                          receiverUserId: driver.driverProfileId,
                          currentUserId: 'ADMIN',
                          receiverName: driver.fullName,
                          reason: 'Dossier Audit Communications',
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Edit Driver Details',
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _showEditDriverDialog(parentContext, driver, theme);
                        },
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 48),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DRIVER DETAILS',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(Icons.person),
                          ),
                          title: Text(
                            driver.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            'ID: ${driver.driverProfileId.substring(0, 8)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(Icons.phone),
                          ),
                          title: Text(
                            driver.phoneNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: const Text(
                            'Primary Contact',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ASSET ASSIGNMENT',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(Icons.local_shipping),
                          ),
                          title: Text(
                            driver.vehicleSummary,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            driver.truckTypeText,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(Icons.pin),
                          ),
                          title: Text(
                            vehicle != null && vehicle['licensePlate'] != null
                                ? vehicle['licensePlate']
                                : 'Unregistered',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: const Text(
                            'License Plate',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 48),
              Text(
                'LEGAL COMPLIANCE DOCUMENTS',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDocumentTile(
                        parentContext,
                        'Government ID',
                        docs['Government ID'],
                        theme,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDocumentTile(
                        parentContext,
                        'Driving License',
                        docs['Driving License'],
                        theme,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDocumentTile(
                        parentContext,
                        'Commercial Insurance',
                        docs['Commercial Insurance'],
                        theme,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDocumentTile(
                        parentContext,
                        'Background Check',
                        docs['Background Check'],
                        theme,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text(
                      'Delete Account',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      bloc.add(
                        DeleteDriver(driverProfileId: driver.driverProfileId),
                      );
                      Navigator.pop(dialogContext);
                    },
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: driver.isSuspended
                          ? Colors.blue
                          : Colors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                    ),
                    icon: Icon(
                      driver.isSuspended ? Icons.restore : Icons.block,
                    ),
                    label: Text(
                      driver.isSuspended
                          ? 'Reactivate Access'
                          : 'Suspend Driver',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      bloc.add(
                        ToggleDriverStatus(
                          driverProfileId: driver.driverProfileId,
                          isSuspended: !driver.isSuspended,
                        ),
                      );
                      Navigator.pop(dialogContext);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- REVIEW MODAL (PENDING DRIVERS) ---
  void _showReviewDialog(
    BuildContext parentContext,
    FleetDriverModel driver,
    ThemeData theme,
  ) {
    final docs = driver.documents;
    final vehicle = driver.vehicleDetails;
    final bloc = parentContext.read<DriverManagementBloc>();

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 1000,
          height: 800,
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compliance Verification: ${driver.fullName}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review the uploaded documents and asset details to verify legal compliance.',
                        style: TextStyle(color: theme.disabledColor),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Edit Driver Details',
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _showEditDriverDialog(parentContext, driver, theme);
                        },
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 48),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DRIVER DETAILS',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(Icons.person),
                          ),
                          title: Text(
                            driver.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            'ID: ${driver.driverProfileId.substring(0, 8)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(Icons.phone),
                          ),
                          title: Text(
                            driver.phoneNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: const Text(
                            'Primary Contact',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ASSET ASSIGNMENT',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(Icons.local_shipping),
                          ),
                          title: Text(
                            driver.vehicleSummary,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            driver.truckTypeText,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(Icons.pin),
                          ),
                          title: Text(
                            vehicle != null && vehicle['licensePlate'] != null
                                ? vehicle['licensePlate']
                                : 'Unregistered',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: const Text(
                            'License Plate',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 48),
              Text(
                'LEGAL COMPLIANCE DOCUMENTS',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDocumentTile(
                        parentContext,
                        'Government ID',
                        docs['Government ID'],
                        theme,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDocumentTile(
                        parentContext,
                        'Driving License',
                        docs['Driving License'],
                        theme,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDocumentTile(
                        parentContext,
                        'Commercial Insurance',
                        docs['Commercial Insurance'],
                        theme,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDocumentTile(
                        parentContext,
                        'Background Check',
                        docs['Background Check'],
                        theme,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                    ),
                    icon: const Icon(Icons.block),
                    label: const Text(
                      'Reject Application',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      bloc.add(
                        ReviewApplication(
                          driverProfileId: driver.driverProfileId,
                          isApproved: false,
                        ),
                      );
                      Navigator.pop(dialogContext);
                    },
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                    ),
                    icon: const Icon(Icons.verified),
                    label: const Text(
                      'Approve & Activate Driver',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      bloc.add(
                        ReviewApplication(
                          driverProfileId: driver.driverProfileId,
                          isApproved: true,
                        ),
                      );
                      Navigator.pop(dialogContext);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTile(
    BuildContext context,
    String title,
    String? url,
    ThemeData theme,
  ) {
    final bool hasDoc = url != null && url.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: hasDoc
                ? () async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open document URL.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                : null,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: hasDoc
                    ? theme.primaryColor.withValues(alpha: 0.05)
                    : theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasDoc
                      ? theme.primaryColor.withValues(alpha: 0.5)
                      : theme.dividerColor,
                ),
              ),
              child: hasDoc
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.description,
                          size: 48,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'View File',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Text(
                        'Not Uploaded',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  static const Map<String, List<String>> _vehicleDatabase = {
    'Ford': [
      'F-150',
      'F-250',
      'F-350',
      'F-450',
      'F-550',
      'F-650',
      'Transit Van',
      'E-Series Van',
    ],
    'RAM': ['1500', '2500', '3500', '4500', '5500', 'ProMaster Van'],
    'Chevrolet / GMC': [
      'Silverado/Sierra 1500',
      'Silverado/Sierra 2500HD',
      'Silverado/Sierra 3500HD',
      'Silverado/Sierra 4500HD',
      'Silverado/Sierra 5500HD',
      'Express/Savana Van',
    ],
    'Freightliner': ['M2 106', 'Cascadia', 'Business Class'],
    'Hino': ['155', '195', '258', '338', 'L Series'],
    'Isuzu': ['NPR', 'NQR', 'NRR', 'F-Series'],
    'Peterbilt': ['Model 330', 'Model 337', 'Model 348', 'Model 389'],
    'Kenworth': ['T270', 'T280', 'T370', 'T380', 'T880'],
    'International': ['MV Series', 'CV Series', 'HV Series'],
    'Toyota': ['Tundra', 'Tacoma'],
  };

  void _showManualOnboardDialog(BuildContext parentContext, ThemeData theme) {
    final formKey = GlobalKey<FormState>();
    final bloc = parentContext.read<DriverManagementBloc>();

    final nameCtrl = TextEditingController();
    final personalPhoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final employeeIdCtrl = TextEditingController();
    final toolPhoneCtrl = TextEditingController();
    final plateCtrl = TextEditingController();

    int truckType = 1;
    String? selectedMake;
    String? selectedModel;
    int selectedYear = DateTime.now().year;
    String selectedFuel = 'Diesel';
    final List<int> yearsList = List.generate(
      30,
      (index) => DateTime.now().year + 1 - index,
    );

    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: theme.scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              width: 900,
              padding: const EdgeInsets.all(40),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Manual Driver & Asset Setup',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    const Divider(height: 48),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Driver Information',
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: nameCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Full Name *',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: theme.cardColor,
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: employeeIdCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Employee / Internal ID *',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: theme.cardColor,
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: personalPhoneCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Personal Phone *',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: theme.cardColor,
                                    ),
                                    keyboardType: TextInputType.phone,
                                    style: const TextStyle(color: Colors.white),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: toolPhoneCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Company Truck Phone',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: theme.cardColor,
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: emailCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Email Address (For Login) *',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: theme.cardColor,
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 40),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fleet Asset Assignment',
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<int>(
                                    key: ValueKey(truckType),
                                    initialValue: truckType,
                                    dropdownColor: theme.cardColor,
                                    decoration: InputDecoration(
                                      labelText: 'Asset Category *',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: theme.cardColor,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 1,
                                        child: Text(
                                          'Standard Wrecker (Wheel Lift)',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 2,
                                        child: Text(
                                          'Flatbed Rollback',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 3,
                                        child: Text(
                                          'Low Clearance / Underground',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 4,
                                        child: Text(
                                          'Heavy Duty Rotator (Commercial)',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 5,
                                        child: Text(
                                          'Light Service (No Towing)',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 6,
                                        child: Text(
                                          'Motorcycle Dedicated Trailer',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) =>
                                        setModalState(() => truckType = val!),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          dropdownColor: theme.cardColor,
                                          decoration: InputDecoration(
                                            labelText: 'Make *',
                                            border: const OutlineInputBorder(),
                                            filled: true,
                                            fillColor: theme.cardColor,
                                          ),
                                          value: selectedMake,
                                          items: _vehicleDatabase.keys
                                              .map(
                                                (make) => DropdownMenuItem(
                                                  value: make,
                                                  child: Text(
                                                    make,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (val) => setModalState(() {
                                            selectedMake = val;
                                            selectedModel = null;
                                          }),
                                          validator: (v) =>
                                              v == null ? 'Req' : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          dropdownColor: theme.cardColor,
                                          decoration: InputDecoration(
                                            labelText: 'Model *',
                                            border: const OutlineInputBorder(),
                                            filled: true,
                                            fillColor: theme.cardColor,
                                          ),
                                          value: selectedModel,
                                          items: selectedMake == null
                                              ? []
                                              : _vehicleDatabase[selectedMake]!
                                                    .map(
                                                      (
                                                        model,
                                                      ) => DropdownMenuItem(
                                                        value: model,
                                                        child: Text(
                                                          model,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                          onChanged: (val) => setModalState(
                                            () => selectedModel = val,
                                          ),
                                          validator: (v) =>
                                              v == null ? 'Req' : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          key: ValueKey(selectedYear),
                                          initialValue: selectedYear,
                                          dropdownColor: theme.cardColor,
                                          decoration: InputDecoration(
                                            labelText: 'Year *',
                                            border: const OutlineInputBorder(),
                                            filled: true,
                                            fillColor: theme.cardColor,
                                          ),
                                          items: yearsList
                                              .map(
                                                (year) => DropdownMenuItem(
                                                  value: year,
                                                  child: Text(
                                                    year.toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (val) => setModalState(
                                            () => selectedYear = val!,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          key: ValueKey(selectedFuel),
                                          initialValue: selectedFuel,
                                          dropdownColor: theme.cardColor,
                                          decoration: InputDecoration(
                                            labelText: 'Fuel Type *',
                                            border: const OutlineInputBorder(),
                                            filled: true,
                                            fillColor: theme.cardColor,
                                          ),
                                          items:
                                              [
                                                    'Diesel',
                                                    'Gasoline',
                                                    'Hybrid',
                                                    'Fully Electric',
                                                  ]
                                                  .map(
                                                    (fuel) => DropdownMenuItem(
                                                      value: fuel,
                                                      child: Text(
                                                        fuel,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged: (val) => setModalState(
                                            () => selectedFuel = val!,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: plateCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'License Plate / Tag *',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: theme.cardColor,
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.person_add),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            bloc.add(
                              ManualOnboard(
                                driverData: {
                                  'fullName': nameCtrl.text.trim(),
                                  'phoneNumber': personalPhoneCtrl.text.trim(),
                                  'toolPhoneNumber': toolPhoneCtrl.text.trim(),
                                  'email': emailCtrl.text.trim(),
                                  'employeeId': employeeIdCtrl.text.trim(),
                                  'vehicleMake': selectedMake,
                                  'vehicleModel': selectedModel,
                                  'vehicleYear': selectedYear,
                                  'fuelType': selectedFuel,
                                  'licensePlate': plateCtrl.text.trim(),
                                  'truckType': truckType,
                                },
                              ),
                            );
                            Navigator.pop(dialogContext);
                          }
                        },
                        label: const Text(
                          'Save & Generate Credentials',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditDriverDialog(
    BuildContext parentContext,
    FleetDriverModel driver,
    ThemeData theme,
  ) {
    final formKey = GlobalKey<FormState>();
    final bloc = parentContext.read<DriverManagementBloc>();

    final nameCtrl = TextEditingController(text: driver.fullName);
    final personalPhoneCtrl = TextEditingController(text: driver.phoneNumber);
    final emailCtrl = TextEditingController(text: driver.email);

    final vehicle = driver.vehicleDetails;
    final plateCtrl = TextEditingController(
      text: vehicle?['licensePlate'] ?? '',
    );

    int truckType = [1, 2, 3, 4, 5, 6].contains(vehicle?['truckType'])
        ? vehicle!['truckType']
        : 1;

    String? selectedMake = vehicle?['make'];
    if (selectedMake != null && !_vehicleDatabase.containsKey(selectedMake))
      selectedMake = null;

    String? selectedModel = vehicle?['model'];
    if (selectedMake != null &&
        selectedModel != null &&
        !(_vehicleDatabase[selectedMake]!.contains(selectedModel)))
      selectedModel = null;

    int selectedYear = vehicle?['year'] ?? DateTime.now().year;
    final List<int> yearsList = List.generate(
      30,
      (index) => DateTime.now().year + 1 - index,
    );
    if (!yearsList.contains(selectedYear)) selectedYear = DateTime.now().year;

    Map<String, String> uploadedDocs = {
      'Government ID': driver.documents['Government ID'] ?? '',
      'Driving License': driver.documents['Driving License'] ?? '',
      'Commercial Insurance': driver.documents['Commercial Insurance'] ?? '',
      'Background Check': driver.documents['Background Check'] ?? '',
    };

    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickAndUploadFile(String docKey) async {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
            );
            if (result != null) {
              setModalState(() {
                uploadedDocs[docKey] =
                    'https://secure-storage.rodl.ca/uploads/${result.files.single.name}';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Document successfully uploaded.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }

          return Dialog(
            backgroundColor: theme.scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              width: 1000,
              height: 850,
              padding: const EdgeInsets.all(40),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Driver',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    const Divider(height: 48),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Driver Information',
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: nameCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Full Name *',
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: theme.cardColor,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        validator: (v) =>
                                            v!.isEmpty ? 'Required' : null,
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: personalPhoneCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Phone Number *',
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: theme.cardColor,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        validator: (v) =>
                                            v!.isEmpty ? 'Required' : null,
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: emailCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Update Email (Optional)',
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: theme.cardColor,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 40),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Fleet Asset Assignment',
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      DropdownButtonFormField<int>(
                                        key: ValueKey(truckType),
                                        initialValue: truckType,
                                        dropdownColor: theme.cardColor,
                                        decoration: InputDecoration(
                                          labelText: 'Asset Category *',
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: theme.cardColor,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 1,
                                            child: Text(
                                              'Standard Wrecker (Wheel Lift)',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 2,
                                            child: Text(
                                              'Flatbed Rollback',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 3,
                                            child: Text(
                                              'Low Clearance / Underground',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 4,
                                            child: Text(
                                              'Heavy Duty Rotator (Commercial)',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 5,
                                            child: Text(
                                              'Light Service (No Towing)',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 6,
                                            child: Text(
                                              'Motorcycle Dedicated Trailer',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) => setModalState(
                                          () => truckType = val!,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<String>(
                                              dropdownColor: theme.cardColor,
                                              decoration: InputDecoration(
                                                labelText: 'Make *',
                                                border:
                                                    const OutlineInputBorder(),
                                                filled: true,
                                                fillColor: theme.cardColor,
                                              ),
                                              value: selectedMake,
                                              items: _vehicleDatabase.keys
                                                  .map(
                                                    (make) => DropdownMenuItem(
                                                      value: make,
                                                      child: Text(
                                                        make,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (val) =>
                                                  setModalState(() {
                                                    selectedMake = val;
                                                    selectedModel = null;
                                                  }),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: DropdownButtonFormField<String>(
                                              dropdownColor: theme.cardColor,
                                              decoration: InputDecoration(
                                                labelText: 'Model *',
                                                border:
                                                    const OutlineInputBorder(),
                                                filled: true,
                                                fillColor: theme.cardColor,
                                              ),
                                              value: selectedModel,
                                              items: selectedMake == null
                                                  ? []
                                                  : _vehicleDatabase[selectedMake]!
                                                        .map(
                                                          (
                                                            model,
                                                          ) => DropdownMenuItem(
                                                            value: model,
                                                            child: Text(
                                                              model,
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                              onChanged: (val) => setModalState(
                                                () => selectedModel = val,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<int>(
                                              key: ValueKey(selectedYear),
                                              initialValue: selectedYear,
                                              dropdownColor: theme.cardColor,
                                              decoration: InputDecoration(
                                                labelText: 'Year *',
                                                border:
                                                    const OutlineInputBorder(),
                                                filled: true,
                                                fillColor: theme.cardColor,
                                              ),
                                              items: yearsList
                                                  .map(
                                                    (year) => DropdownMenuItem(
                                                      value: year,
                                                      child: Text(
                                                        year.toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (val) => setModalState(
                                                () => selectedYear = val!,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: TextFormField(
                                              controller: plateCtrl,
                                              decoration: InputDecoration(
                                                labelText: 'License Plate *',
                                                border:
                                                    const OutlineInputBorder(),
                                                filled: true,
                                                fillColor: theme.cardColor,
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 48),
                            Text(
                              'Upload Compliance Documents',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: uploadedDocs.keys.map((key) {
                                bool isUploaded = uploadedDocs[key]!.isNotEmpty;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: InkWell(
                                      onTap: () => pickAndUploadFile(key),
                                      child: Container(
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: isUploaded
                                              ? Colors.green.withValues(
                                                  alpha: 0.1,
                                                )
                                              : theme.cardColor,
                                          border: Border.all(
                                            color: isUploaded
                                                ? Colors.green
                                                : theme.dividerColor,
                                            width: isUploaded ? 2 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isUploaded
                                                  ? Icons.check_circle
                                                  : Icons.upload_file,
                                              color: isUploaded
                                                  ? Colors.green
                                                  : Colors.grey,
                                              size: 32,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              key,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            if (isUploaded)
                                              const Text(
                                                'Attached',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 10,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.save),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            bloc.add(
                              EditDriverDetails(
                                driverProfileId: driver.driverProfileId,
                                driverData: {
                                  'fullName': nameCtrl.text.trim(),
                                  'phoneNumber': personalPhoneCtrl.text.trim(),
                                  'email': emailCtrl.text.trim(),
                                  'vehicleMake': selectedMake,
                                  'vehicleModel': selectedModel,
                                  'vehicleYear': selectedYear,
                                  'licensePlate': plateCtrl.text.trim(),
                                  'truckType': truckType,
                                  'governmentIdUrl':
                                      uploadedDocs['Government ID'],
                                  'drivingLicenseUrl':
                                      uploadedDocs['Driving License'],
                                  'commercialInsuranceUrl':
                                      uploadedDocs['Commercial Insurance'],
                                  'backgroundCheckUrl':
                                      uploadedDocs['Background Check'],
                                },
                              ),
                            );
                            Navigator.pop(dialogContext);
                          }
                        },
                        label: const Text(
                          'Save Document Overrides & Asset Data',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

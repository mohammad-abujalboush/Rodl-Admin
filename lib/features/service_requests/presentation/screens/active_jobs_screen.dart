import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/active_job_model.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/active_jobs_bloc.dart';

// ============================================================================
// DTO DEFINITIONS
// ============================================================================
class CustomerCrmDto {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String email;

  CustomerCrmDto({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.email,
  });
}

class CustomerVehicleDto {
  final String id;
  final int year;
  final String make;
  final String model;
  final String color;
  final String? licensePlate;
  final bool isDefault;

  CustomerVehicleDto({
    required this.id,
    required this.year,
    required this.make,
    required this.model,
    required this.color,
    this.licensePlate,
    required this.isDefault,
  });
}

// ============================================================================
// MAIN SCREEN
// ============================================================================
class ActiveJobsScreen extends StatefulWidget {
  final String? autoOpenJobId;
  final Map<String, dynamic>? prefillCustomerData;
  const ActiveJobsScreen({
    super.key,
    this.autoOpenJobId,
    this.prefillCustomerData,
  });

  @override
  State<ActiveJobsScreen> createState() => _ActiveJobsScreenState();
}

class _ActiveJobsScreenState extends State<ActiveJobsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _searchQuery = '';
  final Set<int> _selectedStatuses = {};
  final Set<int> _selectedServices = {};
  DateTime? _startDate;
  DateTime? _endDate;

  bool _hasAutoOpened = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => sl<ActiveJobsBloc>()..add(FetchActiveJobs()),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.scaffoldBackgroundColor,
        endDrawer: _buildFilterDrawer(theme),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(
              MediaQuery.of(context).size.width < 600 ? 16.0 : 32.0,
            ),
            child: Builder(
              builder: (innerContext) {
                if (widget.prefillCustomerData != null && !_hasAutoOpened) {
                  _hasAutoOpened = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _openDispatchWizard(
                      innerContext,
                      theme,
                      widget.prefillCustomerData,
                    );
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(theme, innerContext),
                    const SizedBox(height: 24),
                    Expanded(
                      child: BlocConsumer<ActiveJobsBloc, ActiveJobsState>(
                        listener: (context, state) {
                          if (state is JobActionSuccess) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.message),
                                backgroundColor: Colors.green.shade700,
                              ),
                            );
                          } else if (state is ActiveJobsError) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.message),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }

                          if (state is ActiveJobsLoaded &&
                              widget.autoOpenJobId != null &&
                              !_hasAutoOpened &&
                              widget.prefillCustomerData == null) {
                            _hasAutoOpened = true;
                            try {
                              final targetJob = state.jobs.firstWhere(
                                (j) =>
                                    j.requestId.toLowerCase() ==
                                    widget.autoOpenJobId!.toLowerCase(),
                              );
                              Future.microtask(
                                () => _showJobDetailsModal(
                                  context,
                                  targetJob,
                                  state.activeFleet,
                                  theme,
                                ),
                              );
                            } catch (e) {
                              debugPrint("Deep Link failed: $e");
                            }
                          }
                        },
                        buildWhen: (prev, current) =>
                            current is! JobActionSuccess,
                        builder: (context, state) {
                          if (state is ActiveJobsLoading)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          if (state is ActiveJobsError)
                            return Center(
                              child: Text(
                                state.message,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            );

                          if (state is ActiveJobsLoaded) {
                            final filteredJobs = state.jobs.where((j) {
                              final matchesSearch =
                                  j.requestId.toLowerCase().contains(
                                    _searchQuery,
                                  ) ||
                                  j.customerName.toLowerCase().contains(
                                    _searchQuery,
                                  ) ||
                                  j.driverName.toLowerCase().contains(
                                    _searchQuery,
                                  );

                              final matchesStatus =
                                  _selectedStatuses.isEmpty ||
                                  _selectedStatuses.contains(j.status);
                              final matchesService =
                                  _selectedServices.isEmpty ||
                                  _selectedServices.contains(j.serviceType);

                              bool matchesDate = true;
                              if (_startDate != null)
                                matchesDate =
                                    matchesDate &&
                                    j.createdAt.isAfter(_startDate!);
                              if (_endDate != null)
                                matchesDate =
                                    matchesDate &&
                                    j.createdAt.isBefore(
                                      _endDate!.add(const Duration(days: 1)),
                                    );

                              return matchesSearch &&
                                  matchesStatus &&
                                  matchesService &&
                                  matchesDate;
                            }).toList();

                            return ResponsiveBuilder(
                              builder: (responsiveContext, sizingInfo) {
                                if (sizingInfo.isMobile ||
                                    sizingInfo.isTablet) {
                                  return _buildMobileList(
                                    context,
                                    filteredJobs,
                                    state.activeFleet,
                                    theme,
                                  );
                                }
                                return _buildDesktopTable(
                                  context,
                                  filteredJobs,
                                  state.activeFleet,
                                  theme,
                                );
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openDispatchWizard(
    BuildContext context,
    ThemeData theme, [
    Map<String, dynamic>? prefill,
  ]) {
    final bloc = context.read<ActiveJobsBloc>();
    final state = bloc.state;
    List<FleetDriverModel> fleet = [];
    if (state is ActiveJobsLoaded) fleet = state.activeFleet;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: _AdvancedDispatchWizard(
          fleet: fleet,
          crmCustomers: const [],
          bloc: bloc,
          theme: theme,
          prefillData: prefill,
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dispatch & Escalations',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'God-mode control over active incidents, financials, and fleet assignments.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search Job ID, Name...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'New Dispatch',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _openDispatchWizard(context, theme),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.tune),
              tooltip: 'Advanced Filters',
              padding: const EdgeInsets.all(16),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDrawer(ThemeData theme) {
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.blue),
                  const SizedBox(width: 16),
                  Text(
                    'Advanced Filters',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'INCIDENT STATUS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('Pending', 0, _selectedStatuses, theme),
                      _buildFilterChip('Accepted', 1, _selectedStatuses, theme),
                      _buildFilterChip('Arrived', 2, _selectedStatuses, theme),
                      _buildFilterChip(
                        'Completed',
                        3,
                        _selectedStatuses,
                        theme,
                      ),
                      _buildFilterChip(
                        'Cancelled',
                        99,
                        _selectedStatuses,
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'SERVICE TYPES',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        'Wheel Lift',
                        1,
                        _selectedServices,
                        theme,
                      ),
                      _buildFilterChip('Flatbed', 2, _selectedServices, theme),
                      _buildFilterChip(
                        'Jump Start',
                        6,
                        _selectedServices,
                        theme,
                      ),
                      _buildFilterChip('Lockout', 8, _selectedServices, theme),
                      _buildFilterChip('Fuel', 9, _selectedServices, theme),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'DATE RANGE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => _startDate = d);
                          },
                          child: Text(
                            _startDate == null
                                ? 'Start Date'
                                : DateFormat('MMM dd').format(_startDate!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => _endDate = d);
                          },
                          child: Text(
                            _endDate == null
                                ? 'End Date'
                                : DateFormat('MMM dd').format(_endDate!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_selectedStatuses.isNotEmpty ||
                      _selectedServices.isNotEmpty ||
                      _startDate != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedStatuses.clear();
                        _selectedServices.clear();
                        _startDate = null;
                        _endDate = null;
                      }),
                      child: const Text(
                        'Clear All Filters',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    int value,
    Set<int> targetSet,
    ThemeData theme,
  ) {
    final isSelected = targetSet.contains(value);
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      selectedColor: theme.primaryColor,
      backgroundColor: theme.cardColor,
      onSelected: (bool selected) {
        setState(() {
          selected ? targetSet.add(value) : targetSet.remove(value);
        });
      },
    );
  }

  IconData _getServiceIcon(int serviceType) {
    switch (serviceType) {
      case 1:
        return Icons.rv_hookup;
      case 2:
        return Icons.local_shipping;
      case 3:
        return Icons.garage;
      case 4:
        return Icons.fire_truck;
      case 5:
        return Icons.two_wheeler;
      case 6:
        return Icons.bolt;
      case 7:
        return Icons.tire_repair;
      case 8:
        return Icons.lock_open;
      case 9:
        return Icons.local_gas_station;
      case 10:
        return Icons.hardware;
      case 11:
        return Icons.car_repair;
      case 12:
        return Icons.ev_station;
      case 13:
        return Icons.car_crash;
      case 14:
        return Icons.air;
      case 15:
        return Icons.electric_car;
      case 16:
        return Icons.diamond;
      case 17:
        return Icons.shield;
      default:
        return Icons.emergency;
    }
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<ActiveJobModel> jobs,
    List<FleetDriverModel> fleet,
    ThemeData theme,
  ) {
    if (jobs.isEmpty)
      return Center(
        child: Text(
          'No jobs found matching filters.',
          style: TextStyle(color: theme.disabledColor),
        ),
      );

    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: ListView.separated(
        itemCount: jobs.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
        itemBuilder: (ctx, i) {
          final job = jobs[i];
          final String displayId = job.requestId.length > 8
              ? job.requestId.substring(0, 8)
              : job.requestId;

          return ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            iconColor: theme.primaryColor,
            collapsedIconColor: theme.colorScheme.onSurface,
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(
                job.status,
                theme,
              ).withValues(alpha: 0.1),
              child: Icon(
                _getServiceIcon(job.serviceType),
                color: _getStatusColor(job.status, theme),
              ),
            ),
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(
                  job.customerName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '#${displayId.toUpperCase()}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              job.serviceTypeText,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              children: [
                Chip(
                  label: Text(
                    job.statusText,
                    style: TextStyle(
                      color: _getStatusColor(job.status, theme),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: _getStatusColor(
                    job.status,
                    theme,
                  ).withValues(alpha: 0.1),
                  side: BorderSide.none,
                ),
                FilledButton.tonal(
                  onPressed: () =>
                      _showJobDetailsModal(context, job, fleet, theme),
                  child: const Text('God Mode'),
                ),
              ],
            ),
            children: [
              Container(
                width: double.infinity,
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                child: Wrap(
                  spacing: 48,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 250,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicle Target',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.disabledColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (job.vehicleDetails ?? '').isEmpty
                                ? 'Not Provided'
                                : job.vehicleDetails!,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hazards / Notes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.disabledColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (job.locationCondition ?? '').isEmpty
                                ? 'None'
                                : job.locationCondition!,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Fare',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.disabledColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${job.totalFare.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileList(
    BuildContext context,
    List<ActiveJobModel> jobs,
    List<FleetDriverModel> fleet,
    ThemeData theme,
  ) {
    if (jobs.isEmpty)
      return Center(
        child: Text(
          'No jobs found.',
          style: TextStyle(color: theme.disabledColor),
        ),
      );
    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (ctx, i) {
        final job = jobs[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          color: theme.cardColor,
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _showJobDetailsModal(context, job, fleet, theme),
            child: ListTile(
              leading: Icon(
                _getServiceIcon(job.serviceType),
                color: _getStatusColor(job.status, theme),
              ),
              title: Text(
                job.customerName,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                job.statusText,
                style: TextStyle(color: _getStatusColor(job.status, theme)),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showJobDetailsModal(
    BuildContext parentContext,
    ActiveJobModel job,
    List<FleetDriverModel> fleet,
    ThemeData theme,
  ) {
    final bloc = parentContext.read<ActiveJobsBloc>();
    showGeneralDialog(
      context: parentContext,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(
            opacity: animation,
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: theme.scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: _CommandCenterModal(
                job: job,
                fleet: fleet,
                bloc: bloc,
                theme: theme,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(int status, ThemeData theme) {
    if (status == 0) return Colors.orange;
    if (status >= 1 && status <= 8) return Colors.blue;
    if (status == 3) return Colors.green;
    return Colors.red;
  }
}

// ============================================================================
// THE CREATE JOB WIZARD
// ============================================================================
class _AdvancedDispatchWizard extends StatefulWidget {
  final List<FleetDriverModel> fleet;
  final List<CustomerCrmDto> crmCustomers;
  final ActiveJobsBloc bloc;
  final ThemeData theme;
  final Map<String, dynamic>? prefillData;

  const _AdvancedDispatchWizard({
    required this.fleet,
    required this.crmCustomers,
    required this.bloc,
    required this.theme,
    this.prefillData,
  });

  @override
  State<_AdvancedDispatchWizard> createState() =>
      _AdvancedDispatchWizardState();
}

class _AdvancedDispatchWizardState extends State<_AdvancedDispatchWizard> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  String? _selectedCustomerId;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  List<CustomerVehicleDto> _availableVehicles = [];
  CustomerVehicleDto? _selectedVehicle;

  final Map<String, List<String>> _brandDatabase = {
    'Toyota': ['Camry', 'Corolla', 'RAV4', 'Highlander', 'Tacoma'],
    'Honda': ['Civic', 'Accord', 'CR-V', 'Pilot'],
    'Ford': ['F-150', 'Mustang', 'Explorer', 'Escape'],
    'Chevrolet': ['Silverado', 'Malibu', 'Equinox', 'Tahoe', 'Cruze'],
    'BMW': ['3 Series', '5 Series', 'X3', 'X5', 'Z4'],
    'Mercedes-Benz': ['C-Class', 'E-Class', 'GLC', 'GLE'],
    'Nissan': ['Altima', 'Sentra', 'Rogue', 'Pathfinder'],
  };
  String? _selectedMake;
  String? _selectedModel;

  late int _selectedYear;
  late List<int> _yearsList;

  GoogleMapController? _mapController;
  final _mapSearchCtrl = TextEditingController();
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  bool _settingPickup = true;
  bool _isSearchingMap = false;

  int _serviceType = 1;
  bool _isDrivable = false;
  bool _wheelsLocked = false;
  bool _requiresDollies = false;
  final _locationConditionCtrl = TextEditingController();
  final _fuelCostCtrl = TextEditingController();

  String? _selectedDriverId;

  @override
  void initState() {
    super.initState();
    _yearsList = List.generate(30, (index) => DateTime.now().year + 1 - index);
    _selectedYear = DateTime.now().year;

    if (widget.prefillData != null) {
      _selectedCustomerId = widget.prefillData!['customerId'];
      _nameCtrl.text = widget.prefillData!['name'] ?? '';
      _phoneCtrl.text = widget.prefillData!['phone'] ?? '';
      _emailCtrl.text = widget.prefillData!['email'] ?? '';

      if (widget.prefillData!['vehicles'] != null) {
        final List<dynamic> vList = widget.prefillData!['vehicles'];
        _availableVehicles = vList
            .map(
              (v) => CustomerVehicleDto(
                id: v['id'],
                year: v['year'],
                make: v['make'],
                model: v['model'],
                color: v['color'] ?? 'Unknown',
                licensePlate: v['licensePlate'],
                isDefault: false,
              ),
            )
            .toList();

        if (_availableVehicles.isNotEmpty) {
          _selectedVehicle = _availableVehicles.first;
          _selectedYear = _yearsList.contains(_selectedVehicle!.year)
              ? _selectedVehicle!.year
              : DateTime.now().year;
          _selectedMake = _selectedVehicle?.make;
          _selectedModel = _selectedVehicle?.model;
          _plateCtrl.text = _selectedVehicle?.licensePlate ?? '';
        }
      }
    }
  }

  Future<void> _searchMapLocation() async {
    if (_mapSearchCtrl.text.isEmpty) return;
    setState(() => _isSearchingMap = true);
    try {
      List<Location> locations = await locationFromAddress(_mapSearchCtrl.text);
      if (locations.isNotEmpty) {
        final latLng = LatLng(
          locations.first.latitude,
          locations.first.longitude,
        );
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
        setState(() {
          if (_settingPickup) {
            _pickupLocation = latLng;
          } else {
            _dropoffLocation = latLng;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address not found. Try a broader search.'),
        ),
      );
    } finally {
      setState(() => _isSearchingMap = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1000,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width < 600 ? 16 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Create New Job',
                style: widget.theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.theme.colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: widget.theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 3) {
                  setState(() => _currentStep += 1);
                } else {
                  _submitDispatch();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) setState(() => _currentStep -= 1);
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Row(
                    children: [
                      FilledButton(
                        onPressed: details.onStepContinue,
                        child: Text(
                          _currentStep == 3
                              ? 'Confirm & Broadcast'
                              : 'Next Step',
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: Text(
                    'Customer Info',
                    style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  ),
                  isActive: _currentStep >= 0,
                  content: _buildCustomerAndVehicleStep(),
                ),
                Step(
                  title: Text(
                    'Map Location',
                    style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  ),
                  isActive: _currentStep >= 1,
                  content: _buildMapStep(),
                ),
                Step(
                  title: Text(
                    'Service Needs',
                    style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  ),
                  isActive: _currentStep >= 2,
                  content: _buildServiceDetailsStep(),
                ),
                Step(
                  title: Text(
                    'Assign Driver',
                    style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  ),
                  isActive: _currentStep >= 3,
                  content: _buildReviewStep(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerAndVehicleStep() {
    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 650;
          final customerColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Details',
                style: TextStyle(
                  color: widget.theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Autocomplete<CustomerCrmDto>(
                displayStringForOption: (c) =>
                    '${c.fullName} - ${c.phoneNumber}',
                optionsBuilder: (textEditingValue) async {
                  if (textEditingValue.text.length < 2)
                    return const Iterable<CustomerCrmDto>.empty();
                  final results = await widget.bloc.searchCustomers(
                    textEditingValue.text,
                  );
                  return results
                      .map(
                        (json) => CustomerCrmDto(
                          id: json['id'] ?? '',
                          fullName: json['fullName'] ?? 'Unknown',
                          phoneNumber: json['phoneNumber'] ?? '',
                          email: json['email'] ?? '',
                        ),
                      )
                      .toList();
                },
                onSelected: (c) {
                  setState(() {
                    _selectedCustomerId = c.id;
                    _nameCtrl.text = c.fullName;
                    _phoneCtrl.text = c.phoneNumber;
                    _emailCtrl.text = c.email;
                    _availableVehicles = [];
                  });
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        style: TextStyle(
                          color: widget.theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Search Customer (Name or Phone)',
                          filled: true,
                          fillColor: widget.theme.cardColor,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      );
                    },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                style: TextStyle(color: widget.theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  filled: true,
                  fillColor: widget.theme.cardColor,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _selectedCustomerId = null,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                style: TextStyle(color: widget.theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  filled: true,
                  fillColor: widget.theme.cardColor,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (_) => _selectedCustomerId = null,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ],
          );

          final vehicleColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehicle Details',
                style: TextStyle(
                  color: widget.theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_availableVehicles.isNotEmpty) ...[
                DropdownButtonFormField<CustomerVehicleDto>(
                  key: ValueKey(_selectedVehicle),
                  initialValue: _selectedVehicle,
                  dropdownColor: widget.theme.cardColor,
                  style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Select Saved Vehicle',
                    filled: true,
                    fillColor: widget.theme.cardColor,
                    border: const OutlineInputBorder(),
                  ),
                  items: _availableVehicles
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text('${v.year} ${v.make} ${v.model}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedVehicle = v;
                        _selectedYear = _yearsList.contains(v.year)
                            ? v.year
                            : DateTime.now().year;
                        _selectedMake = v.make;
                        _selectedModel = v.model;
                        _plateCtrl.text = v.licensePlate ?? '';
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<int>(
                key: ValueKey(_selectedYear),
                initialValue: _selectedYear,
                dropdownColor: widget.theme.cardColor,
                style: TextStyle(color: widget.theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Year',
                  filled: true,
                  fillColor: widget.theme.cardColor,
                  border: const OutlineInputBorder(),
                ),
                items: _yearsList
                    .map(
                      (y) =>
                          DropdownMenuItem(value: y, child: Text(y.toString())),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedYear = v!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_selectedMake),
                      initialValue: _selectedMake,
                      dropdownColor: widget.theme.cardColor,
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Make *',
                        filled: true,
                        fillColor: widget.theme.cardColor,
                        border: const OutlineInputBorder(),
                      ),
                      items: _brandDatabase.keys
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      validator: (v) => v == null ? 'Required' : null,
                      onChanged: (v) => setState(() {
                        _selectedMake = v!;
                        _selectedModel = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_selectedModel),
                      initialValue: _selectedModel,
                      dropdownColor: widget.theme.cardColor,
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Model *',
                        filled: true,
                        fillColor: widget.theme.cardColor,
                        border: const OutlineInputBorder(),
                      ),
                      items: _selectedMake == null
                          ? []
                          : _brandDatabase[_selectedMake]!
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m),
                                  ),
                                )
                                .toList(),
                      validator: (v) => v == null ? 'Required' : null,
                      onChanged: (v) => setState(() => _selectedModel = v!),
                    ),
                  ),
                ],
              ),
            ],
          );

          if (isSmall) {
            return Column(
              children: [
                customerColumn,
                const SizedBox(height: 32),
                vehicleColumn,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: customerColumn),
              const SizedBox(width: 32),
              Expanded(child: vehicleColumn),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapStep() {
    Set<Marker> markers = {};
    if (_pickupLocation != null)
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    if (_dropoffLocation != null)
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueMagenta,
          ),
        ),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _mapSearchCtrl,
                style: TextStyle(color: widget.theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Search Address',
                  filled: true,
                  fillColor: widget.theme.cardColor,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearchingMap
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.location_searching),
                          onPressed: _searchMapLocation,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _searchMapLocation(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('Set Pickup Location'),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Set Drop-off Location'),
              ),
            ],
            selected: {_settingPickup},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() => _settingPickup = newSelection.first);
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 350,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(31.9539, 35.9106),
              zoom: 12,
            ),
            onMapCreated: (c) => _mapController = c,
            markers: markers,
            onTap: (latLng) => setState(() {
              if (_settingPickup) {
                _pickupLocation = latLng;
              } else {
                _dropoffLocation = latLng;
              }
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey(_serviceType),
          initialValue: _serviceType,
          dropdownColor: widget.theme.cardColor,
          style: TextStyle(color: widget.theme.colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: 'Service Needed',
            filled: true,
            fillColor: widget.theme.cardColor,
            border: const OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 1, child: Text('Wheel Lift Towing')),
            DropdownMenuItem(value: 2, child: Text('Flatbed Carrier')),
            DropdownMenuItem(value: 3, child: Text('Underground/Specialty')),
            DropdownMenuItem(value: 4, child: Text('Heavy Duty Commercial')),
            DropdownMenuItem(value: 5, child: Text('Motorcycle Towing')),
            DropdownMenuItem(value: 6, child: Text('Battery Jump Start')),
            DropdownMenuItem(value: 7, child: Text('Flat Tire Service')),
            DropdownMenuItem(value: 8, child: Text('Lockout Service')),
            DropdownMenuItem(value: 9, child: Text('Fuel/Fluid Delivery')),
            DropdownMenuItem(
              value: 10,
              child: Text('Winching/Off-Road Recovery'),
            ),
            DropdownMenuItem(
              value: 11,
              child: Text('Dollies/Locked Wheels Towing'),
            ),
            DropdownMenuItem(value: 12, child: Text('EV Mobile Charging')),
            DropdownMenuItem(
              value: 13,
              child: Text('Accident Scene Clearance'),
            ),
            DropdownMenuItem(value: 14, child: Text('Tire Inflation/Air Only')),
            DropdownMenuItem(
              value: 15,
              child: Text('Electric Vehicle Flatbed Only'),
            ),
            DropdownMenuItem(
              value: 16,
              child: Text('Exotic Luxury Enclosed Tow'),
            ),
            DropdownMenuItem(
              value: 17,
              child: Text('Secondary Highway Escort (Safety Unit)'),
            ),
          ],
          onChanged: (v) => setState(() => _serviceType = v!),
        ),
        if (_serviceType == 9) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _fuelCostCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: widget.theme.colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Estimated Fuel Receipt Cost (\$)',
              filled: true,
              fillColor: widget.theme.cardColor,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.attach_money),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Situation Overview',
          style: TextStyle(
            color: widget.theme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 250,
              child: SwitchListTile(
                title: Text(
                  'Car Can Drive',
                  style: TextStyle(color: widget.theme.colorScheme.onSurface),
                ),
                value: _isDrivable,
                onChanged: (v) => setState(() => _isDrivable = v),
              ),
            ),
            SizedBox(
              width: 250,
              child: SwitchListTile(
                title: Text(
                  'Wheels Locked',
                  style: TextStyle(color: widget.theme.colorScheme.onSurface),
                ),
                value: _wheelsLocked,
                onChanged: (v) => setState(() => _wheelsLocked = v),
              ),
            ),
            SizedBox(
              width: 250,
              child: SwitchListTile(
                title: Text(
                  'Needs Dollies',
                  style: TextStyle(color: widget.theme.colorScheme.onSurface),
                ),
                value: _requiresDollies,
                onChanged: (v) => setState(() => _requiresDollies = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _locationConditionCtrl,
          maxLines: 3,
          style: TextStyle(color: widget.theme.colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: 'Notes for Driver (Hazards, Parking)',
            filled: true,
            fillColor: widget.theme.cardColor,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedDriverId),
          initialValue: _selectedDriverId,
          dropdownColor: widget.theme.cardColor,
          style: TextStyle(color: widget.theme.colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: 'Assign Specific Driver (Optional)',
            filled: true,
            fillColor: widget.theme.cardColor,
            border: const OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Broadcast to all online drivers'),
            ),
            ...widget.fleet.map(
              (d) => DropdownMenuItem(
                value: d.driverProfileId,
                child: Text('${d.fullName} (${d.vehicle})'),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _selectedDriverId = v),
        ),
      ],
    );
  }

  void _submitDispatch() {
    if (!_formKey.currentState!.validate() || _pickupLocation == null) return;
    widget.bloc.add(
      CreateManualDispatch(
        dispatchData: {
          'customerId': _selectedCustomerId,
          'customerName': _nameCtrl.text,
          'customerPhone': _phoneCtrl.text,
          'customerEmail': _emailCtrl.text,
          'vehicleMake': _selectedMake ?? '',
          'vehicleModel': _selectedModel ?? '',
          'vehicleYear': _selectedYear,
          'licensePlate': _plateCtrl.text,
          'serviceType': _serviceType,
          'requestedFuelCost': double.tryParse(_fuelCostCtrl.text),
          'locationCondition': _locationConditionCtrl.text,
          'pickupLatitude': _pickupLocation!.latitude,
          'pickupLongitude': _pickupLocation!.longitude,
          'dropoffLatitude': _dropoffLocation?.latitude,
          'dropoffLongitude': _dropoffLocation?.longitude,
          'isDrivable': _isDrivable,
          'wheelsLocked': _wheelsLocked,
          'requiresDollies': _requiresDollies,
          'driverId': _selectedDriverId,
        },
      ),
    );
    Navigator.pop(context);
  }
}

// ============================================================================
// GOD MODE MODAL (Command Center)
// ============================================================================
class _CommandCenterModal extends StatefulWidget {
  final ActiveJobModel job;
  final List<FleetDriverModel> fleet;
  final ActiveJobsBloc bloc;
  final ThemeData theme;

  const _CommandCenterModal({
    required this.job,
    required this.fleet,
    required this.bloc,
    required this.theme,
  });

  @override
  State<_CommandCenterModal> createState() => _CommandCenterModalState();
}

class _CommandCenterModalState extends State<_CommandCenterModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Job Overrides
  late int _editStatus;
  late int _editServiceType;
  late TextEditingController _editVehicleTypeCtrl;
  late TextEditingController _editLocationConditionCtrl;
  final TextEditingController _adminNoteCtrl = TextEditingController();

  // Financial Override Controllers
  late TextEditingController _baseCtrl;
  late TextEditingController _distanceCtrl;
  late TextEditingController _waitCtrl;
  late TextEditingController _surchargeCtrl;
  final TextEditingController _overrideReasonCtrl = TextEditingController();

  final TextEditingController _cancelReasonCtrl = TextEditingController();
  final TextEditingController _cancelFeeCtrl = TextEditingController(text: "0");

  // Addon Controllers
  String? _selectedAddonId;
  final TextEditingController _addonDescCtrl = TextEditingController();
  final TextEditingController _addonPriceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // SAFE INITIALIZATION: Defaults to safe valid enums to prevent Dropdown crash
    _editStatus = _getValidStatus(widget.job.status);
    _editServiceType = _getValidServiceType(widget.job.serviceType);

    _editVehicleTypeCtrl = TextEditingController(
      text: widget.job.vehicleDetails ?? '',
    );
    _editLocationConditionCtrl = TextEditingController(
      text: widget.job.locationCondition ?? '',
    );

    _baseCtrl = TextEditingController(text: widget.job.baseFare.toString());
    _distanceCtrl = TextEditingController(
      text: (widget.job.distanceFee).toString(),
    );
    _waitCtrl = TextEditingController(
      text: (widget.job.waitPenalty).toString(),
    );
    _surchargeCtrl = TextEditingController(
      text: (widget.job.surcharges).toString(),
    );
  }

  // --- FAULT TOLERANCE: Ensures we only pass valid Dropdown Values ---
  int _getValidStatus(int s) =>
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 99, 100, 101].contains(s) ? s : 0;
  int _getValidServiceType(int s) =>
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17].contains(s)
      ? s
      : 1;

  // --- ULTIMATE GOD-MODE ADDON CATALOG ---
  // Exhaustive list covering all possible towing, recovery, and roadside scenarios.
  List<Map<String, dynamic>> _getAddonCatalog(int serviceType) {
    return [
      // 1. RECOVERY & WINCHING
      {
        'id': 'rec_1',
        'desc': '[Recovery] Winching - Light Duty (Per 30 mins)',
        'price': 75.00,
      },
      {
        'id': 'rec_2',
        'desc': '[Recovery] Winching - Heavy Duty (Per 30 mins)',
        'price': 150.00,
      },
      {
        'id': 'rec_3',
        'desc': '[Recovery] Snatch Block / Complex Rigging',
        'price': 50.00,
      },
      {
        'id': 'rec_4',
        'desc': '[Recovery] Rollover / Uprighting Service',
        'price': 200.00,
      },
      {
        'id': 'rec_5',
        'desc': '[Recovery] Off-Road / Mud Extraction Premium',
        'price': 100.00,
      },

      // 2. EQUIPMENT & SPECIAL HANDLING
      {
        'id': 'eq_1',
        'desc': '[Equip] Dollies / Skates (AWD/Locked Wheels)',
        'price': 50.00,
      },
      {
        'id': 'eq_2',
        'desc': '[Equip] GoJaks / Tight Space Repositioning',
        'price': 40.00,
      },
      {
        'id': 'eq_3',
        'desc': '[Equip] Driveshaft Drop / Axle Pull',
        'price': 85.00,
      },
      {
        'id': 'eq_4',
        'desc': '[Equip] Dually / Medium-Duty Hookup',
        'price': 45.00,
      },
      {
        'id': 'eq_5',
        'desc': '[Equip] Exotic/Low Clearance Ramps & Handling',
        'price': 60.00,
      },
      {
        'id': 'eq_6',
        'desc': '[Equip] Tarping / Weather Protection (Wrecks)',
        'price': 35.00,
      },

      // 3. LABOR, TIME & LOGISTICS
      {
        'id': 'lab_1',
        'desc': '[Labor] Wait Time / Standby (Per 15 mins)',
        'price': 25.00,
      },
      {
        'id': 'lab_2',
        'desc': '[Labor] Extra Labor / 2nd Operator (Per Hour)',
        'price': 90.00,
      },
      {
        'id': 'lab_3',
        'desc': '[Logistics] Out of Zone / Deadhead Mileage',
        'price': 50.00,
      },
      {
        'id': 'lab_4',
        'desc': '[Logistics] After-Hours / Holiday Premium',
        'price': 40.00,
      },
      {
        'id': 'lab_5',
        'desc': '[Logistics] Secondary Drop-off / Multi-Stop',
        'price': 30.00,
      },
      {
        'id': 'lab_6',
        'desc': '[Logistics] Passenger Transport Surcharge',
        'price': 20.00,
      },
      {
        'id': 'lab_7',
        'desc': '[Logistics] Toll Charges / Bridge Fees',
        'price': 15.00,
      },
      {
        'id': 'lab_8',
        'desc': '[Logistics] Ferry / Transit Charges',
        'price': 50.00,
      },

      // 4. ACCIDENT & SITE MANAGEMENT
      {
        'id': 'acc_1',
        'desc': '[Accident] Site Clean-up (Debris/Oil Dry)',
        'price': 45.00,
      },
      {
        'id': 'acc_2',
        'desc': '[Accident] Police / Impound Processing Fee',
        'price': 50.00,
      },
      {
        'id': 'acc_3',
        'desc': '[Storage] Overnight Truck Storage (Loaded)',
        'price': 100.00,
      },
      {
        'id': 'acc_4',
        'desc': '[Storage] Yard Release / Gate Fee',
        'price': 35.00,
      },

      // 5. ADVANCED ROADSIDE ASSISTANCE
      {
        'id': 'rd_1',
        'desc': '[Roadside] Fuel Cost (Jerry Can / Diesel)',
        'price': 25.00,
      },
      {
        'id': 'rd_2',
        'desc': '[Roadside] Complex Lockout (Luxury/Dead Battery)',
        'price': 35.00,
      },
      {
        'id': 'rd_3',
        'desc': '[Roadside] Difficult Access / Underground Parking',
        'price': 20.00,
      },
      {
        'id': 'rd_4',
        'desc': '[Roadside] Tire Plug / On-site Patch',
        'price': 20.00,
      },
      {
        'id': 'rd_5',
        'desc': '[Roadside] Heavy Duty Jump Start (24v)',
        'price': 45.00,
      },
      {
        'id': 'rd_6',
        'desc': '[Roadside] EV Mobile Charging (Per 10 kWh)',
        'price': 50.00,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveJobsBloc, ActiveJobsState>(
      bloc: widget.bloc,
      builder: (context, state) {
        ActiveJobModel currentJob = widget.job;
        if (state is ActiveJobsLoaded) {
          try {
            currentJob = state.jobs.firstWhere(
              (j) => j.requestId == widget.job.requestId,
            );
          } catch (e) {
            // fallback
          }
        }

        final String displayId = currentJob.requestId.length > 8
            ? currentJob.requestId.substring(0, 8)
            : currentJob.requestId;

        return Container(
          width: 1200,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 16 : 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FIX: Guaranteed Top-Right Alignment for "X" button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Service Request Console: #${displayId.toUpperCase()}',
                          style: widget.theme.textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: widget.theme.colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            currentJob.statusText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: widget.theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TabBar(
                controller: _tabController,
                labelColor: widget.theme.primaryColor,
                unselectedLabelColor: widget.theme.disabledColor,
                indicatorColor: widget.theme.primaryColor,
                isScrollable: true,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.alt_route),
                    text: 'Logistics & Re-Assignment',
                  ),
                  Tab(
                    icon: Icon(Icons.receipt_long),
                    text: 'Financial Overrides & Billing',
                  ),
                  Tab(
                    icon: Icon(Icons.photo_library),
                    text: 'Evidence & Addons',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLogisticsTab(currentJob),
                    _buildFinancialsTab(currentJob),
                    _buildEvidenceTab(currentJob),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogisticsTab(ActiveJobModel currentJob) {
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 800;

          final crmEntitiesColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CRM Entities',
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: widget.theme.cardColor,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    currentJob.customerName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    currentJob.customerPhone,
                    style: TextStyle(
                      color: widget.theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.blue),
                    tooltip: 'View CRM Profile',
                    onPressed: () {
                      if (currentJob.customerId != null &&
                          currentJob.customerId!.isNotEmpty) {
                        Navigator.pop(context);
                        context.go(
                          '/customer-crm',
                          extra: {'autoOpenCustomerId': currentJob.customerId},
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: widget.theme.cardColor,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.local_shipping, color: Colors.white),
                  ),
                  title: Text(
                    currentJob.driverName.isEmpty
                        ? "No Driver Assigned"
                        : currentJob.driverName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    currentJob.statusText,
                    style: TextStyle(
                      color: widget.theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  trailing:
                      currentJob.driverId != null &&
                          currentJob.driverId!.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.open_in_new,
                            color: Colors.green,
                          ),
                          tooltip: 'View Fleet Dossier',
                          onPressed: () {
                            Navigator.pop(context);
                            context.go(
                              '/driver-management',
                              extra: {'autoOpenDriverId': currentJob.driverId},
                            );
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Situation Overview',
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      'Drivable: ${currentJob.isDrivable == true ? "Yes" : "No"}',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                    backgroundColor: currentJob.isDrivable == true
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    side: BorderSide.none,
                  ),
                  Chip(
                    label: Text(
                      'Wheels Locked: ${currentJob.wheelsLocked == true ? "Yes" : "No"}',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                    backgroundColor: currentJob.wheelsLocked == true
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    side: BorderSide.none,
                  ),
                  Chip(
                    label: Text(
                      'Needs Dollies: ${currentJob.requiresDollies == true ? "Yes" : "No"}',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                    backgroundColor: currentJob.requiresDollies == true
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    side: BorderSide.none,
                  ),
                ],
              ),
            ],
          );

          final overrideColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Full Service Override',
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _editStatus,
                dropdownColor: widget.theme.cardColor,
                decoration: InputDecoration(
                  labelText: 'Force Job Status',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: widget.theme.cardColor,
                ),
                items: [
                  DropdownMenuItem(
                    value: 0,
                    child: Text(
                      'Pending Dispatch',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text(
                      'Driver Accepted',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text(
                      'Driver Arrived',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text(
                      'Completed',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 4,
                    child: Text(
                      'Waiting on Customer',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 5,
                    child: Text(
                      'Loading Vehicle',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 6,
                    child: Text(
                      'In Transit to Dropoff',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 7,
                    child: Text(
                      'Unloading Vehicle',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 8,
                    child: Text(
                      'Payment Pending',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 99,
                    child: Text(
                      'Cancelled',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 100,
                    child: Text(
                      'Failed PreAuth',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 101,
                    child: Text(
                      'Suspended By Admin',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _editStatus = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _editServiceType,
                dropdownColor: widget.theme.cardColor,
                decoration: InputDecoration(
                  labelText: 'Override Service Type',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: widget.theme.cardColor,
                ),
                items: [
                  DropdownMenuItem(
                    value: 1,
                    child: Text(
                      'Wheel Lift Towing',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text(
                      'Flatbed Carrier',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text(
                      'Underground/Specialty',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 4,
                    child: Text(
                      'Heavy Duty Commercial',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 5,
                    child: Text(
                      'Motorcycle Towing',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 6,
                    child: Text(
                      'Battery Jump Start',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 7,
                    child: Text(
                      'Flat Tire Service',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 8,
                    child: Text(
                      'Lockout Service',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 9,
                    child: Text(
                      'Fuel/Fluid Delivery',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 10,
                    child: Text(
                      'Winching/Off-Road Recovery',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 11,
                    child: Text(
                      'Dollies/Locked Wheels Towing',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 12,
                    child: Text(
                      'EV Mobile Charging',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 13,
                    child: Text(
                      'Accident Scene Clearance',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 14,
                    child: Text(
                      'Tire Inflation/Air Only',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 15,
                    child: Text(
                      'Electric Vehicle Flatbed Only',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 16,
                    child: Text(
                      'Exotic Luxury Enclosed Tow',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 17,
                    child: Text(
                      'Secondary Highway Escort (Safety Unit)',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _editServiceType = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _editVehicleTypeCtrl,
                style: TextStyle(color: widget.theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Override Target Vehicle Details',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: widget.theme.cardColor,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _editLocationConditionCtrl,
                style: TextStyle(color: widget.theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Override Hazards / Dispatch Notes',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: widget.theme.cardColor,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminNoteCtrl,
                style: TextStyle(color: widget.theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Admin Note (Required for Audit Trail)',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: widget.theme.cardColor,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_adminNoteCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Admin note required to override job details.',
                          ),
                        ),
                      );
                      return;
                    }
                    widget.bloc.add(
                      UpdateJobDetails(
                        requestId: currentJob.requestId,
                        updateData: {
                          'status': _editStatus,
                          'serviceType': _editServiceType,
                          'customerVehicleType': _editVehicleTypeCtrl.text,
                          'locationCondition': _editLocationConditionCtrl.text,
                          'adminNote': _adminNoteCtrl.text,
                        },
                      ),
                    );
                    _adminNoteCtrl.clear();
                  },
                  child: const Text('Execute Dispatch Override'),
                ),
              ),
              const Divider(height: 48),
              Text(
                'Force Re-Assignment',
                style: TextStyle(
                  color: widget.theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: widget.theme.cardColor,
                decoration: InputDecoration(
                  labelText: 'Select New Driver',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: widget.theme.cardColor,
                ),
                items: widget.fleet
                    .map(
                      (d) => DropdownMenuItem(
                        value: d.driverProfileId,
                        child: Text(
                          '${d.fullName} (${d.vehicle})',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    widget.bloc.add(
                      AssignDriver(
                        requestId: currentJob.requestId,
                        driverId: v,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Job Manually'),
                  onPressed: () {
                    _cancelReasonCtrl.text = "Admin forced cancellation";
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: widget.theme.scaffoldBackgroundColor,
                        title: Text(
                          'Cancel Job?',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurface,
                          ),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _cancelReasonCtrl,
                              style: TextStyle(
                                color: widget.theme.colorScheme.onSurface,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Reason for Cancellation',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _cancelFeeCtrl,
                              style: TextStyle(
                                color: widget.theme.colorScheme.onSurface,
                              ),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cancellation Fee to Charge (\$)',
                                hintText: '0 for free cancellation',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Abort'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () {
                              widget.bloc.add(
                                CancelJob(
                                  requestId: currentJob.requestId,
                                  reason: _cancelReasonCtrl.text,
                                  cancellationFee:
                                      double.tryParse(_cancelFeeCtrl.text) ?? 0,
                                ),
                              );
                              Navigator.pop(ctx);
                            },
                            child: const Text('Destroy Job'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );

          if (isSmall) {
            return Column(
              children: [
                crmEntitiesColumn,
                const SizedBox(height: 48),
                overrideColumn,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: crmEntitiesColumn),
              const SizedBox(width: 48),
              Expanded(child: overrideColumn),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFinancialsTab(ActiveJobModel currentJob) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ledger Adjustments',
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Current Total: \$${currentJob.totalFare.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 250,
                child: TextFormField(
                  controller: _baseCtrl,
                  style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Base Fare',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 250,
                child: TextFormField(
                  controller: _distanceCtrl,
                  style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Distance Fare',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 250,
                child: TextFormField(
                  controller: _waitCtrl,
                  style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Wait Time Penalties',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 250,
                child: TextFormField(
                  controller: _surchargeCtrl,
                  style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Surcharges',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _overrideReasonCtrl,
            style: TextStyle(color: widget.theme.colorScheme.onSurface),
            decoration: const InputDecoration(
              labelText: 'Audit Reason (Required for Override)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text(
                'Execute Financial Override',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                if (_overrideReasonCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Audit reason required.')),
                  );
                  return;
                }
                widget.bloc.add(
                  OverrideJobPricing(
                    requestId: currentJob.requestId,
                    pricingData: {
                      'newBaseFare':
                          double.tryParse(_baseCtrl.text) ??
                          currentJob.baseFare,
                      'newDistanceFare':
                          double.tryParse(_distanceCtrl.text) ?? 0.0,
                      'newWaitingTimeCharges':
                          double.tryParse(_waitCtrl.text) ?? 0.0,
                      'newSurchargeTotal':
                          double.tryParse(_surchargeCtrl.text) ?? 0.0,
                      'overrideReason': _overrideReasonCtrl.text,
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceTab(ActiveJobModel currentJob) {
    final catalog = _getAddonCatalog(currentJob.serviceType);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 800;

        // --- 1. PRE-APPROVED ADDON CATALOG ---
        final addonsColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dispatch Addons',
              style: TextStyle(
                color: widget.theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (currentJob.addons.isEmpty)
              Text(
                'No addons applied to this service request.',
                style: TextStyle(color: widget.theme.disabledColor),
              ),
            ...currentJob.addons.map(
              (a) => ListTile(
                title: Text(
                  a.description,
                  style: TextStyle(color: widget.theme.colorScheme.onSurface),
                ),
                subtitle: Text(
                  '\$${a.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: widget.theme.colorScheme.onSurface.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => widget.bloc.add(
                    RemoveJobAddon(
                      requestId: currentJob.requestId,
                      addonId: a.id,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Attach Pre-Approved Addon',
              style: TextStyle(
                color: widget.theme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedAddonId,
              dropdownColor: widget.theme.cardColor,
              style: TextStyle(color: widget.theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Select Addon Type',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: widget.theme.cardColor,
              ),
              items: catalog
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item['id'] as String,
                      child: Text(item['desc'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedAddonId = val;
                    final selectedItem = catalog.firstWhere(
                      (e) => e['id'] == val,
                    );
                    _addonPriceCtrl.text = (selectedItem['price'] as double)
                        .toStringAsFixed(2);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _addonPriceCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: widget.theme.colorScheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: '\$ Price',
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Apply Charge'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onPressed: () {
                    if (_selectedAddonId == null) return;
                    final selectedItem = catalog.firstWhere(
                      (e) => e['id'] == _selectedAddonId,
                    );
                    widget.bloc.add(
                      AddJobAddon(
                        requestId: currentJob.requestId,
                        description: selectedItem['desc'] as String,
                        price: double.tryParse(_addonPriceCtrl.text) ?? 0,
                      ),
                    );
                    setState(() {
                      _selectedAddonId = null;
                      _addonPriceCtrl.clear();
                    });
                  },
                ),
              ],
            ),
          ],
        );

        // --- 2. ADMIN EVIDENCE UPLOAD SECTION ---
        final evidenceColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Photographic Evidence',
                  style: TextStyle(
                    color: widget.theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Attach Media'),
                  onPressed: () => _showAddPhotoDialog(currentJob),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (currentJob.photos.isEmpty)
              Text(
                'No evidence uploaded yet.',
                style: TextStyle(color: widget.theme.disabledColor),
              ),
            if (currentJob.photos.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: currentJob.photos.length,
                itemBuilder: (ctx, i) {
                  final p = currentJob.photos[i];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: widget.theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.network(
                              p.url,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            p.photoType,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: widget.theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );

        return SingleChildScrollView(
          child: isSmall
              ? Column(
                  children: [
                    addonsColumn,
                    const SizedBox(height: 48),
                    evidenceColumn,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: addonsColumn),
                    const SizedBox(width: 48),
                    Expanded(child: evidenceColumn),
                  ],
                ),
        );
      },
    );
  }

  // --- NEW: MODAL TO ATTACH PHOTOS AS AN ADMIN ---
  void _showAddPhotoDialog(ActiveJobModel job) {
    final urlCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'Admin Upload');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.theme.scaffoldBackgroundColor,
        title: Text(
          'Attach Evidence',
          style: TextStyle(
            color: widget.theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: widget.theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Image URL / Storage Link',
                filled: true,
                fillColor: widget.theme.cardColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: typeCtrl,
              style: TextStyle(color: widget.theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Photo Type (e.g., Damage, Receipt)',
                filled: true,
                fillColor: widget.theme.cardColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              style: TextStyle(color: widget.theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Audit Notes (Optional)',
                filled: true,
                fillColor: widget.theme.cardColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (urlCtrl.text.isNotEmpty) {
                widget.bloc.add(
                  AddJobPhoto(
                    requestId: job.requestId,
                    photoUrl: urlCtrl.text,
                    photoType: typeCtrl.text,
                    notes: notesCtrl.text,
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Upload Media'),
          ),
        ],
      ),
    );
  }
}

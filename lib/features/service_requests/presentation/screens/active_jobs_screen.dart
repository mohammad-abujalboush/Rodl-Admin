// lib/features/dispatch/presentation/screens/active_jobs_screen.dart
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/active_job_model.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/active_jobs_bloc.dart';

// ============================================================================
// DTO DEFINITIONS (Required for Autocomplete and Dropdowns)
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
  String _searchQuery = '';
  int? _statusFilter;
  bool _hasAutoOpened = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => sl<ActiveJobsBloc>()..add(FetchActiveJobs()),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.3,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
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
                    _buildStatusFilters(theme),
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
                                  );
                              final matchesStatus =
                                  _statusFilter == null ||
                                  j.status == _statusFilter;
                              return matchesSearch && matchesStatus;
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Active Job Ledger',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Row(
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search Job ID or Name...',
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
            const SizedBox(width: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_alert),
              label: const Text('Advanced Dispatch Wizard'),
              onPressed: () => _openDispatchWizard(context, theme),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusFilters(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('All Jobs'),
            selected: _statusFilter == null,
            onSelected: (s) => setState(() => _statusFilter = s ? null : null),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Pending Dispatch'),
            selected: _statusFilter == 0,
            onSelected: (s) => setState(() => _statusFilter = s ? 0 : null),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Driver Accepted'),
            selected: _statusFilter == 1,
            onSelected: (s) => setState(() => _statusFilter = s ? 1 : null),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Driver Arrived'),
            selected: _statusFilter == 2,
            onSelected: (s) => setState(() => _statusFilter = s ? 2 : null),
          ),
        ],
      ),
    );
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
          'No active jobs found.',
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
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
              child: Icon(Icons.local_shipping, color: theme.primaryColor),
            ),
            title: Text(
              job.customerName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              '#${job.requestId.substring(0, 8).toUpperCase()} • ${job.serviceTypeText}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(width: 16),
                FilledButton.tonal(
                  onPressed: () =>
                      _showJobDetailsModal(context, job, fleet, theme),
                  child: const Text('Manage'),
                ),
              ],
            ),
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
    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (ctx, i) => Card(
        color: theme.cardColor,
        child: ListTile(
          title: Text(jobs[i].customerName),
          subtitle: Text(jobs[i].statusText),
          trailing: IconButton(
            icon: const Icon(Icons.manage_accounts),
            onPressed: () =>
                _showJobDetailsModal(context, jobs[i], fleet, theme),
          ),
        ),
      ),
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
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.purple;
      case 3:
        return Colors.green;
      default:
        return Colors.red;
    }
  }
}

// ============================================================================
// THE ADVANCED MANUAL DISPATCH WIZARD
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
  int _selectedYear = DateTime.now().year;

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

  String? _selectedDriverId;

  @override
  void initState() {
    super.initState();
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
          _selectedYear = _selectedVehicle?.year ?? DateTime.now().year;
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

  Future<void> _getCurrentUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    Position position = await Geolocator.getCurrentPosition();
    final latLng = LatLng(position.latitude, position.longitude);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
    setState(() {
      if (_settingPickup) {
        _pickupLocation = latLng;
      } else {
        _dropoffLocation = latLng;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1000,
      height: 850,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Advanced Dispatch & Assignment',
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
              type: StepperType.horizontal,
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
                  title: const Text('Customer & Vehicle'),
                  isActive: _currentStep >= 0,
                  content: _buildCustomerAndVehicleStep(),
                ),
                Step(
                  title: const Text('Interactive Map'),
                  isActive: _currentStep >= 1,
                  content: _buildMapStep(),
                ),
                Step(
                  title: const Text('Incident Details'),
                  isActive: _currentStep >= 2,
                  content: _buildServiceDetailsStep(),
                ),
                Step(
                  title: const Text('Assignment & Review'),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Identity',
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
                          decoration: InputDecoration(
                            labelText: 'Search CRM Customer (Name, Phone)',
                            filled: true,
                            fillColor: widget.theme.cardColor,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.search),
                          ),
                        );
                      },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: widget.theme.dividerColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'OR CREATE NEW',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.theme.disabledColor,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: widget.theme.dividerColor)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email Address (Optional)',
                    filled: true,
                    fillColor: widget.theme.cardColor,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Digital Garage (Vehicle)',
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
                    decoration: InputDecoration(
                      labelText: 'Select Client Saved Vehicle',
                      filled: true,
                      fillColor: widget.theme.cardColor,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.directions_car),
                    ),
                    items: _availableVehicles
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(
                              '${v.year} ${v.make} ${v.model} (${v.licensePlate ?? "No Plate"})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedVehicle = v;
                          _selectedYear = v.year;
                          _selectedMake = v.make;
                          _selectedModel = v.model;
                          _plateCtrl.text = v.licensePlate ?? '';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: widget.theme.dividerColor),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'OR OVERRIDE MANUALLY',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.theme.disabledColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: widget.theme.dividerColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<int>(
                  key: ValueKey(_selectedYear),
                  initialValue: _selectedYear,
                  dropdownColor: widget.theme.cardColor,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    filled: true,
                    fillColor: widget.theme.cardColor,
                    border: const OutlineInputBorder(),
                  ),
                  items:
                      List.generate(30, (index) => DateTime.now().year - index)
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text(y.toString()),
                            ),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _plateCtrl,
                  decoration: InputDecoration(
                    labelText: 'License Plate (Optional)',
                    filled: true,
                    fillColor: widget.theme.cardColor,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          infoWindow: const InfoWindow(title: 'Pickup Location'),
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
          infoWindow: const InfoWindow(title: 'Drop-off Destination'),
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
                decoration: InputDecoration(
                  labelText: 'Search Location / Address',
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
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _getCurrentUserLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('My Location'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
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
                label: Text('Set Extraction Point (Pickup)'),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Set Destination Point (Drop-off)'),
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
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            onTap: (latLng) => setState(() {
              if (_settingPickup) {
                _pickupLocation = latLng;
              } else {
                _dropoffLocation = latLng;
              }
            }),
          ),
        ),
        if (_pickupLocation == null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Warning: Pickup location is strictly required. Tap the map to place a pin.',
              style: TextStyle(
                color: widget.theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
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
          decoration: InputDecoration(
            labelText: 'Required Service Asset',
            filled: true,
            fillColor: widget.theme.cardColor,
            border: const OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 1, child: Text('Wheel Lift')),
            DropdownMenuItem(value: 2, child: Text('Flatbed Carrier')),
            DropdownMenuItem(value: 3, child: Text('Underground/Specialty')),
          ],
          onChanged: (v) => setState(() => _serviceType = v!),
        ),
        const SizedBox(height: 24),
        Text(
          'Asset Condition Toggles',
          style: TextStyle(
            color: widget.theme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                title: const Text('Vehicle is Drivable'),
                value: _isDrivable,
                activeColor: widget.theme.primaryColor,
                activeTrackColor: widget.theme.primaryColor.withValues(
                  alpha: 0.5,
                ),
                onChanged: (v) => setState(() => _isDrivable = v),
              ),
            ),
            Expanded(
              child: SwitchListTile(
                title: const Text('Wheels Locked/Missing Keys'),
                value: _wheelsLocked,
                activeColor: Colors.red,
                activeTrackColor: Colors.red.withValues(alpha: 0.5),
                onChanged: (v) => setState(() => _wheelsLocked = v),
              ),
            ),
            Expanded(
              child: SwitchListTile(
                title: const Text('Requires Dollies'),
                value: _requiresDollies,
                activeColor: Colors.orange,
                activeTrackColor: Colors.orange.withValues(alpha: 0.5),
                onChanged: (v) => setState(() => _requiresDollies = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _locationConditionCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Location Hazards / Parking Codes',
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
          decoration: InputDecoration(
            labelText:
                'Direct Driver Assignment (Leave empty to queue to fleet)',
            filled: true,
            fillColor: widget.theme.cardColor,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_search),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Broadcast to all available drivers (Queue)'),
            ),
            ...widget.fleet.map(
              (d) => DropdownMenuItem(
                value: d.id,
                child: Text('${d.fullName} (${d.vehicle})'),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _selectedDriverId = v),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.theme.primaryColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dispatch Summary',
                style: widget.theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.theme.primaryColor,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(
                  _nameCtrl.text.isEmpty ? 'Pending Customer' : _nameCtrl.text,
                ),
                subtitle: Text(_phoneCtrl.text),
              ),
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: Text('$_selectedYear $_selectedMake $_selectedModel'),
                subtitle: Text(
                  'Service Type: ${_serviceType == 1 ? "Wheel Lift" : "Flatbed"}',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Coordinates Recorded'),
                subtitle: Text(
                  'Pickup: ${_pickupLocation != null ? "Yes" : "NO"} | Dropoff: ${_dropoffLocation != null ? "Yes" : "No"}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _submitDispatch() {
    if (!_formKey.currentState!.validate()) {
      setState(() => _currentStep = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill out all required customer and vehicle fields.',
          ),
        ),
      );
      return;
    }
    if (_pickupLocation == null) {
      setState(() => _currentStep = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A precise pickup location must be set on the map.'),
        ),
      );
      return;
    }

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
// COMMAND CENTER MODAL
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

  late TextEditingController _vehCtrl;
  late TextEditingController _locCtrl;
  late int _editServiceType;
  late int _editStatus;
  late TextEditingController _baseCtrl;
  late TextEditingController _distCtrl;
  late TextEditingController _waitCtrl;
  late TextEditingController _surCtrl;

  final TextEditingController _addonDescMainCtrl = TextEditingController();
  late TextEditingController _addonPriceCtrl;
  late TextEditingController _photoNotesCtrl;
  String _photoType = 'DamageReport';

  final List<String> _predefinedAddons = [
    'Winching (Standard)',
    'Winching (Heavy Duty)',
    'Dollies Usage',
    'Tire Change',
    'Jump Start',
    'Lockout Service',
    'Fuel Delivery',
  ];

  PlatformFile? _selectedPhotoFile;
  bool _isUploadingFile = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _vehCtrl = TextEditingController(text: widget.job.vehicleDetails);
    _locCtrl = TextEditingController(text: widget.job.locationCondition);

    _editServiceType = [1, 2, 3].contains(widget.job.serviceType)
        ? widget.job.serviceType
        : 1;

    _editStatus = widget.job.status;
    _baseCtrl = TextEditingController(text: widget.job.baseFare.toString());
    _distCtrl = TextEditingController(text: widget.job.distanceFee.toString());
    _waitCtrl = TextEditingController(text: widget.job.waitPenalty.toString());
    _surCtrl = TextEditingController(text: widget.job.surcharges.toString());
    _addonPriceCtrl = TextEditingController();
    _photoNotesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vehCtrl.dispose();
    _locCtrl.dispose();
    _baseCtrl.dispose();
    _distCtrl.dispose();
    _waitCtrl.dispose();
    _surCtrl.dispose();
    _addonDescMainCtrl.dispose();
    _addonPriceCtrl.dispose();
    _photoNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickEvidenceFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null) {
      setState(() {
        _selectedPhotoFile = result.files.first;
      });
    }
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
            // Job voided
          }
        }

        return Container(
          width: 1100,
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
                        'Command Center: #${currentJob.requestId.substring(0, 8).toUpperCase()}',
                        style: widget.theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: widget.theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          currentJob.statusText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(currentJob.status),
                          ),
                        ),
                        backgroundColor: _getStatusColor(
                          currentJob.status,
                        ).withValues(alpha: 0.1),
                        side: BorderSide.none,
                      ),
                    ],
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
                tabs: const [
                  Tab(icon: Icon(Icons.map), text: 'Logistics & Dispatch'),
                  Tab(
                    icon: Icon(Icons.receipt_long),
                    text: 'Financial Overrides',
                  ),
                  Tab(icon: Icon(Icons.photo_library), text: 'Media & Addons'),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLogisticsTab(currentJob),
                    _buildFinancialsTab(currentJob),
                    _buildMediaAndAddonsTab(currentJob),
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
    final activeDriver = widget.fleet
        .where((d) => d.fullName == currentJob.driverName)
        .firstOrNull;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parties Involved',
                  style: TextStyle(
                    color: widget.theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildProfileAccordion(
                  role: 'Customer',
                  name: currentJob.customerName,
                  phone: currentJob.customerPhone,
                  extraDetails: {
                    'Job Created': DateFormat(
                      'MMM dd, yyyy - HH:mm',
                    ).format(currentJob.createdAt),
                    'Vehicle Focus':
                        currentJob.vehicleDetails ?? 'No vehicle specified',
                  },
                  theme: widget.theme,
                  crmAction: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Navigating to CRM profile for ${currentJob.customerName}...',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildProfileAccordion(
                  role: 'Assigned Fleet Driver',
                  // Ensure empty UI strings fallback to "Unassigned" appropriately
                  name: currentJob.driverName.isEmpty
                      ? "Unassigned"
                      : currentJob.driverName,
                  phone: 'System Managed Routing',
                  extraDetails: {
                    'Est. Distance':
                        '${currentJob.estimatedDistanceKm.toStringAsFixed(1)} KM',
                    'Active Vehicle':
                        activeDriver?.vehicle ?? 'Unknown Assigned Unit',
                    'Current Job Status': currentJob.statusText,
                  },
                  theme: widget.theme,
                  crmAction: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Opening Driver management portal for ${currentJob.driverName.isEmpty ? "Unknown" : currentJob.driverName}...',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Service Request Parameters',
                  style: TextStyle(
                    color: widget.theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(_editServiceType),
                        initialValue: _editServiceType,
                        dropdownColor: widget.theme.cardColor,
                        decoration: InputDecoration(
                          labelText: 'Requested Asset Type',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: widget.theme.cardColor,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 1,
                            child: Text(
                              'Wheel Lift Towing',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text(
                              'Flatbed Carrier',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text(
                              'Underground/Specialty',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 4,
                            child: Text(
                              'Heavy Duty Commercial',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 5,
                            child: Text(
                              'Motorcycle Towing',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 6,
                            child: Text(
                              'Battery Jump Start',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 7,
                            child: Text(
                              'Flat Tire Service',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 8,
                            child: Text(
                              'Lockout Service',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 9,
                            child: Text(
                              'Fuel / Fluid Delivery',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 10,
                            child: Text(
                              'Winching / Recovery',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _editServiceType = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(_editStatus),
                        initialValue: _editStatus,
                        dropdownColor: widget.theme.cardColor,
                        decoration: InputDecoration(
                          labelText: 'Incident Status',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: widget.theme.cardColor,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 0,
                            child: Text(
                              'Pending Dispatch',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 1,
                            child: Text(
                              'Driver Accepted',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text(
                              'Driver Arrived',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 4,
                            child: Text(
                              'Waiting on Customer',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 5,
                            child: Text(
                              'Loading Vehicle',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 6,
                            child: Text(
                              'In Transit to Dropoff',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text(
                              'Completed',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 99,
                            child: Text(
                              'Cancelled',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _editStatus = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vehCtrl,
                  decoration: InputDecoration(
                    labelText: 'Customer Vehicle Specifications',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: widget.theme.cardColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Location Hazards & Dispatch Notes',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: widget.theme.cardColor,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.save),
                    onPressed: () {
                      widget.bloc.add(
                        UpdateJobDetails(
                          requestId: currentJob.requestId,
                          updateData: {
                            'serviceType': _editServiceType,
                            'status': _editStatus,
                            'customerVehicleType': _vehCtrl.text,
                            'locationCondition': _locCtrl.text,
                            'adminNote': 'Admin manual profile update',
                          },
                        ),
                      );
                    },
                    label: const Text('Save Dispatch Parameters'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Action Center',
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (currentJob.status == 0) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    icon: const Icon(Icons.person_search),
                    label: const Text(
                      'Open Fleet Commander',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showFleetCommander(currentJob),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Force Void Incident'),
                  onPressed: () {
                    widget.bloc.add(
                      CancelJob(
                        requestId: currentJob.requestId,
                        reason: 'Admin Manual Void',
                        cancellationFee: 0,
                      ),
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialsTab(ActiveJobModel currentJob) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Ledger',
                  style: TextStyle(
                    color: widget.theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: widget.theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'Base Fare',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Text(
                          '\$${currentJob.baseFare.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Distance Fee',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Text(
                          '\$${currentJob.distanceFee.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Wait Penalties',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Text(
                          '\$${currentJob.waitPenalty.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Addons & Surcharges',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          '\$${currentJob.surcharges.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (currentJob.addons.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 4.0,
                          ),
                          child: Column(
                            children: currentJob.addons
                                .map(
                                  (a) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.subdirectory_arrow_right,
                                              size: 16,
                                              color: widget.theme.disabledColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              a.description,
                                              style: TextStyle(
                                                color:
                                                    widget.theme.disabledColor,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '\$${a.price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: widget.theme.disabledColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      const Divider(),
                      ListTile(
                        title: Text(
                          'Grand Total',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          '\$${currentJob.totalFare.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: widget.theme.primaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manual Override Engine',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _baseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'New Base Fare',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _distCtrl,
                        decoration: const InputDecoration(
                          labelText: 'New Distance Fee',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _waitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'New Wait Penalty',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _surCtrl,
                        decoration: const InputDecoration(
                          labelText: 'New Surcharge Total',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                          ),
                          icon: const Icon(Icons.warning_amber),
                          label: const Text(
                            'Apply Destructive Override',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            widget.bloc.add(
                              OverrideJobPricing(
                                requestId: currentJob.requestId,
                                pricingData: {
                                  'newBaseFare':
                                      double.tryParse(_baseCtrl.text) ??
                                      currentJob.baseFare,
                                  'newDistanceFare':
                                      double.tryParse(_distCtrl.text) ??
                                      currentJob.distanceFee,
                                  'newWaitingTimeCharges':
                                      double.tryParse(_waitCtrl.text) ??
                                      currentJob.waitPenalty,
                                  'newSurchargeTotal':
                                      double.tryParse(_surCtrl.text) ??
                                      currentJob.surcharges,
                                  'overrideReason':
                                      'Admin Panel Manual Override',
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaAndAddonsTab(ActiveJobModel currentJob) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Job Addons & Surcharges',
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: widget.theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty)
                          return _predefinedAddons;
                        return _predefinedAddons.where(
                          (String option) => option.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          ),
                        );
                      },
                      onSelected: (String selection) =>
                          _addonDescMainCtrl.text = selection,
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            controller.addListener(
                              () => _addonDescMainCtrl.text = controller.text,
                            );
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Addon Description',
                                filled: true,
                                fillColor: widget.theme.cardColor,
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                              ),
                            );
                          },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addonPriceCtrl,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        filled: true,
                        fillColor: widget.theme.cardColor,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add_card),
                        label: const Text('Inject Addon Charge'),
                        onPressed: () {
                          widget.bloc.add(
                            AddJobAddon(
                              requestId: currentJob.requestId,
                              description: _addonDescMainCtrl.text,
                              price:
                                  double.tryParse(_addonPriceCtrl.text) ?? 0.0,
                            ),
                          );
                          _addonDescMainCtrl.clear();
                          _addonPriceCtrl.clear();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: currentJob.addons.isEmpty
                    ? Center(
                        child: Text(
                          'No addons applied.',
                          style: TextStyle(color: widget.theme.disabledColor),
                        ),
                      )
                    : ListView.separated(
                        itemCount: currentJob.addons.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (c, i) => ListTile(
                          leading: const Icon(
                            Icons.monetization_on,
                            color: Colors.green,
                          ),
                          title: Text(currentJob.addons[i].description),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${currentJob.addons[i].price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Reverse Charge',
                                onPressed: () {
                                  final targetId = currentJob.addons[i].id;
                                  if (targetId.isNotEmpty)
                                    widget.bloc.add(
                                      RemoveJobAddon(
                                        requestId: currentJob.requestId,
                                        addonId: targetId,
                                      ),
                                    );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Media & Incident Evidence',
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: widget.theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey(_photoType),
                      initialValue: _photoType,
                      dropdownColor: widget.theme.cardColor,
                      decoration: InputDecoration(
                        labelText: 'Photo Type',
                        filled: true,
                        fillColor: widget.theme.cardColor,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'DamageReport',
                          child: Text('Damage Report'),
                        ),
                        DropdownMenuItem(
                          value: 'DeliveryProof',
                          child: Text('Delivery Proof'),
                        ),
                        DropdownMenuItem(
                          value: 'General',
                          child: Text('General Evidence'),
                        ),
                      ],
                      onChanged: (v) => _photoType = v!,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickEvidenceFile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color:
                              widget.theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: widget.theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.attachment,
                              color: widget.theme.primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedPhotoFile != null
                                    ? _selectedPhotoFile!.name
                                    : 'Tap to browse and select image file...',
                                style: TextStyle(
                                  color: _selectedPhotoFile != null
                                      ? widget.theme.colorScheme.onSurface
                                      : widget.theme.disabledColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _photoNotesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Admin Notes (Optional)',
                        filled: true,
                        fillColor: widget.theme.cardColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: _isUploadingFile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(
                          _isUploadingFile ? 'Uploading...' : 'Attach Evidence',
                        ),
                        onPressed: () async {
                          if (_selectedPhotoFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a file first.'),
                              ),
                            );
                            return;
                          }
                          setState(() => _isUploadingFile = true);
                          try {
                            await Future.delayed(const Duration(seconds: 2));
                            final uploadedUrl =
                                'https://production-storage.com/evidence/${_selectedPhotoFile!.name}';
                            widget.bloc.add(
                              AddJobPhoto(
                                requestId: currentJob.requestId,
                                photoUrl: uploadedUrl,
                                photoType: _photoType,
                                notes: _photoNotesCtrl.text.isNotEmpty
                                    ? _photoNotesCtrl.text
                                    : null,
                              ),
                            );
                            setState(() {
                              _selectedPhotoFile = null;
                              _photoNotesCtrl.clear();
                            });
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Upload failed: $e')),
                            );
                          } finally {
                            setState(() => _isUploadingFile = false);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: currentJob.photos.isEmpty
                    ? Center(
                        child: Text(
                          'No evidence attached.',
                          style: TextStyle(color: widget.theme.disabledColor),
                        ),
                      )
                    : ListView.separated(
                        itemCount: currentJob.photos.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (c, i) => ListTile(
                          leading: const Icon(Icons.image, color: Colors.blue),
                          title: Text(currentJob.photos[i].photoType),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentJob.photos[i].url,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (currentJob.photos[i].notes != null &&
                                  currentJob.photos[i].notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Notes: ${currentJob.photos[i].notes}',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: widget
                                          .theme
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAccordion({
    required String role,
    required String name,
    required String phone,
    required Map<String, String> extraDetails,
    required ThemeData theme,
    required VoidCallback crmAction,
  }) {
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        collapsedBackgroundColor: theme.cardColor,
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        leading: CircleAvatar(
          backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.person, color: theme.primaryColor),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(role),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone),
                  title: const Text('Contact Number'),
                  subtitle: Text(phone),
                  trailing: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View Full CRM Profile'),
                    onPressed: crmAction,
                  ),
                ),
                const Divider(),
                ...extraDetails.entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFleetCommander(ActiveJobModel currentJob) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      pageBuilder: (ctx, _, __) => const SizedBox(),
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(anim),
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: widget.theme.scaffoldBackgroundColor,
              child: Container(
                width: 450,
                height: double.infinity,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: widget.theme.dividerColor),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      color: widget.theme.cardColor,
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: widget.theme.colorScheme.onSurface,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Fleet Commander',
                            style: TextStyle(
                              color: widget.theme.colorScheme.onSurface,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: widget.fleet.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (c, i) {
                          final driver = widget.fleet[i];
                          return ListTile(
                            tileColor: widget.theme.cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.withValues(
                                alpha: 0.2,
                              ),
                              child: const Icon(
                                Icons.local_shipping,
                                color: Colors.green,
                              ),
                            ),
                            title: Text(
                              driver.fullName,
                              style: TextStyle(
                                color: widget.theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${driver.vehicle} • Available',
                              style: const TextStyle(color: Colors.green),
                            ),
                            trailing: FilledButton(
                              onPressed: () {
                                widget.bloc.add(
                                  AssignDriver(
                                    requestId: currentJob.requestId,
                                    driverId: driver.id,
                                  ),
                                );
                                Navigator.pop(ctx);
                              },
                              child: const Text('Dispatch'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.purple;
      case 3:
        return Colors.green;
      default:
        return Colors.red;
    }
  }
}

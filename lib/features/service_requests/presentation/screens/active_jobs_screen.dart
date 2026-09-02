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
  String _searchQuery = '';
  // 0: Pending, 1: In Progress, 2: Completed, 3: Cancelled
  int _selectedFilterTab = 0;
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

                              bool matchesStatus = false;
                              if (_selectedFilterTab == 0) {
                                // Pending
                                matchesStatus = j.status == 0;
                              } else if (_selectedFilterTab == 1) {
                                // In Progress (Accepted, Arrived, Waiting, Loading, Transit)
                                matchesStatus = [
                                  1,
                                  2,
                                  4,
                                  5,
                                  6,
                                ].contains(j.status);
                              } else if (_selectedFilterTab == 2) {
                                // Completed
                                matchesStatus = j.status == 3;
                              } else if (_selectedFilterTab == 3) {
                                // Cancelled
                                matchesStatus = j.status == 99;
                              }

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
          'Jobs & History',
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
              icon: const Icon(Icons.add),
              label: const Text('Create New Job'),
              onPressed: () => _openDispatchWizard(context, theme),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusFilters(ThemeData theme) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('Pending Jobs')),
        ButtonSegment(value: 1, label: Text('In Progress')),
        ButtonSegment(value: 2, label: Text('Completed')),
        ButtonSegment(value: 3, label: Text('Cancelled')),
      ],
      selected: {_selectedFilterTab},
      onSelectionChanged: (set) {
        setState(() => _selectedFilterTab = set.first);
      },
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
          'No jobs found.',
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
                  child: const Text('View Details'),
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
      case 2:
      case 4:
      case 5:
      case 6:
        return Colors.blue;
      case 3:
        return Colors.green;
      default:
        return Colors.red;
    }
  }
}

// ============================================================================
// THE CREATE JOB WIZARD (Simplified English)
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
                          _currentStep == 3 ? 'Confirm & Send' : 'Next Step',
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
                  title: const Text('Customer Info'),
                  isActive: _currentStep >= 0,
                  content: _buildCustomerAndVehicleStep(),
                ),
                Step(
                  title: const Text('Map Location'),
                  isActive: _currentStep >= 1,
                  content: _buildMapStep(),
                ),
                Step(
                  title: const Text('Service Needs'),
                  isActive: _currentStep >= 2,
                  content: _buildServiceDetailsStep(),
                ),
                Step(
                  title: const Text('Assign Driver'),
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
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
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
                          _selectedYear = v.year;
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
        // FIXED: Included ALL 10 Service Types in the Wizard
        DropdownButtonFormField<int>(
          key: ValueKey(_serviceType),
          initialValue: _serviceType,
          dropdownColor: widget.theme.cardColor,
          decoration: InputDecoration(
            labelText: 'Service Needed',
            filled: true,
            fillColor: widget.theme.cardColor,
            border: const OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 1, child: Text('Wheel Lift Towing')),
            DropdownMenuItem(value: 2, child: Text('Flatbed Towing')),
            DropdownMenuItem(value: 3, child: Text('Underground/Specialty')),
            DropdownMenuItem(value: 4, child: Text('Heavy Duty Commercial')),
            DropdownMenuItem(value: 5, child: Text('Motorcycle Towing')),
            DropdownMenuItem(value: 6, child: Text('Jump Start')),
            DropdownMenuItem(value: 7, child: Text('Flat Tire')),
            DropdownMenuItem(value: 8, child: Text('Lockout Service')),
            DropdownMenuItem(value: 9, child: Text('Fuel Delivery')),
            DropdownMenuItem(value: 10, child: Text('Winching / Recovery')),
          ],
          onChanged: (v) => setState(() => _serviceType = v!),
        ),
        const SizedBox(height: 24),
        Text(
          'Vehicle Condition',
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
                title: const Text('Car Can Drive'),
                value: _isDrivable,
                onChanged: (v) => setState(() => _isDrivable = v),
              ),
            ),
            Expanded(
              child: SwitchListTile(
                title: const Text('Wheels Locked'),
                value: _wheelsLocked,
                onChanged: (v) => setState(() => _wheelsLocked = v),
              ),
            ),
            Expanded(
              child: SwitchListTile(
                title: const Text('Needs Dollies'),
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
          decoration: InputDecoration(
            labelText: 'Assign Driver (Leave blank to queue)',
            filled: true,
            fillColor: widget.theme.cardColor,
            border: const OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Send to all available drivers'),
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
// JOB DETAILS MODAL (Command Center)
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

  late int _editStatus;

  late TextEditingController _baseCtrl;
  late TextEditingController _distCtrl;
  late TextEditingController _waitCtrl;
  late TextEditingController _surCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _editStatus = widget.job.status;

    _baseCtrl = TextEditingController(text: widget.job.baseFare.toString());
    _distCtrl = TextEditingController(text: widget.job.distanceFee.toString());
    _waitCtrl = TextEditingController(text: widget.job.waitPenalty.toString());
    _surCtrl = TextEditingController(text: widget.job.surcharges.toString());
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
            _editStatus = currentJob.status;
          } catch (e) {}
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
                        'Job Details: #${currentJob.requestId.substring(0, 8).toUpperCase()}',
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
                            color: Colors.blue,
                          ),
                        ),
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
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
                  Tab(icon: Icon(Icons.map), text: 'Map & Details'),
                  Tab(icon: Icon(Icons.receipt_long), text: 'Edit Prices'),
                  Tab(icon: Icon(Icons.photo_library), text: 'Photos & Extras'),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLogisticsTab(currentJob),
                    _buildFinancialsTab(currentJob),
                    const Center(
                      child: Text("Photos and Extras managed via mobile app."),
                    ),
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
                  'People Involved',
                  style: TextStyle(
                    color: widget.theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(currentJob.customerName),
                  subtitle: Text(currentJob.customerPhone),
                  tileColor: widget.theme.cardColor,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.local_shipping),
                  title: Text(
                    currentJob.driverName.isEmpty
                        ? "No Driver Assigned"
                        : currentJob.driverName,
                  ),
                  subtitle: Text(currentJob.statusText),
                  tileColor: widget.theme.cardColor,
                ),
                const SizedBox(height: 32),
                Text(
                  'Update Job Settings',
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
                      // FIXED: Added Status 4 to prevent assertion crashes
                      child: DropdownButtonFormField<int>(
                        value: _editStatus,
                        dropdownColor: widget.theme.cardColor,
                        decoration: InputDecoration(
                          labelText: 'Job Status',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: widget.theme.cardColor,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 0,
                            child: Text(
                              'Pending',
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
                              'Loading Car',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 6,
                            child: Text(
                              'Driving to Dropoff',
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
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    widget.bloc.add(
                      UpdateJobDetails(
                        requestId: currentJob.requestId,
                        updateData: {'status': _editStatus},
                      ),
                    );
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialsTab(ActiveJobModel currentJob) {
    return Column(
      children: [
        ListTile(
          title: const Text('Total Cost'),
          trailing: Text(
            '\$${currentJob.totalFare.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(),
        TextFormField(
          controller: _baseCtrl,
          decoration: const InputDecoration(labelText: 'New Base Price'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => widget.bloc.add(
            OverrideJobPricing(
              requestId: currentJob.requestId,
              pricingData: {
                'newBaseFare':
                    double.tryParse(_baseCtrl.text) ?? currentJob.baseFare,
              },
            ),
          ),
          child: const Text('Update Price'),
        ),
      ],
    );
  }
}

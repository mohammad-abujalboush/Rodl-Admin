import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:roadside_service/features/service_requests/presentation/screens/active_jobs_screen.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/live_radar_bloc.dart';

class LiveRadarScreen extends StatefulWidget {
  const LiveRadarScreen({super.key});

  @override
  State<LiveRadarScreen> createState() => _LiveRadarScreenState();
}

class _LiveRadarScreenState extends State<LiveRadarScreen> {
  GoogleMapController? _mapController;

  static bool _showDrivers = true;
  static bool _showOfflineDrivers = false; // NEW TOGGLE
  static bool _showActiveJobs = true;
  static bool _showHistoricalHeatmap = false;
  static bool _showDriverHeatmap = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(31.9454, 35.9284),
    zoom: 12.0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => sl<LiveRadarBloc>()..add(InitializeRadar()),
      child: Scaffold(
        body: ResponsiveBuilder(
          builder: (context, sizingInfo) {
            final isDesktop = sizingInfo.isDesktop;

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      // --- THE MAP LAYER ---
                      BlocConsumer<LiveRadarBloc, LiveRadarState>(
                        listener: (context, state) {
                          if (state.successMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.successMessage!),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                          if (state.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.error!),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        },
                        builder: (context, state) {
                          Set<Marker> displayMarkers = {};
                          Set<Circle> displayCircles = {};

                          // Add Online Drivers
                          if (_showDrivers) {
                            displayMarkers.addAll(
                              state.onlineDriverMarkers.values,
                            );
                          }
                          // Add Offline Drivers
                          if (_showOfflineDrivers) {
                            displayMarkers.addAll(
                              state.offlineDriverMarkers.values,
                            );
                          }
                          // Add Jobs
                          if (_showActiveJobs) {
                            displayMarkers.addAll(state.jobMarkers.values);
                          }

                          if (_showHistoricalHeatmap) {
                            displayCircles.addAll(
                              state.historicalCircles.values,
                            );
                          }
                          if (_showDriverHeatmap) {
                            displayCircles.addAll(
                              state.driverHeatmapCircles.values,
                            );
                          }

                          return GoogleMap(
                            initialCameraPosition: _initialPosition,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: !isDesktop,
                            mapType: MapType.normal,
                            markers: displayMarkers,
                            polylines: _showActiveJobs
                                ? Set<Polyline>.of(state.jobPolylines.values)
                                : {},
                            circles: displayCircles,
                            onMapCreated: (controller) =>
                                _mapController = controller,
                            onTap: (_) {
                              context.read<LiveRadarBloc>().add(
                                SelectJobIndicator(null),
                              );
                              context.read<LiveRadarBloc>().add(
                                SelectDriverIndicator(null),
                              );
                            },
                          );
                        },
                      ),

                      // --- SLEEK ACTION PILL ---
                      Positioned(
                        top: 24,
                        left: 24,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              color: theme.colorScheme.surface.withOpacity(0.8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.my_location),
                                    color: theme.primaryColor,
                                    onPressed: () =>
                                        _mapController?.animateCamera(
                                          CameraUpdate.newCameraPosition(
                                            _initialPosition,
                                          ),
                                        ),
                                  ),
                                  Container(
                                    height: 20,
                                    width: 1,
                                    color: theme.dividerColor,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                  ),
                                  BlocBuilder<LiveRadarBloc, LiveRadarState>(
                                    builder: (context, state) => IconButton(
                                      icon: const Icon(Icons.zoom_out_map),
                                      color: theme.colorScheme.secondary,
                                      onPressed: () => _fitMapToMarkers(state),
                                    ),
                                  ),
                                  Container(
                                    height: 20,
                                    width: 1,
                                    color: theme.dividerColor,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                  ),
                                  Builder(
                                    builder: (ctx) => IconButton(
                                      icon: const Icon(Icons.refresh),
                                      color: Colors.green,
                                      onPressed: () => ctx
                                          .read<LiveRadarBloc>()
                                          .add(InitializeRadar()),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // --- ANIMATED HUD OVERLAYS ---
                      BlocBuilder<LiveRadarBloc, LiveRadarState>(
                        builder: (context, state) {
                          final isJobVisible = state.selectedJob != null;
                          final isDriverVisible = state.selectedDriver != null;

                          return Stack(
                            children: [
                              // JOB OVERLAY
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                bottom: isJobVisible ? 40 : -350,
                                left: 24,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 250),
                                  opacity: isJobVisible ? 1.0 : 0.0,
                                  child: isJobVisible
                                      ? _JobInfoOverlay(
                                          jobData: state.selectedJob!,
                                          onClose: () => context
                                              .read<LiveRadarBloc>()
                                              .add(SelectJobIndicator(null)),
                                          onExpand: () {
                                            final jobId =
                                                state.selectedJob!['requestId'];
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ActiveJobsScreen(
                                                      autoOpenJobId: jobId,
                                                    ),
                                              ),
                                            );
                                          },
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                              // DRIVER OVERLAY
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                bottom: isDriverVisible ? 40 : -350,
                                left: 24,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 250),
                                  opacity: isDriverVisible ? 1.0 : 0.0,
                                  child: isDriverVisible
                                      ? _DriverInfoOverlay(
                                          driverData: state.selectedDriver!,
                                          bloc: context.read<LiveRadarBloc>(),
                                          onClose: () => context
                                              .read<LiveRadarBloc>()
                                              .add(SelectDriverIndicator(null)),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // --- GLASSMORPHISM SIDEBAR ---
                if (isDesktop)
                  ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: 380,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(
                            0.95,
                          ), // Fixed Light Mode contrast
                          border: Border(
                            left: BorderSide(
                              color: theme.dividerColor.withOpacity(0.5),
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(-5, 0),
                            ),
                          ],
                        ),
                        child: _buildControlPanel(theme),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _fitMapToMarkers(LiveRadarState state) {
    if (_mapController == null) return;
    List<LatLng> points = [];
    if (_showDrivers)
      points.addAll(state.onlineDriverMarkers.values.map((m) => m.position));
    if (_showOfflineDrivers)
      points.addAll(state.offlineDriverMarkers.values.map((m) => m.position));
    if (_showActiveJobs)
      points.addAll(state.jobMarkers.values.map((m) => m.position));
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80.0,
      ),
    );
  }

  Widget _buildControlPanel(ThemeData theme) {
    return BlocBuilder<LiveRadarBloc, LiveRadarState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.satellite_alt,
                    color: theme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Radar Controls',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  Text(
                    'MAP LAYERS',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildAnimatedToggle(
                    'Live Fleet (Online)',
                    _showDrivers,
                    Colors.blue,
                    Icons.local_shipping,
                    (v) => setState(() => _showDrivers = v),
                    theme,
                  ),
                  const SizedBox(height: 16),
                  _buildAnimatedToggle(
                    'Offline Drivers (Last Known)',
                    _showOfflineDrivers,
                    Colors.grey,
                    Icons.location_disabled,
                    (v) => setState(() => _showOfflineDrivers = v),
                    theme,
                  ),
                  const SizedBox(height: 16),
                  _buildAnimatedToggle(
                    'Active Incidents',
                    _showActiveJobs,
                    Colors.orange,
                    Icons.warning,
                    (v) => setState(() => _showActiveJobs = v),
                    theme,
                  ),
                  const SizedBox(height: 16),
                  _buildAnimatedToggle(
                    'Driver Concentration (Heat)',
                    _showDriverHeatmap,
                    Colors.lightBlue,
                    Icons.radar,
                    (v) => setState(() => _showDriverHeatmap = v),
                    theme,
                  ),
                  const SizedBox(height: 16),
                  _buildAnimatedToggle(
                    'Historical Incident Heatmap',
                    _showHistoricalHeatmap,
                    Colors.purple,
                    Icons.map,
                    (v) => setState(() => _showHistoricalHeatmap = v),
                    theme,
                  ),

                  const SizedBox(height: 48),
                  const Divider(),
                  const SizedBox(height: 48),

                  Text(
                    'LIVE TELEMETRY',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (state.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    // FIX: Real dynamic calculation of the online fleet!
                    _buildAnimatedStat(
                      'Total Fleet Online',
                      state.onlineDriverMarkers.length,
                      theme,
                    ),
                    const SizedBox(height: 16),
                    _buildAnimatedStat(
                      'Active Extractions',
                      state.jobMarkers.length ~/ 2,
                      theme,
                      isAlert: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedToggle(
    String title,
    bool value,
    Color color,
    IconData icon,
    Function(bool) onChanged,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? color.withOpacity(0.5)
                : theme.dividerColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: value ? color : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: value
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedStat(
    String label,
    int value,
    ThemeData theme, {
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert
              ? Colors.orange.withOpacity(0.3)
              : theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              '$value',
              key: ValueKey<int>(value),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: isAlert ? Colors.orange : theme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- DRIVER OVERLAY (UPDATED FOR LIGHT THEME FIXES) ---
class _DriverInfoOverlay extends StatelessWidget {
  final Map<String, dynamic> driverData;
  final LiveRadarBloc bloc;
  final VoidCallback onClose;

  const _DriverInfoOverlay({
    required this.driverData,
    required this.bloc,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String driverId =
        driverData['driverId'] ?? driverData['DriverId'] ?? '';
    final String name =
        driverData['name'] ?? driverData['Name'] ?? 'Unknown Driver';
    final String vehicle =
        driverData['vehicleDetails'] ??
        driverData['VehicleDetails'] ??
        'Unknown Vehicle';
    final String stateStr = driverData['calculatedState'] ?? 'Unknown';

    Color stateColor = Colors.green;
    if (stateStr == 'Active Job') stateColor = Colors.red;
    if (stateStr == 'Idle Warning') stateColor = Colors.orange;
    if (stateStr == 'Offline') stateColor = Colors.grey;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(
              0.95,
            ), // Fixed for light mode contrast
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: stateColor.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: stateColor.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stateColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stateStr.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: stateColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.dividerColor.withOpacity(0.2),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    radius: 20,
                    child: Icon(
                      Icons.local_shipping,
                      size: 20,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          vehicle,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (stateStr == 'Idle Warning')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.notification_important, size: 18),
                    label: const Text(
                      'Send Wake-Up Ping',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => bloc.add(PingDriver(driverId: driverId)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- JOB OVERLAY (UPDATED FOR LIGHT THEME FIXES) ---
class _JobInfoOverlay extends StatelessWidget {
  final Map<String, dynamic> jobData;
  final VoidCallback onClose;
  final VoidCallback onExpand;

  const _JobInfoOverlay({
    required this.jobData,
    required this.onClose,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jobId =
        jobData['requestId']?.toString().substring(0, 8).toUpperCase() ?? 'N/A';
    final customerName =
        jobData['customerName'] ??
        jobData['CustomerName'] ??
        'Unknown Customer';
    final customerPhone =
        jobData['customerPhone'] ?? jobData['CustomerPhone'] ?? 'No Phone';
    final driverName =
        jobData['driverName'] ?? jobData['DriverName'] ?? 'Unassigned';
    final int status = jobData['status'] ?? jobData['Status'] ?? 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(
              0.95,
            ), // Fixed for light mode contrast
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: status == 0
                  ? Colors.orange.withOpacity(0.5)
                  : Colors.blue.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: status == 0
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status == 0
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'INCIDENT #$jobId',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: status == 0 ? Colors.orange : Colors.blue,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.dividerColor.withOpacity(0.2),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    radius: 20,
                    child: Icon(
                      Icons.person,
                      size: 20,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          customerPhone,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.trip_origin,
                    size: 16,
                    color: status == 0 ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      status == 0
                          ? 'Awaiting Fleet Assignment'
                          : 'Assigned: $driverName',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: status == 0 ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.launch, size: 18),
                  label: const Text(
                    'Open Command Center',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: onExpand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:roadside_service/features/incident_review/data/models/incident_review_models.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/incident_review_bloc.dart';

class IncidentReviewScreen extends StatefulWidget {
  const IncidentReviewScreen({super.key});

  @override
  State<IncidentReviewScreen> createState() => _IncidentReviewScreenState();
}

class _IncidentReviewScreenState extends State<IncidentReviewScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => sl<IncidentReviewBloc>(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor, // Light theme compliant
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, context),
                const SizedBox(height: 32),
                Expanded(
                  child: BlocConsumer<IncidentReviewBloc, IncidentReviewState>(
                    listener: (context, state) {
                      if (state is IncidentError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      if (state is IncidentIdle) {
                        return _buildIdleState(theme);
                      } else if (state is IncidentLoading) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (state is IncidentLoaded) {
                        return ResponsiveBuilder(
                          builder: (context, sizingInfo) {
                            if (sizingInfo.isMobile || sizingInfo.isTablet) {
                              return _buildMobileView(state.dossier, theme);
                            }
                            return _buildDesktopView(state.dossier, theme);
                          },
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
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Job History & GPS Archive',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Review past dispatch incidents, status timelines, and driver routes.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Builder(
          builder: (blocContext) => Row(
            children: [
              SizedBox(
                width: 350,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Enter Job ID...',
                    prefixIcon: const Icon(Icons.history),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  onSubmitted: (val) {
                    blocContext.read<IncidentReviewBloc>().add(
                      SearchIncident(jobId: val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                icon: const Icon(Icons.search),
                label: const Text(
                  'Search',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  blocContext.read<IncidentReviewBloc>().add(
                    SearchIncident(jobId: _searchController.text),
                  );
                },
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear'),
                onPressed: () {
                  _searchController.clear();
                  blocContext.read<IncidentReviewBloc>().add(
                    ClearIncidentSearch(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdleState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.travel_explore,
            size: 80,
            color: theme.disabledColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Search Archive',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a precise Job ID to load the timeline and GPS map.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopView(IncidentDossierModel dossier, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildJobSummaryCard(dossier.job, theme),
              const SizedBox(height: 24),
              Expanded(child: _buildTimelineCard(dossier.timeline, theme)),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 2,
          child: _buildBreadcrumbMapCard(dossier.breadcrumbs, theme),
        ),
      ],
    );
  }

  Widget _buildMobileView(IncidentDossierModel dossier, ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildJobSummaryCard(dossier.job, theme),
          const SizedBox(height: 24),
          SizedBox(
            height: 350,
            child: _buildBreadcrumbMapCard(dossier.breadcrumbs, theme),
          ),
          const SizedBox(height: 24),
          _buildTimelineCard(dossier.timeline, theme, isMobile: true),
        ],
      ),
    );
  }

  Widget _buildJobSummaryCard(HistoricalJobModel job, ThemeData theme) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // FIX: Corrected Border syntax
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Job ID: ${job.requestId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Chip(
                  label: Text(
                    job.finalStatusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: job.finalStatus == 3
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                  backgroundColor:
                      (job.finalStatus == 3 ? Colors.green : Colors.red)
                          .withValues(alpha: 0.1),
                  side: BorderSide.none,
                ),
              ],
            ),
            Divider(
              height: 32,
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer: ${job.customerName}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Driver: ${job.driverName}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  currencyFormat.format(job.totalFare),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(
    List<StatusHistoryModel> timeline,
    ThemeData theme, {
    bool isMobile = false,
  }) {
    if (timeline.isEmpty) {
      return Card(
        elevation: 0,
        color: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          // FIX: Corrected Border syntax
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            'No timeline events found.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // FIX: Corrected Border syntax
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Timeline',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              flex: isMobile ? 0 : 1,
              child: ListView.builder(
                shrinkWrap: isMobile,
                physics: isMobile ? const NeverScrollableScrollPhysics() : null,
                itemCount: timeline.length,
                itemBuilder: (context, index) {
                  final event = timeline[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (index != timeline.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: theme.dividerColor.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      _getStatusString(event.status),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Changed by: ${event.changedBy}\n${event.notes ?? ""}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                    trailing: Text(
                      DateFormat('HH:mm:ss\nMMM dd').format(event.timestamp),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.disabledColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbMapCard(
    List<LocationBreadcrumbModel> breadcrumbs,
    ThemeData theme,
  ) {
    if (breadcrumbs.isEmpty) {
      return Card(
        elevation: 0,
        color: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          // FIX: Corrected Border syntax
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            'No GPS map data recorded for this job.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final polylineCoords = breadcrumbs.map((b) => b.toLatLng()).toList();
    final initialTarget = polylineCoords.isNotEmpty
        ? polylineCoords.first
        : const LatLng(0, 0);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // FIX: Corrected Border syntax
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 14.0,
            ),
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: polylineCoords,
                color: theme.primaryColor,
                width: 4,
              ),
            },
            markers: {
              if (polylineCoords.isNotEmpty)
                Marker(
                  markerId: const MarkerId('start'),
                  position: polylineCoords.first,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                  infoWindow: const InfoWindow(title: 'Start Location'),
                ),
              if (polylineCoords.length > 1)
                Marker(
                  markerId: const MarkerId('end'),
                  position: polylineCoords.last,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                  infoWindow: const InfoWindow(title: 'Final Location'),
                ),
            },
            zoomControlsEnabled: true,
            mapType: MapType.normal,
            myLocationEnabled: false,
          ),
          Positioned(
            top: 24,
            left: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                'GPS Route Map',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusString(int status) {
    switch (status) {
      case 0:
        return 'Pending Request';
      case 1:
        return 'Driver Accepted';
      case 2:
        return 'Driver Arrived';
      case 3:
        return 'Job Completed';
      case 4:
        return 'Waiting on Customer';
      case 5:
        return 'Loading Vehicle';
      case 6:
        return 'In Transit';
      case 99:
        return 'Job Cancelled';
      default:
        return 'Status Update ($status)';
    }
  }
}

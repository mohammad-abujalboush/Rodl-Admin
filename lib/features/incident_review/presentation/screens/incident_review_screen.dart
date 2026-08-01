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
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, context),
                const SizedBox(height: 24),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Incident Review & Archive',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (blocContext) => Row(
            children: [
              SizedBox(
                width: 350,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Enter Job Request ID...',
                    prefixIcon: const Icon(Icons.history),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
              ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('Pull Archive'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  backgroundColor: theme.primaryColor,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                onPressed: () {
                  blocContext.read<IncidentReviewBloc>().add(
                    SearchIncident(jobId: _searchController.text),
                  );
                },
              ),
              const Spacer(),
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
            color: theme.disabledColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'God View Archive',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a Job ID to retrieve the historical status timeline and GPS breadcrumbs.',
            style: TextStyle(color: theme.disabledColor),
          ),
        ],
      ),
    );
  }

  // --- DESKTOP VIEW ---
  Widget _buildDesktopView(IncidentDossierModel dossier, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel: Job Details & Micro-Timeline
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildJobSummaryCard(dossier.job, theme),
              const SizedBox(height: 16),
              Expanded(child: _buildTimelineCard(dossier.timeline, theme)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Panel: God View Map Archive
        Expanded(
          flex: 2,
          child: _buildBreadcrumbMapCard(dossier.breadcrumbs, theme),
        ),
      ],
    );
  }

  // --- MOBILE VIEW ---
  Widget _buildMobileView(IncidentDossierModel dossier, ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildJobSummaryCard(dossier.job, theme),
          const SizedBox(height: 16),
          SizedBox(
            height: 350,
            child: _buildBreadcrumbMapCard(dossier.breadcrumbs, theme),
          ),
          const SizedBox(height: 16),
          _buildTimelineCard(dossier.timeline, theme, isMobile: true),
        ],
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildJobSummaryCard(HistoricalJobModel job, ThemeData theme) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Archive File: ${job.requestId.substring(0, 8)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Chip(
                  label: Text(
                    job.finalStatusText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor:
                      (job.finalStatus == 3 ? Colors.green : Colors.red)
                          .withOpacity(0.1),
                  side: BorderSide(
                    color: job.finalStatus == 3 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer: ${job.customerName}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Driver: ${job.driverName}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
                Text(
                  currencyFormat.format(job.totalFare),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
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
      return const Card(
        child: Center(child: Text('No timeline events found.')),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event Micro-Timeline',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: isMobile ? 0 : 1, // Let it scroll if inside fixed column
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
                              color: theme.dividerColor,
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      _getStatusString(event.status),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Changed by: ${event.changedBy}\n${event.notes ?? ""}',
                    ),
                    trailing: Text(
                      DateFormat('HH:mm:ss\nMMM dd').format(event.timestamp),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.disabledColor,
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
        elevation: 2,
        child: Center(
          child: Text(
            'No GPS data recorded for this incident.',
            style: TextStyle(color: theme.disabledColor),
          ),
        ),
      );
    }

    // Prepare map data
    final polylineCoords = breadcrumbs.map((b) => b.toLatLng()).toList();
    final initialTarget = polylineCoords.isNotEmpty
        ? polylineCoords.first
        : const LatLng(0, 0);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
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
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Historical Breadcrumb Trail',
                style: TextStyle(
                  color: Colors.white,
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
        return 'Driver Assigned';
      case 2:
        return 'Driver Arrived';
      case 3:
        return 'Job Completed';
      case 99:
        return 'Job Voided';
      default:
        return 'Status Update ($status)';
    }
  }
}

import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/api/signalr_client.dart';
import '../../../../core/api/dio_client.dart';

// --- EVENTS ---
abstract class LiveRadarEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class InitializeRadar extends LiveRadarEvent {}

class UpdateDriverLocation extends LiveRadarEvent {
  final String driverId;
  final double lat;
  final double lng;
  final bool isOnJob;
  UpdateDriverLocation(this.driverId, this.lat, this.lng, this.isOnJob);
  @override
  List<Object> get props => [driverId, lat, lng, isOnJob];
}

class SyncNewJob extends LiveRadarEvent {
  final Map<String, dynamic> jobData;
  SyncNewJob(this.jobData);
  @override
  List<Object> get props => [jobData];
}

class SyncJobUpdate extends LiveRadarEvent {
  final Map<String, dynamic> jobData;
  SyncJobUpdate(this.jobData);
  @override
  List<Object> get props => [jobData];
}

class SyncJobCompletion extends LiveRadarEvent {
  final String jobId;
  SyncJobCompletion(this.jobId);
  @override
  List<Object> get props => [jobId];
}

class SelectJobIndicator extends LiveRadarEvent {
  final Map<String, dynamic>? jobData;
  SelectJobIndicator(this.jobData);
  @override
  List<Object?> get props => [jobData];
}

class SelectDriverIndicator extends LiveRadarEvent {
  final Map<String, dynamic>? driverData;
  SelectDriverIndicator(this.driverData);
  @override
  List<Object?> get props => [driverData];
}

class PingDriver extends LiveRadarEvent {
  final String driverId;
  PingDriver({required this.driverId});
  @override
  List<Object> get props => [driverId];
}

// --- STATES ---
class LiveRadarState extends Equatable {
  final bool isLoading;
  final Map<String, Marker> onlineDriverMarkers;
  final Map<String, Marker> offlineDriverMarkers;
  final Map<String, Marker> jobMarkers;
  final Map<String, Circle> historicalCircles;
  final Map<String, Circle> driverHeatmapCircles;
  final Map<String, Polyline> jobPolylines;
  final Map<String, Map<String, dynamic>> rawJobData;
  final Map<String, Map<String, dynamic>>
  rawDriverData; // FIX: Prevents driver amnesia
  final Map<String, dynamic>? selectedJob;
  final Map<String, dynamic>? selectedDriver;
  final String? error;
  final String? successMessage;

  const LiveRadarState({
    this.isLoading = true,
    this.onlineDriverMarkers = const {},
    this.offlineDriverMarkers = const {},
    this.jobMarkers = const {},
    this.historicalCircles = const {},
    this.driverHeatmapCircles = const {},
    this.jobPolylines = const {},
    this.rawJobData = const {},
    this.rawDriverData = const {},
    this.selectedJob,
    this.selectedDriver,
    this.error,
    this.successMessage,
  });

  LiveRadarState copyWith({
    bool? isLoading,
    Map<String, Marker>? onlineDriverMarkers,
    Map<String, Marker>? offlineDriverMarkers,
    Map<String, Marker>? jobMarkers,
    Map<String, Circle>? historicalCircles,
    Map<String, Circle>? driverHeatmapCircles,
    Map<String, Polyline>? jobPolylines,
    Map<String, Map<String, dynamic>>? rawJobData,
    Map<String, Map<String, dynamic>>? rawDriverData,
    Map<String, dynamic>? selectedJob,
    Map<String, dynamic>? selectedDriver,
    String? error,
    String? successMessage,
    bool clearSelectedJob = false,
    bool clearSelectedDriver = false,
    bool clearMessages = false,
  }) {
    return LiveRadarState(
      isLoading: isLoading ?? this.isLoading,
      onlineDriverMarkers: onlineDriverMarkers ?? this.onlineDriverMarkers,
      offlineDriverMarkers: offlineDriverMarkers ?? this.offlineDriverMarkers,
      jobMarkers: jobMarkers ?? this.jobMarkers,
      historicalCircles: historicalCircles ?? this.historicalCircles,
      driverHeatmapCircles: driverHeatmapCircles ?? this.driverHeatmapCircles,
      jobPolylines: jobPolylines ?? this.jobPolylines,
      rawJobData: rawJobData ?? this.rawJobData,
      rawDriverData: rawDriverData ?? this.rawDriverData,
      selectedJob: clearSelectedJob ? null : (selectedJob ?? this.selectedJob),
      selectedDriver: clearSelectedDriver
          ? null
          : (selectedDriver ?? this.selectedDriver),
      error: clearMessages ? null : (error ?? this.error),
      successMessage: clearMessages
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    onlineDriverMarkers,
    offlineDriverMarkers,
    jobMarkers,
    historicalCircles,
    driverHeatmapCircles,
    jobPolylines,
    rawJobData,
    rawDriverData,
    selectedJob,
    selectedDriver,
    error,
    successMessage,
  ];
}

// --- BLOC ---
class LiveRadarBloc extends Bloc<LiveRadarEvent, LiveRadarState> {
  final SignalRClient signalRClient;
  final DioClient dioClient;

  StreamSubscription? _locSub;
  StreamSubscription? _newJobSub;
  StreamSubscription? _updJobSub;
  StreamSubscription? _compJobSub;

  // SMALL Driver Icons (40px)
  BitmapDescriptor? _greenTruck;
  BitmapDescriptor? _redTruck;
  BitmapDescriptor? _orangeTruck;
  BitmapDescriptor? _greyTruck;

  // BIG Job Icons (65px)
  BitmapDescriptor? _pendingJobIcon;
  BitmapDescriptor? _activeJobIcon;

  LiveRadarBloc({required this.signalRClient, required this.dioClient})
    : super(const LiveRadarState()) {
    on<InitializeRadar>((event, emit) async {
      emit(state.copyWith(isLoading: true, clearMessages: true));

      try {
        await _cacheMapIcons();
        Response? fleetRes;
        Response? jobsRes;
        Response? heatRes;

        await Future.wait([
          dioClient.dio
              .get('/api/admin/fleet-radar')
              .then((v) => fleetRes = v)
              .catchError((_) => null),
          dioClient.dio
              .get('/api/admin/jobs/active')
              .then((v) => jobsRes = v)
              .catchError((_) => null),
          dioClient.dio
              .get('/api/admin/jobs/heatmap-history')
              .then((v) => heatRes = v)
              .catchError((_) => null),
        ]);

        Map<String, Marker> onlineDrivers = {};
        Map<String, Marker> offlineDrivers = {};
        Map<String, Circle> driverHeatmap = {};
        Map<String, Marker> activeJobs = {};
        Map<String, Polyline> polylines = {};
        Map<String, Circle> history = {};
        Map<String, Map<String, dynamic>> rawJobs = {};
        Map<String, Map<String, dynamic>> rawDrivers =
            {}; // FIX: Caching driver data

        if (fleetRes != null && fleetRes!.statusCode == 200) {
          for (var d in (fleetRes!.data as List)) {
            final id =
                d['driverId']?.toString() ?? d['DriverId']?.toString() ?? '';
            if (id.isEmpty) continue;

            rawDrivers[id] = d; // Cache the data so it isn't lost on movement

            final lat = _extractCoord(d, 'lastLatitude', 'LastLatitude');
            final lng = _extractCoord(d, 'lastLongitude', 'LastLongitude');
            final bool isOnline = d['isOnline'] ?? d['IsOnline'] ?? false;
            final bool isOnJob = d['isOnJob'] ?? d['IsOnJob'] ?? false;
            final bool isIdle = d['isIdle'] ?? d['IsIdle'] ?? false;

            final marker = _createDriverMarker(
              id,
              lat,
              lng,
              isOnline,
              isOnJob,
              isIdle,
              d,
            );
            if (isOnline) {
              onlineDrivers[id] = marker;
            } else {
              offlineDrivers[id] = marker;
            }
            driverHeatmap['heat_drv_$id'] = _createDriverHeatmapCircle(
              id,
              lat,
              lng,
            );
          }
        }

        if (jobsRes != null && jobsRes!.statusCode == 200) {
          for (var j in (jobsRes!.data as List)) {
            final jobId = j['requestId']?.toString() ?? 'unknown_id';
            rawJobs[jobId] = j;

            int status =
                int.tryParse((j['status'] ?? j['Status'] ?? '0').toString()) ??
                0;
            double pickLat = _extractCoord(
              j,
              'pickupLatitude',
              'PickupLatitude',
            );
            double pickLng = _extractCoord(
              j,
              'pickupLongitude',
              'PickupLongitude',
            );
            double dropLat = _extractCoord(
              j,
              'dropoffLatitude',
              'DropoffLatitude',
            );
            double dropLng = _extractCoord(
              j,
              'dropoffLongitude',
              'DropoffLongitude',
            );

            if (pickLat == 0.0 && pickLng == 0.0) {
              pickLat = 31.9522;
              pickLng = 35.2332;
            }

            activeJobs['pickup_$jobId'] = _createJobMarker(
              'pickup_$jobId',
              pickLat,
              pickLng,
              status,
              j,
            );

            // Preserve Route Lines
            if (dropLat != 0.0 &&
                dropLng != 0.0 &&
                (dropLat != pickLat || dropLng != pickLng)) {
              activeJobs['dropoff_$jobId'] = Marker(
                markerId: MarkerId('dropoff_$jobId'),
                position: LatLng(dropLat, dropLng),
                zIndex: 1,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueMagenta,
                ),
                consumeTapEvents: false,
              );
              polylines['path_$jobId'] = Polyline(
                polylineId: PolylineId('path_$jobId'),
                points: [LatLng(pickLat, pickLng), LatLng(dropLat, dropLng)],
                color: Colors.orange,
                width: 4,
                patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                geodesic: true,
                zIndex: 1,
              );
            }
          }
        }

        if (heatRes != null && heatRes!.statusCode == 200) {
          for (var h in (heatRes!.data as List)) {
            final id =
                h['id']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString();
            history[id] = _createHistoryHeatmapCircle(
              id,
              _extractCoord(h, 'lat', 'Lat'),
              _extractCoord(h, 'lng', 'Lng'),
            );
          }
        }

        emit(
          state.copyWith(
            isLoading: false,
            onlineDriverMarkers: onlineDrivers,
            offlineDriverMarkers: offlineDrivers,
            driverHeatmapCircles: driverHeatmap,
            jobMarkers: activeJobs,
            jobPolylines: polylines,
            historicalCircles: history,
            rawJobData: rawJobs,
            rawDriverData: rawDrivers,
          ),
        );

        // SignalR Hooks
        _locSub ??= signalRClient.onDriverLocationUpdate.listen(
          (data) => add(
            UpdateDriverLocation(
              data['DriverId']?.toString() ?? '',
              _extractCoord(data, 'Latitude', 'lat'),
              _extractCoord(data, 'Longitude', 'lng'),
              data['IsOnJob'] ?? false,
            ),
          ),
        );
        _newJobSub ??= signalRClient.onNewJob.listen(
          (data) => add(SyncNewJob(data)),
        );
        _updJobSub ??= signalRClient.onJobUpdated.listen(
          (data) => add(SyncJobUpdate(data)),
        );
        _compJobSub ??= signalRClient.onJobCompleted.listen(
          (id) => add(SyncJobCompletion(id)),
        );
      } catch (e) {
        emit(
          state.copyWith(
            isLoading: false,
            error: 'Failed to sync radar telemetry.',
          ),
        );
      }
    });

    on<SyncNewJob>((event, emit) {
      final jobId =
          event.jobData['requestId']?.toString() ??
          event.jobData['RequestId']?.toString() ??
          '';
      if (jobId.isEmpty) return;

      final updatedJobs = Map<String, Marker>.from(state.jobMarkers);
      final updatedRaw = Map<String, Map<String, dynamic>>.from(
        state.rawJobData,
      );
      final updatedPolylines = Map<String, Polyline>.from(state.jobPolylines);

      // Map.from prevents unmodifiable map crashes
      final newJobData = Map<String, dynamic>.from(event.jobData);
      newJobData['status'] = 0; // Force pending
      updatedRaw[jobId] = newJobData;

      double pickLat = _extractCoord(
        newJobData,
        'pickupLatitude',
        'PickupLatitude',
      );
      double pickLng = _extractCoord(
        newJobData,
        'pickupLongitude',
        'PickupLongitude',
      );
      double dropLat = _extractCoord(
        newJobData,
        'dropoffLatitude',
        'DropoffLatitude',
      );
      double dropLng = _extractCoord(
        newJobData,
        'dropoffLongitude',
        'DropoffLongitude',
      );

      updatedJobs['pickup_$jobId'] = _createJobMarker(
        'pickup_$jobId',
        pickLat,
        pickLng,
        0,
        newJobData,
      );

      // FIX: Ensures routes don't disappear on SignalR update
      if (dropLat != 0.0 &&
          dropLng != 0.0 &&
          (dropLat != pickLat || dropLng != pickLng)) {
        updatedJobs['dropoff_$jobId'] = Marker(
          markerId: MarkerId('dropoff_$jobId'),
          position: LatLng(dropLat, dropLng),
          zIndex: 1,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueMagenta,
          ),
          consumeTapEvents: false,
        );
        updatedPolylines['path_$jobId'] = Polyline(
          polylineId: PolylineId('path_$jobId'),
          points: [LatLng(pickLat, pickLng), LatLng(dropLat, dropLng)],
          color: Colors.orange,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          geodesic: true,
          zIndex: 1,
        );
      }

      emit(
        state.copyWith(
          jobMarkers: updatedJobs,
          jobPolylines: updatedPolylines,
          rawJobData: updatedRaw,
        ),
      );
    });

    on<SyncJobUpdate>((event, emit) {
      final jobId =
          event.jobData['requestId']?.toString() ??
          event.jobData['RequestId']?.toString() ??
          '';
      if (jobId.isEmpty) return;

      final updatedJobs = Map<String, Marker>.from(state.jobMarkers);
      final updatedRaw = Map<String, Map<String, dynamic>>.from(
        state.rawJobData,
      );
      final updatedPolylines = Map<String, Polyline>.from(state.jobPolylines);

      // Map.from prevents unmodifiable map crashes
      final existingJob = Map<String, dynamic>.from(updatedRaw[jobId] ?? {});
      existingJob.addAll(event.jobData);
      updatedRaw[jobId] = existingJob;

      double pickLat = _extractCoord(
        existingJob,
        'pickupLatitude',
        'PickupLatitude',
      );
      double pickLng = _extractCoord(
        existingJob,
        'pickupLongitude',
        'PickupLongitude',
      );
      double dropLat = _extractCoord(
        existingJob,
        'dropoffLatitude',
        'DropoffLatitude',
      );
      double dropLng = _extractCoord(
        existingJob,
        'dropoffLongitude',
        'DropoffLongitude',
      );
      int status =
          int.tryParse(
            (existingJob['status'] ?? existingJob['Status'] ?? '0').toString(),
          ) ??
          0;

      updatedJobs['pickup_$jobId'] = _createJobMarker(
        'pickup_$jobId',
        pickLat,
        pickLng,
        status,
        existingJob,
      );

      // FIX: Ensures routes don't disappear on SignalR update
      if (dropLat != 0.0 &&
          dropLng != 0.0 &&
          (dropLat != pickLat || dropLng != pickLng)) {
        updatedJobs['dropoff_$jobId'] = Marker(
          markerId: MarkerId('dropoff_$jobId'),
          position: LatLng(dropLat, dropLng),
          zIndex: 1,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueMagenta,
          ),
          consumeTapEvents: false,
        );
        updatedPolylines['path_$jobId'] = Polyline(
          polylineId: PolylineId('path_$jobId'),
          points: [LatLng(pickLat, pickLng), LatLng(dropLat, dropLng)],
          color: Colors.orange,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          geodesic: true,
          zIndex: 1,
        );
      }

      emit(
        state.copyWith(
          jobMarkers: updatedJobs,
          jobPolylines: updatedPolylines,
          rawJobData: updatedRaw,
        ),
      );
    });

    on<SyncJobCompletion>((event, emit) {
      final updatedJobs = Map<String, Marker>.from(state.jobMarkers);
      final updatedPolylines = Map<String, Polyline>.from(state.jobPolylines);
      final updatedRaw = Map<String, Map<String, dynamic>>.from(
        state.rawJobData,
      );

      updatedJobs.remove('pickup_${event.jobId}');
      updatedJobs.remove('dropoff_${event.jobId}');
      updatedPolylines.remove('path_${event.jobId}');
      updatedRaw.remove(event.jobId);

      emit(
        state.copyWith(
          jobMarkers: updatedJobs,
          jobPolylines: updatedPolylines,
          rawJobData: updatedRaw,
        ),
      );
    });

    on<UpdateDriverLocation>((event, emit) {
      if (event.driverId.isEmpty) return;
      final updatedOnline = Map<String, Marker>.from(state.onlineDriverMarkers);
      final updatedOffline = Map<String, Marker>.from(
        state.offlineDriverMarkers,
      );
      final updatedHeatmaps = Map<String, Circle>.from(
        state.driverHeatmapCircles,
      );

      // FIX: Pull existing raw driver data instead of passing {} to prevent "Unknown Driver"
      final existingDriverData = state.rawDriverData[event.driverId] ?? {};

      final newMarker = _createDriverMarker(
        event.driverId,
        event.lat,
        event.lng,
        true,
        event.isOnJob,
        false,
        existingDriverData,
      );

      updatedOffline.remove(event.driverId);
      updatedOnline[event.driverId] = newMarker;
      updatedHeatmaps['heat_drv_${event.driverId}'] =
          _createDriverHeatmapCircle(event.driverId, event.lat, event.lng);

      emit(
        state.copyWith(
          onlineDriverMarkers: updatedOnline,
          offlineDriverMarkers: updatedOffline,
          driverHeatmapCircles: updatedHeatmaps,
        ),
      );
    });

    on<PingDriver>((event, emit) async {
      try {
        await dioClient.dio.post('/api/admin/drivers/${event.driverId}/ping');
        emit(
          state.copyWith(
            successMessage: 'Wake-up ping broadcasted to driver.',
            clearMessages: false,
          ),
        );
      } catch (e) {
        emit(
          state.copyWith(
            error: 'Failed to reach driver device.',
            clearMessages: false,
          ),
        );
      }
      await Future.delayed(const Duration(seconds: 2));
      emit(state.copyWith(clearMessages: true));
    });

    on<SelectJobIndicator>(
      (event, emit) => emit(
        state.copyWith(
          selectedJob: event.jobData,
          clearSelectedDriver: true,
          clearSelectedJob: event.jobData == null,
        ),
      ),
    );

    on<SelectDriverIndicator>(
      (event, emit) => emit(
        state.copyWith(
          selectedDriver: event.driverData,
          clearSelectedJob: true,
          clearSelectedDriver: event.driverData == null,
        ),
      ),
    );
  }

  double _extractCoord(Map<String, dynamic> json, String key1, String key2) {
    var val = json[key1] ?? json[key2];
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  Future<void> _cacheMapIcons() async {
    if (_greenTruck != null) return;
    try {
      // Drivers: Small Size (40.0)
      _greenTruck = await _createCustomMarkerIcon(
        Colors.green.shade700,
        Icons.local_shipping,
        40.0,
      );
      _redTruck = await _createCustomMarkerIcon(
        Colors.red.shade700,
        Icons.local_shipping,
        40.0,
      );
      _orangeTruck = await _createCustomMarkerIcon(
        Colors.orange.shade700,
        Icons.local_shipping,
        40.0,
      );
      _greyTruck = await _createCustomMarkerIcon(
        Colors.grey.shade600,
        Icons.local_shipping,
        40.0,
      );

      // Jobs: Large Size (65.0)
      _pendingJobIcon = await _createCustomMarkerIcon(
        Colors.orange.shade700,
        Icons.warning_rounded,
        65.0,
      );
      _activeJobIcon = await _createCustomMarkerIcon(
        Colors.blue.shade700,
        Icons.handyman,
        65.0,
      );
    } catch (e) {
      _greenTruck = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      );
      _redTruck = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
      _orangeTruck = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      );
      _greyTruck = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueYellow,
      );
      _pendingJobIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      );
      _activeJobIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
    }
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(
    Color bgColor,
    IconData iconData,
    double size,
  ) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, borderPaint);

    final Paint bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      (size / 2) - (size * 0.1),
      bgPaint,
    );

    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.55,
        fontFamily: iconData.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Marker _createDriverMarker(
    String id,
    double lat,
    double lng,
    bool isOnline,
    bool isOnJob,
    bool isIdle,
    Map<String, dynamic> rawData,
  ) {
    BitmapDescriptor icon = !isOnline
        ? _greyTruck!
        : (isOnJob ? _redTruck! : (isIdle ? _orangeTruck! : _greenTruck!));
    return Marker(
      markerId: MarkerId('driver_$id'),
      position: LatLng(lat, lng),
      zIndex: isOnline ? 5 : 2,
      icon: icon,
      consumeTapEvents: true,
      onTap: () {
        final data = Map<String, dynamic>.from(rawData);
        data['driverId'] = id;
        data['calculatedState'] = !isOnline
            ? 'Offline'
            : (isOnJob
                  ? 'Active Job'
                  : (isIdle ? 'Idle Warning' : 'Available'));
        add(SelectDriverIndicator(data));
      },
    );
  }

  Marker _createJobMarker(
    String id,
    double lat,
    double lng,
    int status,
    Map<String, dynamic> rawData,
  ) {
    BitmapDescriptor icon = (status == 0)
        ? (_pendingJobIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange))
        : (_activeJobIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure));
    return Marker(
      markerId: MarkerId(id),
      position: LatLng(lat, lng),
      zIndex: 10,
      icon: icon,
      consumeTapEvents: true,
      onTap: () => add(SelectJobIndicator(rawData)),
    );
  }

  Circle _createDriverHeatmapCircle(String id, double lat, double lng) {
    return Circle(
      circleId: CircleId('heat_drv_$id'),
      center: LatLng(lat, lng),
      radius: 1200,
      fillColor: Colors.blue.withOpacity(0.08),
      strokeWidth: 0,
      zIndex: 1,
      consumeTapEvents: false,
    );
  }

  Circle _createHistoryHeatmapCircle(String id, double lat, double lng) {
    return Circle(
      circleId: CircleId('heat_hist_$id'),
      center: LatLng(lat, lng),
      radius: 350,
      fillColor: Colors.purple.withOpacity(0.15),
      strokeWidth: 0,
      zIndex: 0,
      consumeTapEvents: false,
    );
  }

  @override
  Future<void> close() {
    _locSub?.cancel();
    _newJobSub?.cancel();
    _updJobSub?.cancel();
    _compJobSub?.cancel();
    return super.close();
  }
}

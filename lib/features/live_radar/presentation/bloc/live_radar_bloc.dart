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
  final Map<String, Marker> onlineDriverMarkers; // Split for offline toggle
  final Map<String, Marker> offlineDriverMarkers; // Split for offline toggle
  final Map<String, Marker> jobMarkers;
  final Map<String, Circle> historicalCircles;
  final Map<String, Circle> driverHeatmapCircles;
  final Map<String, Polyline> jobPolylines;
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
  StreamSubscription? _locationSub;

  // Cached Custom Truck Icons
  BitmapDescriptor? _greenTruck;
  BitmapDescriptor? _redTruck;
  BitmapDescriptor? _orangeTruck;
  BitmapDescriptor? _greyTruck; // Added for offline drivers

  LiveRadarBloc({required this.signalRClient, required this.dioClient})
    : super(const LiveRadarState()) {
    on<InitializeRadar>((event, emit) async {
      emit(state.copyWith(isLoading: true, clearMessages: true));

      try {
        await _cacheTruckIcons();

        Response? fleetRes;
        Response? jobsRes;
        Response? heatRes;

        await Future.wait([
          // FIX: Pointed to the new API returning ALL drivers (online and offline)
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

        // 1. Process Live Fleet (Drivers)
        if (fleetRes != null && fleetRes!.statusCode == 200) {
          for (var d in (fleetRes!.data as List)) {
            final id =
                d['driverId']?.toString() ?? d['DriverId']?.toString() ?? '';
            if (id.isEmpty) continue;

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

        // 2. Process Active Jobs & Routes
        if (jobsRes != null && jobsRes!.statusCode == 200) {
          for (var j in (jobsRes!.data as List)) {
            final jobId = j['requestId']?.toString() ?? 'unknown_id';

            int status = 0;
            var rawStatus = j['status'] ?? j['Status'];
            if (rawStatus != null) {
              status = (rawStatus is int)
                  ? rawStatus
                  : int.tryParse(rawStatus.toString()) ?? 0;
            }

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

            double hue = (status == 0)
                ? BitmapDescriptor.hueOrange
                : BitmapDescriptor.hueAzure;
            activeJobs['pickup_$jobId'] = _createJobMarker(
              'pickup_$jobId',
              pickLat,
              pickLng,
              hue,
              j,
            );

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

        // 3. Process Heatmap (Background Circles)
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
          ),
        );

        // 4. Listen to SignalR Stream
        _locationSub ??= signalRClient.onDriverLocationUpdate.listen((data) {
          add(
            UpdateDriverLocation(
              data['DriverId']?.toString() ?? '',
              _extractCoord(data, 'Latitude', 'lat'),
              _extractCoord(data, 'Longitude', 'lng'),
              data['IsOnJob'] ?? false,
            ),
          );
        });
      } catch (e) {
        emit(
          state.copyWith(
            isLoading: false,
            error: 'Failed to sync radar telemetry.',
          ),
        );
      }
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
        await Future.delayed(const Duration(seconds: 2));
        emit(state.copyWith(clearMessages: true));
      } catch (e) {
        emit(
          state.copyWith(
            error: 'Failed to reach driver device.',
            clearMessages: false,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        emit(state.copyWith(clearMessages: true));
      }
    });

    on<UpdateDriverLocation>((event, emit) {
      if (event.driverId.isEmpty) return;

      final updatedOnlineMarkers = Map<String, Marker>.from(
        state.onlineDriverMarkers,
      );
      final updatedOfflineMarkers = Map<String, Marker>.from(
        state.offlineDriverMarkers,
      );
      final updatedHeatmaps = Map<String, Circle>.from(
        state.driverHeatmapCircles,
      );

      final Map<String, dynamic> existingData = {};

      final newMarker = _createDriverMarker(
        event.driverId,
        event.lat,
        event.lng,
        true, // SignalR implies they are online
        event.isOnJob,
        false,
        existingData,
      );

      // Move marker to online if it was offline
      updatedOfflineMarkers.remove(event.driverId);
      updatedOnlineMarkers[event.driverId] = newMarker;

      updatedHeatmaps['heat_drv_${event.driverId}'] =
          _createDriverHeatmapCircle(event.driverId, event.lat, event.lng);

      emit(
        state.copyWith(
          onlineDriverMarkers: updatedOnlineMarkers,
          offlineDriverMarkers: updatedOfflineMarkers,
          driverHeatmapCircles: updatedHeatmaps,
        ),
      );
    });

    on<SelectJobIndicator>((event, emit) {
      if (event.jobData == null) {
        emit(state.copyWith(clearSelectedJob: true));
      } else {
        emit(
          state.copyWith(selectedJob: event.jobData, clearSelectedDriver: true),
        );
      }
    });

    on<SelectDriverIndicator>((event, emit) {
      if (event.driverData == null) {
        emit(state.copyWith(clearSelectedDriver: true));
      } else {
        emit(
          state.copyWith(
            selectedDriver: event.driverData,
            clearSelectedJob: true,
          ),
        );
      }
    });
  }

  // --- UI GENERATORS & EXTRACTORS ---

  double _extractCoord(Map<String, dynamic> json, String key1, String key2) {
    var val = json[key1] ?? json[key2];
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  Future<void> _cacheTruckIcons() async {
    if (_greenTruck != null) return;
    try {
      _greenTruck = await _createCustomTruckIcon(Colors.green.shade700);
      _redTruck = await _createCustomTruckIcon(Colors.red.shade700);
      _orangeTruck = await _createCustomTruckIcon(Colors.orange.shade700);
      _greyTruck = await _createCustomTruckIcon(
        Colors.grey.shade600,
      ); // Offline Color
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
    }
  }

  Future<BitmapDescriptor> _createCustomTruckIcon(Color bgColor) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 110.0;

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, borderPaint);

    final Paint bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      (size / 2) - 6,
      bgPaint,
    );

    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.local_shipping.codePoint),
      style: TextStyle(
        fontSize: size * 0.55,
        fontFamily: Icons.local_shipping.fontFamily,
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
    BitmapDescriptor icon;
    if (!isOnline) {
      icon = _greyTruck!;
    } else if (isOnJob) {
      icon = _redTruck!;
    } else if (isIdle) {
      icon = _orangeTruck!;
    } else {
      icon = _greenTruck!;
    }

    return Marker(
      markerId: MarkerId('driver_$id'),
      position: LatLng(lat, lng),
      zIndex: isOnline ? 5 : 2, // Push offline markers below active ones
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
    double hue,
    Map<String, dynamic> rawData,
  ) {
    return Marker(
      markerId: MarkerId(id),
      position: LatLng(lat, lng),
      zIndex: 4,
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
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
    _locationSub?.cancel();
    return super.close();
  }
}

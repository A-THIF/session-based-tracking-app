import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Use latlong2, not latlong
import 'package:ably_flutter/ably_flutter.dart' as ably;

// Hide LatLng from Google Maps to avoid conflicts
import '../models/location_payload.dart';
import '../services/ably_service.dart';
import '../services/api_service.dart';
import '../widgets/compass_hud_widget.dart';
import '../widgets/stats_bottom_card_widget.dart';
import '../widgets/tracking_header_widget.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String sessionCode;
  final bool isHost;

  const TrackingScreen({
    Key? key,
    required this.sessionCode,
    required this.isHost,
  }) : super(key: key);

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  // OSM Map State
  final MapController _mapController = MapController();
  List<LatLng> _polylineCoordinates = [];

  // Real-time State
  late AblyService _ablyService;
  final ApiService _apiService = ApiService();
  StreamSubscription<Position>? _locationSubscription;
  DateTime _lastPacketTime = DateTime.fromMillisecondsSinceEpoch(0);

  Position? _myCurrentPos;
  LatLng? _trackedUserPosition;
  bool _isCompassHudActive = false;
  double _distanceInMeters = 0;
  double _targetBearing = 0;

  // UI State
  String _trackedName = 'Liam';
  String _distance = '0m';
  String _eta = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _ablyService = ref.read(ablyServiceProvider);
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    try {
      final details = await _apiService.getSessionDetails(widget.sessionCode);
      final List<dynamic> path = details['path'] ?? [];

      if (path.isNotEmpty) {
        setState(() {
          _polylineCoordinates = path
              .map((coords) => LatLng(coords['latitude'], coords['longitude']))
              .toList();
        });
      }

      final String deviceId = await _apiService.getDeviceId();

      if (widget.isHost) {
        _startLocationTracking(deviceId: deviceId, publish: true);
      } else {
        _startLocationTracking();
        _listenToLiveUpdates();
      }
    } catch (e) {
      debugPrint('Error starting tracking: $e');
    }
  }

  void _startLocationTracking({String? deviceId, bool publish = false}) {
    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings:  AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 10,
            intervalDuration: Duration(seconds: 5),
          ),
        ).listen((Position position) {
          _myCurrentPos = position;
          final myLatLng = LatLng(position.latitude, position.longitude);

          _refreshProximityState();

          if (publish && deviceId != null) {
            _ablyService.publishLocation(
              deviceId,
              position.latitude,
              position.longitude,
            );
          }

          setState(() {
            if (widget.isHost) {
              _polylineCoordinates.add(myLatLng);
            }
          });
          _mapController.move(myLatLng, _mapController.camera.zoom);
        });
  }

  void _listenToLiveUpdates() {
    _ablyService.getLocationStream().listen((ably.Message message) {
      if (message.data == null) return;

      try {
        final payload = LocationPayload.fromJson(
          Map<String, dynamic>.from(message.data as Map),
        );

        if (payload.timestamp.isAfter(_lastPacketTime)) {
          _lastPacketTime = payload.timestamp;

          setState(() {
            // Convert google_maps LatLng to latlong2 LatLng if models differ
            _trackedUserPosition = LatLng(
              payload.position.latitude,
              payload.position.longitude,
            );
            _polylineCoordinates.add(_trackedUserPosition!);
            _refreshProximityState();
          });

          _mapController.move(
            _trackedUserPosition!,
            _mapController.camera.zoom,
          );
        }
      } catch (e) {
        debugPrint("Payload Error: $e");
      }
    });
  }

  void _refreshProximityState() {
    if (_myCurrentPos == null || _trackedUserPosition == null) return;

    _distanceInMeters = Geolocator.distanceBetween(
      _myCurrentPos!.latitude,
      _myCurrentPos!.longitude,
      _trackedUserPosition!.latitude,
      _trackedUserPosition!.longitude,
    );

    _targetBearing = Geolocator.bearingBetween(
      _myCurrentPos!.latitude,
      _myCurrentPos!.longitude,
      _trackedUserPosition!.latitude,
      _trackedUserPosition!.longitude,
    );

    setState(() {
      _distance = _formatDistance(_distanceInMeters);
      _isCompassHudActive = _distanceInMeters < 20;
    });
  }

  String _formatDistance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(2)} km'
      : '${meters.toStringAsFixed(0)}m';

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. OPEN STREET MAP (OSM)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(13.0827, 80.2707),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.session_based_tracking_app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _polylineCoordinates,
                    color: const Color(0xFF5AB9EA),
                    strokeWidth: 4,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (_myCurrentPos != null)
                    Marker(
                      point: LatLng(
                        _myCurrentPos!.latitude,
                        _myCurrentPos!.longitude,
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.green,
                        size: 30,
                      ),
                    ),
                  if (_trackedUserPosition != null)
                    Marker(
                      point: _trackedUserPosition!,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // UI Overlays (Header, Stats, Compass)
          Align(
            alignment: Alignment.topCenter,
            child: TrackingHeaderWidget(
              trackedName: _trackedName,
              distance: _distance,
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: StatsBottomCardWidget(distance: _distance, eta: _eta),
            ),
          ),

          AnimatedSlide(
            duration: const Duration(milliseconds: 350),
            offset: _isCompassHudActive ? Offset.zero : const Offset(0, 1),
            child: CompassHudWidget(
              distance: _distanceInMeters,
              trackedName: _trackedName,
              targetBearing: _targetBearing,
              onBackToMap: () => setState(() => _isCompassHudActive = false),
            ),
          ),
        ],
      ),
    );
  }
}

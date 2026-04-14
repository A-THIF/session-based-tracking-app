import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ably_flutter/ably_flutter.dart' as ably;

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
  // Map State
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
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

  static const double _compassHudTriggerDistance = 20;

  // UI State (Matching Mockup)
  String _trackedName = 'Liam'; // Example
  String _distance = '0m';
  String _eta = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _ablyService = ref.read(ablyServiceProvider);

    // 1. Initial Map Setup (Sync previous data + start live)
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    try {
      if (!mounted) return;

      // 2. Pro Feature: Fetch Path History from Render Backend (for polylines)
      // This solves the problem: User B joins, they see the line User A already walked.
      final details = await _apiService.getSessionDetails(widget.sessionCode);
      final List<dynamic> path = details['path'];

      if (path.isNotEmpty) {
        _polylineCoordinates = path
            .map((coords) => LatLng(coords['latitude'], coords['longitude']))
            .toList();
        _drawPolyline(_polylineCoordinates);
      }

      // 3. User A Logic (The Publisher)
      if (widget.isHost) {
        // We will pass 'RedmiNote13Athif' as deviceId for now
        _startLocationTracking(deviceId: 'RedmiNote13Athif', publish: true);
      }

      // 4. User B Logic (The Subscriber)
      if (!widget.isHost) {
        _startLocationTracking();
        // User B listens to the live stream
        _listenToLiveUpdates();
      }
    } catch (e) {
      debugPrint('Error starting tracking: $e');
    }
  }

  // --- Logic for User A (Host) ---
  void _startLocationTracking({String? deviceId, bool publish = false}) {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10,
    ); // Update every 10m

    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          _myCurrentPos = position;
          _refreshProximityState();

          if (publish && deviceId != null) {
            // 5. This publishes to Ably (fast) which triggers the Render Webhook (saves to DB)
            _ablyService.publishLocation(
              deviceId,
              position.latitude,
              position.longitude,
            );
          }

          // Also update my own UI
          _updateUserAMarker(position);
        });
  }

  // --- Logic for User B (Follower) ---
  void _listenToLiveUpdates() {
    // 6. Listen directly to the Ably channel for incoming location updates.
    _ablyService.getLocationStream().listen((ably.Message message) {
      // Ably sends { "items": [ { "channel": ..., "message": { "data": {lat, lng, deviceId} } } ] }
      final LocationPayload payload = LocationPayload.fromJson(
        message.data as Map<String, dynamic>,
      );

      // 7. Solving Packet Flooding: Ignore Old Packets!
      if (payload.timestamp.isBefore(_lastPacketTime)) {
        return; // Laggy packet arrived late. Ignore it to prevent marker jumping.
      }
      _lastPacketTime = payload.timestamp;

      // Update Map
      _trackedUserPosition = payload.position;
      _polylineCoordinates.add(payload.position);
      _updateMarkerPosition(payload);
      _drawPolyline(_polylineCoordinates);
      _refreshProximityState();

      // Update UI Stats (Will implement real distance calc later)
      setState(() {
        _distance = _formatDistance(_distanceInMeters);
        _eta = '2 MIN';
      });
    });
  }

  void _refreshProximityState() {
    if (_myCurrentPos == null || _trackedUserPosition == null) {
      return;
    }

    final wasCompassHudActive = _isCompassHudActive;
    final distanceInMeters = Geolocator.distanceBetween(
      _myCurrentPos!.latitude,
      _myCurrentPos!.longitude,
      _trackedUserPosition!.latitude,
      _trackedUserPosition!.longitude,
    );

    final bearing = Geolocator.bearingBetween(
      _myCurrentPos!.latitude,
      _myCurrentPos!.longitude,
      _trackedUserPosition!.latitude,
      _trackedUserPosition!.longitude,
    );

    final shouldActivateHud = distanceInMeters < _compassHudTriggerDistance;

    if (mounted) {
      setState(() {
        _distanceInMeters = distanceInMeters;
        _targetBearing = bearing;
        _distance = _formatDistance(distanceInMeters);
        _isCompassHudActive = shouldActivateHud;
      });
    }

    if (shouldActivateHud && !wasCompassHudActive) {
      _triggerHapticFeedback();
    }
  }

  Future<void> _triggerHapticFeedback() async {
    await HapticFeedback.lightImpact();
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceInMeters.toStringAsFixed(0)}m';
  }

  // --- Map Utilities ---
  void _updateUserAMarker(Position pos) {
    final latlng = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('host'),
          position: latlng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    });
    _moveCamera(latlng);
  }

  void _updateMarkerPosition(LocationPayload payload) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(payload.deviceId),
          position: payload.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
    _moveCamera(payload.position);
  }

  void _drawPolyline(List<LatLng> coords) {
    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('path'),
          points: coords,
          color: const Color(0xFF5AB9EA),
          width: 5,
          patterns: [PatternItem.dot],
        ),
      );
    });
  }

  Future<void> _moveCamera(LatLng pos) async {
    final GoogleMapController mapController = await _controller.future;
    mapController.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 16)),
    );
  }

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
          // 1. Google Map (Widget call for cleaner code)
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: const CameraPosition(
              target: LatLng(13.0827, 80.2707),
              zoom: 12,
            ), // Initial view over Chennai
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Using custom button from mockup
            onMapCreated: (GoogleMapController controller) =>
                _controller.complete(controller),
          ),

          // 2. Tracking Header (White Bar - Widget Call)
          Align(
            alignment: Alignment.topCenter,
            child: TrackingHeaderWidget(
              trackedName: _trackedName,
              distance: _distance,
            ),
          ),

          // 3. Custom Compass (Image 2 mockup)
          Positioned(
            top: 100,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Column(
                children: [
                  Text(
                    'N',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.navigation, color: Colors.grey),
                ],
              ),
            ),
          ),

          // 4. Custom Location Button (Image 2 mockup)
          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () {}, // Center on tracked user
              child: const Icon(Icons.gps_fixed, color: Colors.blueAccent),
            ),
          ),

          // 5. Distance and ETA Card (Bottom Card - Widget Call)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: StatsBottomCardWidget(distance: _distance, eta: _eta),
            ),
          ),

          AnimatedSlide(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            offset: _isCompassHudActive ? Offset.zero : const Offset(0, 1),
            child: IgnorePointer(
              ignoring: !_isCompassHudActive,
              child: CompassHudWidget(
                distance: _distanceInMeters,
                trackedName: _trackedName,
                targetBearing: _targetBearing,
                onBackToMap: () {
                  setState(() {
                    _isCompassHudActive = false;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ably_flutter/ably_flutter.dart' as ably;

import '../services/ably_service.dart';
import '../services/api_service.dart';
import '../widgets/proximity_info_widget.dart';
import '../widgets/tracking_header_widget.dart';

// International Error/Packet Constants
const int _kPacketTimeoutMs = 7000;

class TrackingScreen extends ConsumerStatefulWidget {
  final String sessionCode;
  final bool isHost;
  final String myName;
  final String? peerName;

  const TrackingScreen({
    super.key,
    required this.sessionCode,
    required this.isHost,
    this.myName = 'You',
    this.peerName,
  });

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _myPath = [];
  final List<LatLng> _peerPath = [];

  late final AblyService _ablyService;
  final ApiService _apiService = ApiService();

  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<ably.Message>? _ablySub;
  Timer? _watchdog;

  Position? _myPosition;
  LatLng? _peerPosition;
  String? _myDeviceId;

  String _distanceLabel = '—';
  String _etaLabel = '—';
  String _resolvedPeerName = 'Peer';

  DateTime _lastPeerPacket = DateTime.fromMillisecondsSinceEpoch(0);
  bool _peerTimeout = false;

  @override
  void initState() {
    super.initState();
    _ablyService = ref.read(ablyServiceProvider);
    _resolvedPeerName = widget.peerName ?? (widget.isHost ? 'Guest' : 'Host');
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    try {
      _myDeviceId = await _apiService.getDeviceId();

      // 1. Fetch History from DB (Breadcrumbs)
      final details = await _apiService.getSessionDetails(widget.sessionCode);
      final List<dynamic> path = details['path'] ?? [];
      if (path.isNotEmpty) {
        setState(() {
          _myPath.addAll(
            path.map(
              (c) => LatLng(
                (c['latitude'] as num).toDouble(),
                (c['longitude'] as num).toDouble(),
              ),
            ),
          );
        });
      }

      // 2. Start Bidirectional Streams
      _startGpsPublisher();
      _startPeerListener();
      _startWatchdog();
    } catch (e) {
      debugPrint('[Tracking] Initialization Failed: $e');
    }
  }

  void _startGpsPublisher() {
    _gpsSub =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.best,
            intervalDuration: Duration(seconds: 3),
            distanceFilter: 0,
          ),
        ).listen((Position pos) {
          _myPosition = pos;
          final me = LatLng(pos.latitude, pos.longitude);

          if (_myDeviceId != null) {
            _ablyService.publishLocation(
              _myDeviceId!,
              pos.latitude,
              pos.longitude,
            );
          }

          setState(() => _myPath.add(me));

          // If we don't see the peer yet, just follow 'me'
          if (_peerPosition == null) {
            _mapController.move(me, _mapController.camera.zoom);
          } else {
            _fitBoth();
          }
          _recalcStats();
        });
  }

  void _startPeerListener() {
    _ablySub = _ablyService.getLocationStream().listen((msg) {
      if (msg.name != 'location_update' || msg.data == null) return;

      final raw = Map<String, dynamic>.from(msg.data as Map);
      final String senderId = (raw['deviceId'] ?? '').toString();

      // Filter out our own broadcast
      if (senderId == _myDeviceId) return;

      final peer = LatLng(
        (raw['lat'] as num).toDouble(),
        (raw['lng'] as num).toDouble(),
      );
      _lastPeerPacket = DateTime.now();

      setState(() {
        _peerPosition = peer;
        _peerPath.add(peer);
        _peerTimeout = false;
      });

      _fitBoth();
      _recalcStats();
    });
  }

  void _startWatchdog() {
    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _peerPosition == null) return;

      final age = DateTime.now().difference(_lastPeerPacket).inMilliseconds;
      if (age > _kPacketTimeoutMs && !_peerTimeout) {
        setState(() => _peerTimeout = true);

        // Structured Error Logging
        debugPrint(
          '{"type":"location-timeout", "session":"${widget.sessionCode}", "ageMs":$age}',
        );
      }
    });
  }

  void _fitBoth() {
    if (_myPosition == null || _peerPosition == null) return;
    final bounds = LatLngBounds.fromPoints([
      LatLng(_myPosition!.latitude, _myPosition!.longitude),
      _peerPosition!,
    ]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(70)),
    );
  }

  void _recalcStats() {
    if (_myPosition == null || _peerPosition == null) return;

    final dist = Geolocator.distanceBetween(
      _myPosition!.latitude,
      _myPosition!.longitude,
      _peerPosition!.latitude,
      _peerPosition!.longitude,
    );

    final etaSec = (dist / 1.4).round(); // Avg walking speed 1.4m/s

    setState(() {
      _distanceLabel = dist >= 1000
          ? '${(dist / 1000).toStringAsFixed(2)} km'
          : '${dist.toStringAsFixed(0)} m';
      _etaLabel = etaSec > 60
          ? '${etaSec ~/ 60}m ${etaSec % 60}s'
          : '${etaSec}s';
    });
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _ablySub?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(13.0827, 80.2707),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.session_based_tracking_app',
              ),
              // Path Visuals
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _myPath,
                    color: const Color(0xFF4ECDC4),
                    strokeWidth: 4,
                  ),
                  Polyline(
                    points: _peerPath,
                    color: const Color(0xFFFF8C42),
                    strokeWidth: 4,
                  ),
                ],
              ),
              // Markers
              MarkerLayer(
                markers: [
                  if (_myPosition != null)
                    _buildUserMarker(
                      LatLng(_myPosition!.latitude, _myPosition!.longitude),
                      widget.myName,
                      const Color(0xFF4ECDC4),
                      Icons.navigation,
                    ),
                  if (_peerPosition != null)
                    _buildUserMarker(
                      _peerPosition!,
                      _resolvedPeerName,
                      const Color(0xFFFF8C42),
                      Icons.person_pin,
                      isDimmed: _peerTimeout,
                    ),
                ],
              ),
            ],
          ),

          TrackingHeaderWidget(
            trackedName: _resolvedPeerName,
            distance: _distanceLabel,
          ),

          // Update this block in your TrackingScreen build method
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ProximityInfoWidget(
                distance: _distanceLabel,
                eta: _etaLabel,
                myName: widget.myName, // Changed from missing to widget.myName
                peerName:
                    _resolvedPeerName, // Changed from missing to _resolvedPeerName
                peerConnected:
                    !_peerTimeout, // Changed from isConnected to peerConnected
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildUserMarker(
    LatLng point,
    String label,
    Color color,
    IconData icon, {
    bool isDimmed = false,
  }) {
    return Marker(
      point: point,
      width: 60,
      height: 70,
      child: Opacity(
        opacity: isDimmed ? 0.5 : 1.0,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
            Icon(icon, color: color, size: 35),
          ],
        ),
      ),
    );
  }
}

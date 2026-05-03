import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:latlong2/latlong.dart';
import '../providers/session_provider.dart';
import '../providers/tracking_provider.dart';
import '../widgets/proximity_info_widget.dart';
import '../widgets/tracking_header_widget.dart';
import '../widgets/end_session_button.dart';
import '../widgets/recenter_fab.dart';
import '../widgets/route_polyline_widget.dart'; // Adjust name if needed

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();
  bool _backgroundStarted = false;
  bool _isAutoFollow = true;

  // Back-press double-tap state
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    Future.microtask(_maybeStartBackgroundService);
  }

  void _maybeStartBackgroundService() {
    final session = ref.read(sessionProvider);
    if (session.status == SessionStatus.tracking &&
        session.deviceId != null &&
        session.session != null &&
        !_backgroundStarted) {
      _backgroundStarted = true;
      FlutterBackgroundService().invoke('startTracking', {
        'sessionCode': session.session!.code,
        'deviceId': session.deviceId!,
      });
    }
  }

  void _fitCamera(TrackingData data) {
    if (!_isAutoFollow || !mounted) return;

    if (data.myPos != null && data.peerPos != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([data.myPos!, data.peerPos!]),
          padding: const EdgeInsets.only(
            top: 100,
            bottom: 280,
            left: 60,
            right: 60,
          ),
        ),
      );
    } else if (data.myPos != null) {
      _mapController.move(data.myPos!, _mapController.camera.zoom);
    }
  }

  // Double back-press to exit
  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Press back again to end the session',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return false;
    }
    // Second press — end session and go home
    ref.read(sessionProvider.notifier).cancelSession();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final trackingAsync = ref.watch(liveTrackingProvider);

    final myName = session.deviceId ?? 'You';
    final peerName = session.presentMembers.isNotEmpty
        ? session.presentMembers.first
        : 'Peer';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: trackingAsync.when(
        loading: () => const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                SizedBox(height: 16),
                Text(
                  'Acquiring GPS…',
                  style: TextStyle(color: Color(0xFF7A9BC0), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Tracking error:\n$err',
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        data: (data) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera(data));

          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            // No floatingActionButton here — we position it manually
            body: Stack(
              children: [
                // ── Map ────────────────────────────────────────────────
                // Make sure to import your new widget at the top
// import '../widgets/route_line_widget.dart';

FlutterMap(
  mapController: _mapController,
  options: MapOptions(
    initialCenter: data.myPos ?? const LatLng(13.0827, 80.2707),
    initialZoom: 16,
    onPositionChanged: (position, hasGesture) {
      if (hasGesture && _isAutoFollow) {
        setState(() => _isAutoFollow = false);
      }
    },
  ),
  children: [
    // 1. Base Map Tiles
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.session_based_tracking_app',
    ),

    // 2. The Road Path (New Widget)
    RouteLineWidget(routePoints: data.routePoints),

    // 3. User Markers
    MarkerLayer(
      markers: [
        if (data.myPos != null)
          Marker(
            point: data.myPos!,
            width: 44,
            height: 44,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF4ECDC4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: Color(0xFF4ECDC4),
                size: 22,
              ),
            ),
          ),
        if (data.peerPos != null)
          Marker(
            point: data.peerPos!,
            width: 44,
            height: 44,
            child: Container(
              decoration: BoxDecoration(
                color: data.isPeerTimeout
                    ? Colors.redAccent.withValues(alpha: 0.15)
                    : const Color(0xFFFF8C42).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: data.isPeerTimeout
                      ? Colors.redAccent
                      : const Color(0xFFFF8C42),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.person_pin_circle_rounded,
                color: data.isPeerTimeout
                    ? Colors.redAccent
                    : const Color(0xFFFF8C42),
                size: 22,
              ),
            ),
          ),
      ],
    ),
  ],
),

                // ── Header with End Session button ─────────────────────
                Positioned(
                  top: 0,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TrackingHeaderWidget(
                            trackedName: peerName,
                            distance: data.distanceLabel,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const EndSessionButton(),
                      ],
                    ),
                  ),
                ),

                // ── Waiting for peer overlay ────────────────────────────
                if (data.peerPos == null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1E293B,
                            ).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFF4ECDC4,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF4ECDC4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Waiting for $peerName signal…',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF7A9BC0),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Recenter FAB above proximity card ──────────────────
                if (!_isAutoFollow)
                  Positioned(
                    bottom: 210,
                    right: 16,
                    child: RecenterFab(
                      onTap: () {
                        setState(() => _isAutoFollow = true);
                        _fitCamera(data);
                      },
                    ),
                  ),

                // ── Proximity card ─────────────────────────────────────
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: ProximityInfoWidget(
                    distance: data.distanceLabel,
                    eta: data.etaLabel,
                    myName: myName,
                    peerName: peerName,
                    peerConnected: !data.isPeerTimeout,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

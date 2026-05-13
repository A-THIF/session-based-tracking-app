import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../providers/session_provider.dart';
import '../providers/tracking_provider.dart';
import '../widgets/tracking/map_view_widget.dart';
import '../widgets/proximity_info_widget.dart';
import 'spotlight_screen.dart';
import '../config/constants.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});
  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();
  bool _backgroundStarted = false;
  bool _isAutoFollow = true;
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
        'backendUrl': AppConfig.baseUrl, // 🟢 Use the actual config
      });
    }
  }

  void _fitCamera(TrackingData data) {
    if (!_isAutoFollow ||
        !mounted ||
        data.myPos == null ||
        data.peerPos == null)
      return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([data.myPos!, data.peerPos!]),
        padding: const EdgeInsets.only(
          top: 120,
          bottom: 300,
          left: 60,
          right: 60,
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Press back again to exit')));
      return false;
    }
    ref.read(sessionProvider.notifier).cancelSession();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final trackingAsync = ref.watch(liveTrackingProvider);
    final peerName = session.presentMembers.isNotEmpty
        ? session.presentMembers.first
        : 'Peer';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.of(context).pop();
      },
      child: trackingAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
        data: (data) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera(data));

          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Stack(
              children: [
                // 1. MAP
                MapViewWidget(
                  mapController: _mapController,
                  myPos: data.myPos,
                  peerPos: data.peerPos,
                  myHeading: data.myHeading,
                  peerHeading: data.peerHeading,
                  mySpeedKmh: data.mySpeedKmh,
                  peerSpeedKmh: data.peerSpeedKmh,
                  routePoints: data.routePoints,
                  peerTimeout: data.isPeerTimeout,
                  myUsername: session.username ?? 'Me',
                  peerName: peerName,
                  onGesture: () => setState(() => _isAutoFollow = false),
                ),

                // 2. PROXIMITY CARD
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 28,
                  child: ProximityInfoWidget(
                    distance: '${data.roadDistance.toStringAsFixed(0)} m',
                    eta: data.etaLabel,
                    myName: session.username ?? 'Me',
                    peerName: peerName,
                    mySpeed: data.mySpeedKmh,
                    peerSpeed: data.peerSpeedKmh,
                    peerConnected: !data.isPeerTimeout,
                    isSpotlightActive:
                        data.isSpotlightActive, // 🟢 From Provider
                    onSpotlightToggle: () async {
                      // Trigger Ably via Provider
                      ref.read(liveTrackingProvider.notifier).toggleSpotlight();

                      if (!context.mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SpotlightScreen(
                            color: const Color(0xFF4ECDC4),
                            username: session.username ?? 'Me',
                            distanceMeters: data.roadDistance,
                            isSelf: true,
                            onCancel: () {
                              ref
                                  .read(liveTrackingProvider.notifier)
                                  .toggleSpotlight();
                              Navigator.pop(context);
                            },
                            onFoundYou: () {},
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 3. WAITING UI
                if (data.peerPos == null)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFF4ECDC4,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'Waiting for $peerName signal...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 4. PEER SPOTLIGHT OVERLAY (The orange pulse when Naf finds you)
                if (data.isPeerSpotlighting)
                  Positioned.fill(
                    child: SpotlightScreen(
                      username: peerName,
                      color: const Color(0xFFFF8C42),
                      distanceMeters: data.roadDistance,
                      isSelf: false,
                      onCancel: () {},
                      onFoundYou: () => ref
                          .read(liveTrackingProvider.notifier)
                          .dismissPeerSpotlight(),
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

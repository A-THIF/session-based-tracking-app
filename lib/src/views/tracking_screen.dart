import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../providers/session_provider.dart';
import '../providers/tracking_provider.dart';
import '../providers/map_navigation_provider.dart';
import '../widgets/tracking/map_view_widget.dart';
import '../widgets/proximity_info_widget.dart';
import '../widgets/recenter_fab.dart';
import '../widgets/end_session_button.dart';
import '../widgets/leave_session_button.dart';
import '../theme/trace_colors.dart';
import '../theme/trace_typography.dart';
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
    final isOverview =
        ref.read(mapNavigationProvider).cameraMode == CameraMode.overview;
    if (!isOverview || !mounted || data.myPos == null || data.peerPos == null) {
      return;
    }
    final points = [data.myPos!, data.peerPos!, ...data.routePoints];
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.only(
          top: 80,
          bottom: 150,
          left: 40,
          right: 40,
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
    // Guest intercept: host killed the session remotely.
    ref.listen<SessionState>(sessionProvider, (_, next) {
      if (next.status == SessionStatus.terminated && mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Session Ended',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            content: const Text(
              'The host has ended this tracking session.',
              style: TextStyle(color: Color(0xFF7A9BC0), fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx); // dismiss dialog first
                  await ref.read(sessionProvider.notifier).cancelSession();
                  if (context.mounted) {
                    ref.invalidate(liveTrackingProvider);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: const Text(
                  'OK',
                  style: TextStyle(color: TraceColors.neonTeal),
                ),
              ),
            ],
          ),
        );
      }
    });
    // Host intercept: a peer has left the session.
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (!next.isHost) return;
      final prev = previous?.presentMembers ?? [];
      final curr = next.presentMembers;
      if (curr.length < prev.length && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A guest has left the session.'),
            backgroundColor: Color(0xFF1E293B),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
    // Task 13: one-shot low battery snackbar.
    ref.listen<AsyncValue<TrackingData>>(liveTrackingProvider, (_, next) {
      final data = next.valueOrNull;
      if (data == null || !data.showBatteryWarning || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Low battery: Location updates slowed to conserve power.',
          ),
          backgroundColor: Color(0xFF1E293B),
          duration: Duration(seconds: 5),
        ),
      );
      // Clear the flag immediately so it only fires once.
      ref
          .read(liveTrackingProvider.notifier)
          .clearBatteryWarning();
    });
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
                  isGpsLost: data.isGpsLost,
                  myUsername: session.username ?? 'Me',
                  peerName: peerName,
                  onGesture: () => ref
                      .read(mapNavigationProvider.notifier)
                      .resetToOverview(),
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
                // 3. ROUTE LOADING OVERLAY — Positioned.fill keeps it below FABs
                // IgnorePointer stops it eating touches once route arrives.
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: data.routePoints.isEmpty ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: data.routePoints.isNotEmpty,
                      child: Container(
                        color: Colors.black87,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: TraceColors.neonTeal,
                                strokeWidth: 2.5,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Calculating route...',
                                style: TraceTypography.bodyMedium.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 4. RECENTER FAB — always above overlay
                const Positioned(
                  top: 52,
                  right: 16,
                  child: RecenterFab(),
                ),
                // 5. ROLE-BASED SESSION BUTTON — always above overlay
                Positioned(
                  top: 52,
                  left: 16,
                  child: session.isHost
                      ? const EndSessionButton()
                      : const LeaveSessionButton(),
                ),
                // 6. WAITING UI
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
                // 7. PEER SPOTLIGHT OVERLAY
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

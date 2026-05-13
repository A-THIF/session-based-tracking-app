import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'navigation_pointer.dart';
import '../route_polyline_widget.dart';
import '../../providers/map_navigation_provider.dart';
import '../../providers/tracking_provider.dart';

// ── LatLng interpolation ──────────────────────────────────────────────────────

class LatLngTween extends Tween<LatLng> {
  LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) => LatLng(
    begin!.latitude + (end!.latitude - begin!.latitude) * t,
    begin!.longitude + (end!.longitude - begin!.longitude) * t,
  );
}

// ── Per-marker animation state ────────────────────────────────────────────────

class _MarkerAnimState {
  final AnimationController controller;
  late LatLngTween tween;
  late Animation<LatLng> animation;

  _MarkerAnimState({required TickerProvider vsync, required LatLng initial})
    : controller = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 900),
      ) {
    tween = LatLngTween(begin: initial, end: initial);
    animation = tween.animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );
  }

  void animateTo(LatLng target) {
    final currentPos = animation.value;
    tween = LatLngTween(begin: currentPos, end: target);
    animation = tween.animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );
    controller
      ..reset()
      ..forward();
  }

  void dispose() => controller.dispose();
}

// ── MapViewWidget ─────────────────────────────────────────────────────────────

class MapViewWidget extends ConsumerStatefulWidget {
  final MapController mapController;
  final LatLng? myPos;
  final LatLng? peerPos;
  final double myHeading;
  final double peerHeading;
  final double mySpeedKmh;
  final double peerSpeedKmh;
  final List<LatLng> routePoints;
  final bool peerTimeout;
  final String myUsername;
  final String peerName;
  final VoidCallback onGesture;

  const MapViewWidget({
    super.key,
    required this.mapController,
    required this.myPos,
    required this.peerPos,
    required this.myHeading,
    required this.peerHeading,
    this.mySpeedKmh = 0,
    this.peerSpeedKmh = 0,
    required this.routePoints,
    required this.peerTimeout,
    required this.myUsername,
    required this.peerName,
    required this.onGesture,
  });

  @override
  ConsumerState<MapViewWidget> createState() => _MapViewWidgetState();
}

class _MapViewWidgetState extends ConsumerState<MapViewWidget>
    with TickerProviderStateMixin {
  _MarkerAnimState? _myAnim;
  _MarkerAnimState? _peerAnim;

  LatLng? _lastMyPos;
  LatLng? _lastPeerPos;

  @override
  void didUpdateWidget(covariant MapViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.myPos != null) {
      if (_myAnim == null) {
        _myAnim = _MarkerAnimState(vsync: this, initial: widget.myPos!);
        _lastMyPos = widget.myPos;
      } else if (widget.myPos != _lastMyPos) {
        _myAnim!.animateTo(widget.myPos!);
        _lastMyPos = widget.myPos;
      }
    }

    if (widget.peerPos != null) {
      if (_peerAnim == null) {
        _peerAnim = _MarkerAnimState(vsync: this, initial: widget.peerPos!);
        _lastPeerPos = widget.peerPos;
      } else if (widget.peerPos != _lastPeerPos) {
        _peerAnim!.animateTo(widget.peerPos!);
        _lastPeerPos = widget.peerPos;
      }
    }
  }

  @override
  void dispose() {
    _myAnim?.dispose();
    _peerAnim?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Watch navigation state (Rotation/Tilt/Zoom)
    final nav = ref.watch(mapNavigationProvider);

    // 2. Sync speed updates back to the navigation provider
    ref.listen(liveTrackingProvider, (prev, next) {
      final speed = next.valueOrNull?.mySpeedKmh ?? 0.0;
      ref.read(mapNavigationProvider.notifier).updateFromSpeed(speed);
    });

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -1,
        0,
        0,
        0,
        255,
        0,
        -1,
        0,
        0,
        255,
        0,
        0,
        -1,
        0,
        255,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: FlutterMap(
        mapController: widget.mapController,
        options: MapOptions(
          initialCenter: widget.myPos ?? const LatLng(13.0827, 80.2707),
          initialZoom: 17,
          initialRotation: nav.rotation,
          onPositionChanged: (_, hasGesture) {
            if (hasGesture) widget.onGesture();
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.trace.app',
          ),
          RouteLineWidget(routePoints: widget.routePoints),

          // 🟢 Camera Controller: Applies rotation and focal point padding
          Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (nav.isHeadingUp && widget.myPos != null) {
                  // Move map camera to rotation angle
                  widget.mapController.rotate(nav.rotation);

                  // Shift focal point to bottom third
                  widget.mapController.move(
                    widget.myPos!,
                    nav.zoom,
                    offset: const Offset(0, 180), // Anchor at bottom-third
                  );
                } else if (!nav.isHeadingUp && nav.rotation == 0) {
                  // Reset to North-Up center if stopped
                  widget.mapController.rotate(0);
                }
              });
              return const SizedBox.shrink();
            },
          ),

          AnimatedBuilder(
            animation: Listenable.merge([
              if (_myAnim != null) _myAnim!.controller,
              if (_peerAnim != null) _peerAnim!.controller,
            ]),
            builder: (context, _) {
              return MarkerLayer(
                markers: [
                  if (_myAnim != null)
                    _buildMarker(
                      pos: _myAnim!.animation.value,
                      type: PuckType.self,
                      label: widget.myUsername,
                      // 🟢 FIXED: If map is rotating, arrow stays fixed at 0 (Up)
                      heading: nav.isHeadingUp ? 0 : widget.myHeading,
                      speedKmh: widget.mySpeedKmh,
                      isTimeout: false,
                    ),
                  if (_peerAnim != null)
                    _buildMarker(
                      pos: _peerAnim!.animation.value,
                      type: PuckType.peer,
                      label: widget.peerName,
                      // Peer marker still rotates normally relative to North
                      heading: widget.peerHeading,
                      speedKmh: widget.peerSpeedKmh,
                      isTimeout: widget.peerTimeout,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Marker _buildMarker({
    required LatLng pos,
    required PuckType type,
    required String label,
    required double heading,
    required double speedKmh,
    required bool isTimeout,
  }) {
    final height = type == PuckType.peer ? 100.0 : 80.0;
    return Marker(
      point: pos,
      width: 80,
      height: height,
      rotate: false, // We handle rotation inside the widget for better control
      alignment: type == PuckType.peer
          ? const Alignment(0, 0.85)
          : Alignment.center,
      child: NavigationPuck(
        type: type,
        label: label,
        bearing: heading,
        isTimeout: isTimeout,
        speedKmh: speedKmh,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

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

class MarkerAnimState {
  final AnimationController controller;
  late LatLngTween tween;
  late Animation<LatLng> animation;

  MarkerAnimState({required TickerProvider vsync, required LatLng initial})
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

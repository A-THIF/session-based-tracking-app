import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/map_navigation_provider.dart';
import '../theme/trace_colors.dart';

/// Floating action button that reflects the current [CameraMode].
///
/// - [CameraMode.overview] → crosshair icon  (fit both users)
/// - [CameraMode.guided]   → compass icon    (lock to self, heading-up)
///
/// Tapping calls [toggleCameraMode] on the provider.
/// The map view calls [resetToOverview] directly when it detects a user drag.
class RecenterFab extends ConsumerWidget {
  const RecenterFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(mapNavigationProvider.select((s) => s.cameraMode));
    final isGuided = mode == CameraMode.guided;

    return GestureDetector(
      onTap: () => ref.read(mapNavigationProvider.notifier).toggleCameraMode(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isGuided
              ? TraceColors.neonTeal.withValues(alpha: 0.15)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: TraceColors.neonTeal.withValues(
              alpha: isGuided ? 0.9 : 0.4,
            ),
            width: isGuided ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isGuided
                  ? TraceColors.neonTeal.withValues(alpha: 0.25)
                  : Colors.black38,
              blurRadius: isGuided ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isGuided ? Icons.explore_rounded : Icons.filter_center_focus_rounded,
          color: TraceColors.neonTeal,
          size: 22,
        ),
      ),
    );
  }
}

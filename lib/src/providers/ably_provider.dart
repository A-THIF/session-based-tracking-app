import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ably_service.dart';

// 1. Existing Provider
final ablyServiceProvider = Provider<AblyService>((ref) {
  final service = AblyService();
  ref.onDispose(() => service.dispose());
  return service;
});

// 2. NEW: A Simple State Provider to track initialization
final ablyReadyProvider = StateProvider.family<bool, String>((ref, sessionCode) => false);

// 3. Updated Stream Provider
final locationStreamProvider = StreamProvider.family<ably.Message, String>((ref, sessionCode) {
  final ablyService = ref.watch(ablyServiceProvider);
  final isReady = ref.watch(ablyReadyProvider(sessionCode));

  if (!isReady) {
    return const Stream.empty();
  }

  return ablyService.getLocationStream();
});
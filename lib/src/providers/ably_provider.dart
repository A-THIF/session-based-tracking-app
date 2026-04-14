import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ably_service.dart';

final ablyServiceProvider = Provider<AblyService>((ref) => AblyService());

final locationStreamProvider = StreamProvider.family<ably.Message, String>((
  ref,
  sessionCode,
) {
  final ablyService = ref.watch(ablyServiceProvider);
  return ablyService.getLocationStream();
});


import 'package:flutter_riverpod/flutter_riverpod.dart';

final ablyServiceProvider = Provider<AblyService>((ref) {
  return AblyService();
});
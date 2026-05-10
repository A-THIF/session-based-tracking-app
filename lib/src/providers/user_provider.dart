import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserNotifier extends AsyncNotifier<UserProfile?> {
  final UserService _service = UserService();

  @override
  Future<UserProfile?> build() async {
    return await _service.getUserProfile();
  }

  Future<List<String>> fetchSuggestions() async {
    return await _service.fetchUsernameSuggestions();
  }

  Future<bool> claimIdentity(String username) async {
    try {
      final profile = await _service.claimIdentity(username);
      state = AsyncData(profile);
      return true;
    } catch (e) {
      if (e.toString().contains('USERNAME_TAKEN')) {
        throw Exception('USERNAME_TAKEN');
      }
      throw Exception('CLAIM_FAILED');
    }
  }

  Future<void> sendPulse() async {
    await _service.sendPulse();
  }
}

final userProvider = AsyncNotifierProvider<UserNotifier, UserProfile?>(
  UserNotifier.new,
);

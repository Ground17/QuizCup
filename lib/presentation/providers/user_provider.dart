import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile.dart';
import 'project_provider.dart';

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile>(() {
  return UserProfileNotifier();
});

class UserProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    return _fetchOrCreateProfile();
  }

  Future<UserProfile> _fetchOrCreateProfile() async {
    final db = ref.read(databaseServiceProvider);
    final profile = await db.getUserProfile();

    if (profile == null) {
      final defaultProfile = UserProfile.defaultProfile();
      await db.saveUserProfile(defaultProfile);
      return defaultProfile;
    }

    return profile;
  }

  Future<void> updateProfile({String? name, String? country}) async {
    final current = state.value;
    if (current == null) return;

    final updated = current.copyWith(
      name: name ?? current.name,
      country: country ?? current.country,
    );

    final db = ref.read(databaseServiceProvider);
    await db.saveUserProfile(updated);
    state = AsyncData(updated);
  }
}

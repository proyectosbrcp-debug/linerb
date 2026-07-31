import '../models/user_profile.dart';

abstract class AuthSessionStorage {
  Future<UserProfile?> loadLastValidProfile();

  Future<void> saveLastValidProfile(UserProfile profile);

  Future<void> clearLastValidProfile();
}

import '../models/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile?> findByUid(String uid);
}

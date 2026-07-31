import '../models/user_profile.dart';
import 'user_profile_repository.dart';

class UnavailableUserProfileRepository implements UserProfileRepository {
  const UnavailableUserProfileRepository();

  @override
  Future<UserProfile?> findByUid(String uid) async {
    return null;
  }
}

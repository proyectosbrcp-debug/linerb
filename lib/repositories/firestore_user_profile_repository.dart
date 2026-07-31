import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'user_profile_repository.dart';

class FirestoreUserProfileRepository implements UserProfileRepository {
  final FirebaseFirestore firestore;

  const FirestoreUserProfileRepository({required this.firestore});

  @override
  Future<UserProfile?> findByUid(String uid) async {
    final snapshot = await firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return UserProfile.fromFirestore(data);
  }
}

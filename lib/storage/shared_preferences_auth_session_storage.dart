import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'auth_session_storage.dart';

class SharedPreferencesAuthSessionStorage implements AuthSessionStorage {
  static const String lastValidProfileKey = 'linerb_auth_last_valid_profile';

  const SharedPreferencesAuthSessionStorage();

  @override
  Future<UserProfile?> loadLastValidProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(lastValidProfileKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return UserProfile.fromStorageJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveLastValidProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      lastValidProfileKey,
      jsonEncode(profile.toStorageJson()),
    );
  }

  @override
  Future<void> clearLastValidProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(lastValidProfileKey);
  }
}

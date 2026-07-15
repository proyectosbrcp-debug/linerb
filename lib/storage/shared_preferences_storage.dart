import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesStorage {
  const SharedPreferencesStorage();

  Future<SharedPreferences> instance() {
    return SharedPreferences.getInstance();
  }
}

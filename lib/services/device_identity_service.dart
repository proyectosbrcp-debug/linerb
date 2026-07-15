import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/stable_id.dart';

class DeviceIdentityService {
  static const String storageKey = 'linerb_device_id';

  final Future<SharedPreferences> Function()? preferencesProvider;
  final DateTime Function() clock;

  DeviceIdentityService({this.preferencesProvider, required this.clock});

  Future<String> deviceId() async {
    final prefs =
        await (preferencesProvider ?? SharedPreferences.getInstance)();
    final existing = prefs.getString(storageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = StableId.fromParts('device', [
      clock().toIso8601String(),
      DateTime.now().microsecondsSinceEpoch,
    ]);
    await prefs.setString(storageKey, generated);
    return generated;
  }
}

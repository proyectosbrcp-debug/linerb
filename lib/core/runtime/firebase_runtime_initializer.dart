import 'package:firebase_core/firebase_core.dart';

import '../logging/app_logger.dart';

class FirebaseRuntimeInitializer {
  const FirebaseRuntimeInitializer();

  Future<bool> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) return true;
      await Firebase.initializeApp();
      return true;
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Firebase no disponible; LINERB continúa en modo local',
        error,
        stackTrace,
      );
      return false;
    }
  }
}

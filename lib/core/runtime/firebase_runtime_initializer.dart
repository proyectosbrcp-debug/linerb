import 'package:firebase_core/firebase_core.dart';

import '../logging/app_logger.dart';
import 'firebase_emulator_configurator.dart';

class FirebaseRuntimeInitializer {
  const FirebaseRuntimeInitializer();

  Future<bool> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await const FirebaseEmulatorConfigurator().configure();
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

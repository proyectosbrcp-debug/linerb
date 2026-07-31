import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';

class FirebaseEmulatorConfigurator {
  static const bool useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );
  static const String configuredHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '',
  );
  static const int authPort = int.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );
  static const int firestorePort = int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );

  static bool _configured = false;

  const FirebaseEmulatorConfigurator();

  Future<void> configure({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) async {
    if (_configured || !useEmulators || kReleaseMode) return;

    final host = resolveHost();
    await (auth ?? FirebaseAuth.instance).useAuthEmulator(host, authPort);
    (firestore ?? FirebaseFirestore.instance).useFirestoreEmulator(
      host,
      firestorePort,
    );

    _configured = true;
    AppLogger.info(
      'Firebase emulators configurados en $host '
      '(auth:$authPort, firestore:$firestorePort)',
    );
  }

  String resolveHost() {
    if (configuredHost.trim().isNotEmpty) return configuredHost.trim();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }

  @visibleForTesting
  static void resetForTesting() {
    _configured = false;
  }
}

import 'package:flutter/material.dart';

import 'core/di/app_dependencies.dart';
import 'core/runtime/firebase_runtime_initializer.dart';
import 'core/theme/linerb_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const FirebaseRuntimeInitializer().initialize();
  await AppDependencies.initialize();
  runApp(const LinerbApp());
}

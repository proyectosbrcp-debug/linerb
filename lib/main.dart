import 'package:flutter/material.dart';

import 'core/di/app_dependencies.dart';
import 'core/theme/linerb_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDependencies.initialize();
  runApp(const LinerbApp());
}

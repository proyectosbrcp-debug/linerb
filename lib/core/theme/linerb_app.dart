import 'package:flutter/material.dart';

import '../../core/di/app_dependencies.dart';
import '../../pages/auth/auth_gate.dart';

class LinerbApp extends StatefulWidget {
  const LinerbApp({super.key});

  @override
  State<LinerbApp> createState() => _LinerbAppState();
}

class _LinerbAppState extends State<LinerbApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppDependencies.automaticSyncCoordinator.onAppPaused();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        AppDependencies.automaticSyncCoordinator.onAppResumed();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        AppDependencies.automaticSyncCoordinator.onAppPaused();
      case AppLifecycleState.detached:
        AppDependencies.automaticSyncCoordinator.stop();
      case AppLifecycleState.hidden:
        AppDependencies.automaticSyncCoordinator.onAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LINERB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0D47A1),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

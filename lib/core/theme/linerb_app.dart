import 'package:flutter/material.dart';

import '../../pages/auth/auth_gate.dart';

class LinerbApp extends StatelessWidget {
  const LinerbApp({super.key});

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

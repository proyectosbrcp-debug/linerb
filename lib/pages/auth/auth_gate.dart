import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../core/di/app_dependencies.dart';
import '../../models/auth_models.dart';
import '../../models/sync_status_snapshot.dart';
import '../home/seleccion_linea_page.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  final AuthController? controller;

  const AuthGate({super.key, this.controller});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? AppDependencies.authController;
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await AppDependencies.automaticSyncCoordinator.restore();
    await controller.restoreSession();
    await AppDependencies.automaticSyncCoordinator.start(
      trigger: SyncTrigger.authSessionRestored,
    );
    if (!mounted) return;
    setState(() {});
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;

    if (state.status == AuthStatus.initial ||
        state.status == AuthStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.status == AuthStatus.authenticated && state.profile != null) {
      return SeleccionLineaPage(
        usuario: state.profile!.operationalName,
        userProfile: state.profile,
      );
    }

    if (state.status == AuthStatus.disabled) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FA),
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          title: const Text('LINERB'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'El usuario no está habilitado para ingresar.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return LoginPage(controller: controller, onAuthChanged: _refresh);
  }
}

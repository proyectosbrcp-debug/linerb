import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/logging/app_logger.dart';
import '../../core/theme/ui_constants.dart';
import '../../models/auth_models.dart';
import '../../models/sync_status_snapshot.dart';

class LoginPage extends StatefulWidget {
  final AuthController controller;
  final VoidCallback onAuthChanged;

  const LoginPage({
    super.key,
    required this.controller,
    required this.onAuthChanged,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool _isSubmitting = false;
  String? message;

  bool get isLoading =>
      _isSubmitting || widget.controller.state.status == AuthStatus.loading;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      message = null;
    });

    try {
      await widget.controller.signIn(
        email: emailController.text,
        password: passwordController.text,
      );
      if (!mounted) return;

      final state = widget.controller.state;
      if (state.status == AuthStatus.authenticated) {
        await AppDependencies.automaticSyncCoordinator.start(
          trigger: SyncTrigger.manual,
        );
        if (!mounted) return;
        widget.onAuthChanged();
        return;
      }
      AppLogger.warning('Intento de inicio de sesión no completado');
      if (!mounted) return;
      setState(() {
        message = state.message ?? AuthController.genericErrorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      message = null;
    });

    try {
      await widget.controller.sendPasswordResetEmail(emailController.text);
      if (!mounted) return;
      setState(() {
        message =
            'Si el correo está registrado, recibirá instrucciones de recuperación.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LinerbColors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: LinerbColors.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'LINERB',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.hub,
                  size: 90,
                  color: LinerbColors.primaryBlue,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Sistema de Inspección de Líneas',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  enabled: !isLoading,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) {
                    if (!isLoading) _login();
                  },
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      tooltip: obscurePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),
                  enabled: !isLoading,
                ),
                const SizedBox(height: 15),
                if (message != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: LinerbColors.danger),
                    ),
                  ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _login,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text('INICIAR SESIÓN'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      LinerbTouchTarget.primaryButtonHeight,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: isLoading ? null : _resetPassword,
                  child: const Text('Recuperar contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

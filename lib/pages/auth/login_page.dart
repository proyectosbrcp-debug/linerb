import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../core/logging/app_logger.dart';
import '../../models/auth_models.dart';

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
  String? message;

  bool get isLoading => widget.controller.state.status == AuthStatus.loading;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      message = null;
    });
    await widget.controller.signIn(
      email: emailController.text,
      password: passwordController.text,
    );
    if (!mounted) return;

    final state = widget.controller.state;
    if (state.status == AuthStatus.authenticated) {
      widget.onAuthChanged();
      return;
    }
    AppLogger.warning('Intento de inicio de sesión no completado');
    setState(() {
      message = state.message ?? AuthController.genericErrorMessage;
    });
  }

  Future<void> _resetPassword() async {
    await widget.controller.sendPasswordResetEmail(emailController.text);
    if (!mounted) return;
    setState(() {
      message =
          'Si el correo está registrado, recibirá instrucciones de recuperación.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Text(
          'LINERB',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.hub, size: 90, color: Color(0xFF0D47A1)),
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
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 15),
              if (message != null)
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB71C1C)),
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
                  minimumSize: const Size(double.infinity, 55),
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
    );
  }
}

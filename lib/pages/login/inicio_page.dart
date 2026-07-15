import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../home/seleccion_linea_page.dart';

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  String usuario = 'SUPER';
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final fecha = fechaCorta(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Text(
          "LINERB",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.hub, size: 90, color: Color(0xFF0D47A1)),
            const SizedBox(height: 15),
            const Text(
              "Sistema de Inspección de Líneas",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text("Fecha"),
                subtitle: Text(fecha),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: usuario,
              decoration: const InputDecoration(
                labelText: "Usuario",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "SUPER", child: Text("SUPER")),
                DropdownMenuItem(value: "INSPE", child: Text("INSPE")),
              ],
              onChanged: (valor) {
                setState(() {
                  usuario = valor!;
                });
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Contraseña",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                final accesoSuper =
                    usuario == "SUPER" && passwordController.text == "ECO01";
                final accesoInspe =
                    usuario == "INSPE" && passwordController.text == "MASA01";

                if (accesoSuper || accesoInspe) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SeleccionLineaPage(usuario: usuario),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Usuario o contraseña incorrectos"),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text("INICIAR"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

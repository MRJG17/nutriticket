import 'package:flutter/material.dart';
import 'dart:math' as math; // Necesario para rotar la ola inferior
import 'register_screen.dart';
import 'login_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double logoSize = screenSize.width * 0.4;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // --- OLA SUPERIOR DECORATIVA ---
          Align(
            alignment: Alignment.topCenter,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: screenSize.height * 0.15,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade200, Colors.green.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // --- OLA INFERIOR DECORATIVA (ROTADA) ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Transform.rotate(
              angle: math.pi, // Rota la ola 180 grados
              child: ClipPath(
                clipper: WaveClipper(),
                child: Container(
                  height: screenSize.height * 0.15,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade200, Colors.green.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- CONTENIDO PRINCIPAL CENTRADO ---
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Logo
                    Image.asset('assets/images/logo.png', height: logoSize),
                    const SizedBox(height: 20),

                    // Imagen del eslogan
                    Image.asset('assets/images/eslogan.png'),

                    // ✅ INICIO DE LA MODIFICACIÓN: Ajuste de espaciadores
                    const Spacer(flex: 1), // Reducimos para subir el botón

                    // Botón "Comenzar"
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Comenzar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Spacer(flex: 3), // Aumentamos para compensar
                    // ✅ FIN DE LA MODIFICACIÓN
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Clipper para crear la forma de la ola ---
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50); // Punto de inicio de la curva

    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 30.0);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);

    var secondControlPoint =
        Offset(size.width - (size.width / 4), size.height - 80);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, 0); // Lado derecho
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}

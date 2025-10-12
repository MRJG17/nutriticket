// lib/main_screen.dart

import 'package:flutter/material.dart';
import 'register_screen.dart'; 
import 'login_screen.dart'; 

// Renombramos la clase a MainScreen para reflejar su rol como punto de partida para no-autenticados
class MainScreen extends StatelessWidget { 
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              
              // Título de la Aplicación
              const Text(
                'NutriTicket',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                  color: Colors.green, // Color de tu marca
                ),
              ),
              const Text(
                'Tu asistente nutricional inteligente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              
              const Spacer(flex: 1),
              
              // ⭐️ Botón de INICIAR SESIÓN ⭐️
              ElevatedButton(
                onPressed: () {
                  // Navega a la pantalla de Login separada
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 18)),
              ),
              
              const SizedBox(height: 15),
              
              // ⭐️ Botón de CREAR CUENTA (REGISTRO) ⭐️
              OutlinedButton(
                onPressed: () {
                  // Navega a la pantalla de Registro separada
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.green),
                  foregroundColor: Colors.green,
                ),
                child: const Text('Crear Cuenta', style: TextStyle(fontSize: 18)),
              ),
              
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
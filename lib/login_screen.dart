// lib/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutriticket/main.dart';

// Renombramos la clase para que LoginScreen sea su propio widget importable
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (Route<dynamic> route) => false, // Elimina todo el historial
      );
    }
      // AuthWrapper se encargará de la navegación si es exitoso
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Credenciales incorrectas o usuario no existe.";
      if (e.code == 'wrong-password') {
        errorMessage = 'Contraseña incorrecta.';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'No se encontró un usuario con ese correo electrónico.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Sesión')), // Añadimos AppBar para más claridad
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('NutriTicket', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 50),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Correo electrónico')),
              const SizedBox(height: 20),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _loginUser, child: const Text('Login')),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
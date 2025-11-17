// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart'; // Importamos la pantalla de registro

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

  // --- FUNCIÓN DE LOGIN (SIN CAMBIOS) ---
  Future<void> _loginUser() async {
    // Muestra un indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Si el login es exitoso, cerramos todas las pantallas hasta llegar al AuthWrapper
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      // Primero, cerramos el diálogo de carga antes de mostrar el error
      if (mounted) Navigator.pop(context);

      String errorMessage = "Usuario o Contraseña Incorrecta.";
      if (e.code == 'wrong-password' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-credential') {
        errorMessage = 'Las credenciales son incorrectas.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo es inválido.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Demasiados intentos. Inténtalo de nuevo más tarde.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- ✅ 1. NUEVA FUNCIÓN PARA MODO INVITADO ---
  Future<void> _signInAsGuest() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Usamos la autenticación anónima de Firebase
      await FirebaseAuth.instance.signInAnonymously();

      // Cerramos todo, el AuthWrapper nos redirigirá al HomeScreen
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context); // Oculta el diálogo de carga

      String errorMessage = 'No se pudo conectar como invitado.';
      // Este error es común si no has habilitado el método anónimo en la consola de Firebase
      if (e.code == 'operation-not-allowed') {
        errorMessage = 'El modo invitado no está habilitado en el servidor.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }
  // --- ✅ FIN DE LA NUEVA FUNCIÓN ---

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double logoSize = screenSize.width * 0.4;
    final double socialIconRadius = screenSize.width * 0.06;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        // --- ✅ 2. AÑADIR EL BOTÓN DE "MODO INVITADO" ---
        actions: [
          TextButton(
            onPressed: _signInAsGuest, // Llama a la nueva función
            child: const Text(
              'Modo Invitado',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        // --- ✅ FIN DE LA MODIFICACIÓN ---
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ... (El resto de la UI: logo, campos de texto, botones)
              // ... (NO HAY MÁS CAMBIOS EN EL BODY) ...
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 220,
                  maxWidth: 220,
                ),
                child: Image.asset('assets/images/logo.png', height: logoSize),
              ),

              const SizedBox(height: 40),

              // Campo de texto para Correo Electrónico
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  labelStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),

              const SizedBox(height: 20),

              // Campo de texto para Contraseña
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  labelStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),

              const SizedBox(height: 10),

              // Botón de "Olvidaste tu contraseña"
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // TODO: Implementar lógica de recuperación de contraseña
                  },
                  child: const Text(
                    '¿Olvidaste tu Contraseña?',
                    style: TextStyle(color: Color(0xFF4CAF50)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botón principal de Iniciar Sesión
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loginUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Iniciar Sesión',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botón para navegar a la pantalla de registro
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: const Text(
                  '¿No tienes una cuenta? Regístrate',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF4CAF50),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Divisor con texto
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.grey)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'O inicia sesión con',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.grey)),
                ],
              ),

              const SizedBox(height: 20),

              // Iconos de redes sociales
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      // TODO: Implementar inicio de sesión con Google
                    },
                    child: CircleAvatar(
                      radius: socialIconRadius.clamp(25.0, 35.0),
                      backgroundColor: Colors.transparent,
                      child: Image.asset('assets/images/google.png'),
                    ),
                  ),
                  const SizedBox(width: 30),
                  GestureDetector(
                    onTap: () {
                      // TODO: Implementar inicio de sesión con Facebook
                    },
                    child: CircleAvatar(
                      radius: socialIconRadius.clamp(25.0, 35.0),
                      backgroundColor: Colors.transparent,
                      child: Image.asset('assets/images/facebook.png'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

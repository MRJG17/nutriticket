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

  // --- FUNCIÓN DE LOGIN ---
  Future<void> _loginUser() async {
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

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
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

  // --- FUNCIÓN PARA MODO INVITADO ---
  Future<void> _signInAsGuest() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);

      String errorMessage = 'No se pudo conectar como invitado.';
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

  // --- ✅ FUNCIÓN: RECUPERAR CONTRASEÑA MEJORADA ---
  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController resetEmailController = TextEditingController();

    // Autocompletar si ya escribió el correo
    if (_emailController.text.isNotEmpty) {
      resetEmailController.text = _emailController.text;
    }

    return showDialog(
      context: context, // Usa el contexto de la Pantalla Principal
      // Usamos 'dialogContext' para referirnos a ESTE diálogo específico
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Recuperar Contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext), // Cerramos usando dialogContext
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final email = resetEmailController.text.trim();

                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Por favor, ingresa un correo.')),
                  );
                  return;
                }

                // 1. Cerramos el diálogo de entrada
                Navigator.pop(dialogContext);

                // 2. Mostramos carga (Usamos 'context' principal)
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: email);

                  if (mounted) {
                    // 3. Cerramos la carga
                    Navigator.pop(context);

                    // ✅ 4. MOSTRAMOS EL DIÁLOGO DE INSTRUCCIONES (MEJORA UX)
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        title: const Row(
                          children: [
                            Icon(Icons.mark_email_read,
                                color: Color(0xFF4CAF50)),
                            SizedBox(width: 10),
                            Text('¡Correo Enviado!'),
                          ],
                        ),
                        content: const Text(
                          'Hemos enviado un enlace seguro a tu correo.\n\n'
                          '1. Abre el correo de "Equipo NutriTicket".\n'
                          '2. Toca el enlace para crear tu nueva contraseña.\n'
                          '3. Vuelve aquí e inicia sesión con tu nueva clave.',
                          style: TextStyle(fontSize: 15, height: 1.5),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Entendido',
                              style: TextStyle(
                                  color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  // Si falla, cerramos la carga usando el contexto principal
                  if (mounted) Navigator.pop(context);

                  String errorMsg = 'Error al enviar el correo.';
                  if (e.code == 'user-not-found') {
                    errorMsg = 'No existe una cuenta con este correo.';
                  } else if (e.code == 'invalid-email') {
                    errorMsg = 'El formato del correo no es válido.';
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(errorMsg), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

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
        actions: [
          TextButton(
            onPressed: _signInAsGuest,
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
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 220,
                  maxWidth: 220,
                ),
                child: Image.asset('assets/images/logo.png', height: logoSize),
              ),

              const SizedBox(height: 40),

              // Campo Email
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

              // Campo Contraseña
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

              // Botón de "¿Olvidaste tu contraseña?"
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      _showForgotPasswordDialog, // Llama a la nueva función
                  child: const Text(
                    '¿Olvidaste tu Contraseña?',
                    style: TextStyle(color: Color(0xFF4CAF50)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botón Iniciar Sesión
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

              // Botón Registro
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

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      // TODO: Implementar Google Sign-In
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
                      // TODO: Implementar Facebook Sign-In
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

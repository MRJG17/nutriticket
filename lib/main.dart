// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Necesario para la autenticación
import 'firebase_options.dart'; 
import 'register_screen.dart'; // Necesario para la navegación al registro
import 'home_screen.dart'; // La pantalla principal que mostraremos después del login

// Inicialización de Firebase (TU CÓDIGO ESTÁ BIEN AQUÍ)
void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NutriTicket',
      // 💡 Comprobamos si el usuario ya inició sesión
      home: AuthWrapper(), 
    );
  }
}

// ⭐️ Nueva Clase: Controla si mostrar Login o Home ⭐️
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha los cambios en el estado de autenticación de Firebase
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Si hay un error, puedes mostrar un mensaje
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // Si el usuario está autenticado, navega al Home
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        
        // Si no está autenticado, muestra la pantalla de Login
        return const LoginScreen();
      },
    );
  }
}


// LoginScreen (versión funcional con Firebase)
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
      // Firebase AuthWrapper se encargará de navegar a HomeScreen si es exitoso
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
              TextButton(
                onPressed: () {
                  // Navegación a la pantalla de registro
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text('Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ⚠️ NECESITAS CREAR lib/home_screen.dart y lib/register_screen.dart
// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'home_screen.dart';
import 'main_screen.dart'; // ⭐️ Cambia la clase interna a MainScreen, si renombraste el archivo ⭐️

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
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en', 'US'),
        Locale('es', 'ES'),
        Locale('es', 'MX'),
      ],
      home: AuthWrapper(),
    );
  }
}

// ⭐️ AuthWrapper Ajustado ⭐️
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Si el usuario está autenticado, va al Home
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // ⭐️ Si no está autenticado, va a la pantalla de Bienvenida/Main ⭐️
        // Asumiendo que has renombrado la clase WelcomeScreen a MainScreen:
        return const MainScreen();
      },
    );
  }
}

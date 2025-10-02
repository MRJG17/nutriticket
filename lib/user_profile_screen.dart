// lib/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'home_screen.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; // ⭐️ Importar Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Para obtener el UID del usuario

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // Función para guardar los datos en Cloud Firestore
  Future<void> _saveProfileData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // 1. Crear el mapa de datos
      Map<String, dynamic> userData = {
        'uid': user.uid,
        'gender': _genderController.text.trim(),
        'heightCm': double.tryParse(_heightController.text.trim()) ?? 0.0,
        'weightKg': double.tryParse(_weightController.text.trim()) ?? 0.0,
        'hasCompletedProfile': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      try {
        // 2. Usar el UID del usuario como ID del documento en la colección 'users'
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(userData, SetOptions(merge: true)); // Usamos merge para no sobrescribir todo

        print("Datos de perfil guardados en Firestore.");
        
        // 3. Navegar al Home si es exitoso
        _navigateToHome();
      } catch (e) {
        print("Error al guardar en Firestore: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error al guardar los datos."), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // Función de navegación para no repetir código
  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _genderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        title: const Text('Información Nutricional'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Para un menú balanceado, necesitamos algunos datos:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            TextField(controller: _heightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estatura (cm)', hintText: 'Ej: 175')),
            const SizedBox(height: 10),
            
            TextField(controller: _weightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Peso (kg)', hintText: 'Ej: 70.5')),
            const SizedBox(height: 10),
            
            TextField(controller: _genderController, decoration: const InputDecoration(labelText: 'Sexo', hintText: 'Hombre / Mujer')),
            const SizedBox(height: 30),

            // Botón para Guardar y Continuar
            ElevatedButton(
              onPressed: _saveProfileData, // Llama a la función de guardado
              child: const Text('Guardar y Continuar'),
            ),
            const SizedBox(height: 10),
            
            // Botón para Omitir / Saltar
            TextButton(
              onPressed: _navigateToHome, // Llama a la función de navegación directa
              child: const Text('Omitir por ahora', style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}
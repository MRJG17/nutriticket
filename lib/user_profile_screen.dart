// lib/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'home_screen.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // Controladores de valores numéricos
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  
  // ⭐️ Variables de estado para los selectores ⭐️
  String? _selectedGender; // null, 'Hombre', o 'Mujer'
  String _heightUnit = 'cm'; // 'cm' o 'ft'
  String _weightUnit = 'kg'; // 'kg' o 'lbs'

  // --- Lógica de Conversión de Unidades ---
  double _convertToCm(double value, String unit) {
    if (unit == 'cm') return value;
    // 1 pie = 30.48 cm
    return value * 30.48; 
  }

  double _convertToKg(double value, String unit) {
    if (unit == 'kg') return value;
    // 1 libra = 0.453592 kg
    return value * 0.453592; 
  }
  // ----------------------------------------

  // Función para guardar los datos en Cloud Firestore
  Future<void> _saveProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedGender == null) {
      // Manejar error si el usuario no está logueado o falta seleccionar género
      return; 
    }

    // Convertir a valores base (Cm y Kg) antes de guardar
    final double rawHeight = double.tryParse(_heightController.text.trim()) ?? 0.0;
    final double rawWeight = double.tryParse(_weightController.text.trim()) ?? 0.0;
    
    final double heightInCm = _convertToCm(rawHeight, _heightUnit);
    final double weightInKg = _convertToKg(rawWeight, _weightUnit);

    // 1. Crear el mapa de datos
    Map<String, dynamic> userData = {
      'uid': user.uid,
      'gender': _selectedGender, // Usamos el valor del selector
      'heightCm': heightInCm,
      'weightKg': weightInKg,
      'heightUnitPreference': _heightUnit, // Guardar la preferencia
      'weightUnitPreference': _weightUnit, // Guardar la preferencia
      'hasCompletedProfile': true,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // 2. Usar el UID del usuario como ID del documento en la colección 'users'
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true)); 

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

  // Función de navegación para no repetir código
  void _navigateToHome() {
    Navigator.pushAndRemoveUntil( 
    context,
    MaterialPageRoute(builder: (context) => const HomeScreen()),
    (Route<dynamic> route) => false, // Elimina todas las rutas anteriores (perfil, registro, login)
  );
  }

  @override
  void dispose() {
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
            
            // ⭐️ 1. Selector de Sexo ⭐️
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Sexo',
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedGender,
              hint: const Text('Selecciona tu sexo'),
              items: ['Hombre', 'Mujer']
                  .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              },
            ),
            const SizedBox(height: 20),

            // ⭐️ 2. Estatura con Selector de Unidades (cm/ft) ⭐️
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estatura', 
                      hintText: 'Ej: 175',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _heightUnit,
                  items: ['cm', 'ft']
                      .map((String unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                      .toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _heightUnit = newValue;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ⭐️ 3. Peso con Selector de Unidades (kg/lbs) ⭐️
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Peso', 
                      hintText: 'Ej: 70.5',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _weightUnit,
                  items: ['kg', 'lbs']
                      .map((String unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                      .toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _weightUnit = newValue;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Botón para Guardar y Continuar
            ElevatedButton(
              onPressed: _saveProfileData,
              child: const Text('Guardar y Continuar'),
            ),
            const SizedBox(height: 10),
            
            // Botón para Omitir / Saltar
            TextButton(
              onPressed: _navigateToHome,
              child: const Text('Omitir por ahora', style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}